import SwiftUI
import WebKit

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    @Published var title = "Новая вкладка"
    @Published var url: URL?
    @Published var isHome = true
    @Published var isLoading = false
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var error: String?
    @Published var dialog: ScriptDialog?
    var webView: WKWebView?
    var openNewTab: ((URL) -> Void)?
    var finished: ((SavedPage) -> Void)?
    private var observations: [NSKeyValueObservation] = []

    struct ScriptDialog: Identifiable {
        enum Kind: Equatable { case alert, confirm, prompt }
        let id = UUID()
        let kind: Kind
        let message: String
        var defaultText: String = ""
        var complete: (Bool, String?) -> Void
    }

    func prepareWebView() -> WKWebView {
        if let webView { return webView }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.045, green: 0.05, blue: 0.06, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = self
        view.uiDelegate = self
        observations = [
            view.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in self?.progress = view.estimatedProgress },
            view.observe(\.isLoading, options: [.new]) { [weak self] view, _ in self?.isLoading = view.isLoading },
            view.observe(\.title, options: [.new]) { [weak self] view, _ in self?.title = view.title ?? view.url?.host ?? "Страница" },
            view.observe(\.url, options: [.new]) { [weak self] view, _ in self?.url = view.url },
            view.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in self?.canGoBack = view.canGoBack },
            view.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in self?.canGoForward = view.canGoForward }
        ]
        webView = view
        return view
    }

    func load(_ destination: URL) {
        error = nil
        url = destination
        title = destination.host ?? "Страница"
        isHome = false
        prepareWebView().load(URLRequest(url: destination))
    }
    func reload() { if let url { load(url) } }
    func home() { webView?.stopLoading(); isHome = true; error = nil }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { error = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, ["http", "https"].contains(url.scheme ?? "") else { return }
        error = nil
        finished?(SavedPage(title: webView.title ?? url.host ?? "Страница", url: url))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) { handle(failure) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) { handle(failure) }
    private func handle(_ failure: Error) {
        guard (failure as NSError).code != NSURLErrorCancelled else { return }
        error = failure.localizedDescription
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { error = "Страница перестала отвечать. Попробуй обновить её." }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let destination = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = destination.scheme?.lowercased() ?? ""
        if ["http", "https", "about", "blob", "data"].contains(scheme) { decisionHandler(.allow) }
        else {
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated, ["mailto", "tel", "sms"].contains(scheme) { UIApplication.shared.open(destination) }
        }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") { openNewTab?(url) }
        return nil
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        dialog = ScriptDialog(kind: .alert, message: message, complete: { _, _ in completionHandler() })
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        dialog = ScriptDialog(kind: .confirm, message: message, complete: { accepted, _ in completionHandler(accepted) })
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        dialog = ScriptDialog(kind: .prompt, message: prompt, defaultText: defaultText ?? "", complete: { accepted, text in completionHandler(accepted ? text : nil) })
    }
}

struct WebsiteView: UIViewRepresentable {
    let tab: BrowserTab
    func makeUIView(context: Context) -> WKWebView { tab.prepareWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
