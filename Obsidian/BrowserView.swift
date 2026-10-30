import SwiftUI

enum BrowserSheet: String, Identifiable {
    case tabs, settings, bookmarks, history
    var id: String { rawValue }
}

struct BrowserRoot: View {
    @EnvironmentObject private var browser: BrowserModel
    @State private var sheet: BrowserSheet?

    var body: some View {
        ActiveBrowserView(tab: browser.active, sheet: $sheet)
            .id(browser.active.id)
            .environmentObject(browser)
            .sheet(item: $sheet) { destination in
                switch destination {
                case .tabs: TabsView()
                case .settings: SettingsView()
                case .bookmarks: SavedPagesView(showHistory: false)
                case .history: SavedPagesView(showHistory: true)
                }
            }
            .alert("Obsidian", isPresented: Binding(get: { browser.notice != nil }, set: { if !$0 { browser.notice = nil } })) {
                Button("Понятно") { browser.notice = nil }
            } message: { Text(browser.notice ?? "") }
    }
}

struct ActiveBrowserView: View {
    @EnvironmentObject private var browser: BrowserModel
    @ObservedObject var tab: BrowserTab
    @Binding var sheet: BrowserSheet?
    @State private var address = ""
    @State private var dialogInput = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.05).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    DiamondMark().stroke(.white.opacity(0.75), lineWidth: 1.2).frame(width: 17, height: 20)
                    Text("obsidian").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(-0.9)
                    Text("iOS").font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.4)).padding(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.12)))
                    Spacer()
                    Button { sheet = .bookmarks } label: { Image(systemName: "star").frame(width: 38, height: 34) }
                        .accessibilityLabel("Закладки")
                    Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3").frame(width: 38, height: 34) }
                        .accessibilityLabel("Настройки")
                }
                .foregroundStyle(.white.opacity(0.82)).padding(.horizontal, 20).padding(.top, 6)

                ZStack {
                    if tab.isHome { HomeView() }
                    else if let error = tab.error { errorPage(error) }
                    else { WebsiteView(tab: tab) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.07)))
                .padding(.horizontal, 10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .onAppear { syncAddress() }
        .onChange(of: tab.url) { _, _ in if !addressFocused { syncAddress() } }
        .onChange(of: tab.isHome) { _, _ in if !addressFocused { syncAddress() } }
        .onChange(of: tab.dialog?.id) { _, _ in dialogInput = tab.dialog?.defaultText ?? "" }
        .alert("Сообщение сайта", isPresented: Binding(get: { tab.dialog != nil }, set: { if !$0 { resolveDialog(false) } })) {
            if tab.dialog?.kind == .prompt { TextField("Ответ", text: $dialogInput) }
            Button("OK") { resolveDialog(true) }
            if tab.dialog?.kind != .alert { Button("Отмена", role: .cancel) { resolveDialog(false) } }
        } message: { Text(tab.dialog?.message ?? "") }
    }

    private func syncAddress() { address = tab.isHome ? "" : (tab.url?.absoluteString ?? "") }
    private func resolveDialog(_ accepted: Bool) {
        guard let dialog = tab.dialog else { return }
        tab.dialog = nil
        dialog.complete(accepted, dialogInput)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if tab.isLoading && !tab.isHome {
                ProgressView(value: tab.progress).tint(.white.opacity(0.65)).padding(.horizontal, 7)
            }
            HStack(spacing: 10) {
                Image(systemName: !tab.isHome && tab.url?.scheme == "https" ? "lock.fill" : "magnifyingglass")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                TextField("Поиск или адрес сайта", text: $address)
                    .font(.system(size: 14)).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.webSearch).submitLabel(.go).focused($addressFocused)
                    .accessibilityIdentifier("addressInput")
                    .onSubmit { browser.navigate(address); addressFocused = false }
                Button {
                    if addressFocused { browser.navigate(address); addressFocused = false }
                    else if tab.isLoading { tab.webView?.stopLoading() }
                    else { tab.reload() }
                } label: {
                    Image(systemName: addressFocused ? "arrow.right" : tab.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium)).frame(width: 29, height: 29)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }.accessibilityLabel(addressFocused ? "Открыть или найти" : "Обновить страницу")
            }
            .padding(.horizontal, 13).frame(height: 48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(addressFocused ? 0.22 : 0.09)))

            HStack {
                toolbarButton("chevron.left", "Назад", disabled: !tab.canGoBack || tab.isHome) { tab.webView?.goBack() }
                Spacer()
                toolbarButton("chevron.right", "Вперёд", disabled: !tab.canGoForward || tab.isHome) { tab.webView?.goForward() }
                Spacer()
                toolbarButton("house", "Главная") { tab.home() }
                Spacer()
                if let url = tab.url, !tab.isHome {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 35, height: 30) }.accessibilityLabel("Поделиться страницей")
                } else { toolbarButton("star", "Закладки") { sheet = .bookmarks } }
                Spacer()
                Button { sheet = .tabs } label: {
                    Text("\(browser.tabs.count)").font(.system(size: 11, weight: .semibold))
                        .frame(width: 19, height: 21).overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1.4)).frame(width: 35, height: 30)
                }.accessibilityLabel("Вкладки: \(browser.tabs.count)").accessibilityIdentifier("tabsButton")
            }
            .font(.system(size: 17, weight: .regular)).foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 9)
        }
        .padding(.horizontal, 17).padding(.top, 12).padding(.bottom, 7)
        .background(Color(red: 0.035, green: 0.04, blue: 0.05).opacity(0.97))
    }

    private func toolbarButton(_ symbol: String, _ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 35, height: 30) }
            .disabled(disabled).opacity(disabled ? 0.25 : 1).accessibilityLabel(title)
    }
    private func errorPage(_ error: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "globe").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(.white.opacity(0.5))
            Text("Давай ещё раз.").font(.system(size: 30, weight: .light))
            Text(error).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Попробовать снова") { tab.reload() }.buttonStyle(.borderedProminent).tint(.white.opacity(0.15))
            Spacer()
        }.padding(35).frame(maxWidth: .infinity).background(browser.atmosphere.color.gradient)
    }
}

struct DiamondMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLines([CGPoint(x: w, y: h * 0.3), CGPoint(x: w * 0.85, y: h), CGPoint(x: w * 0.15, y: h), CGPoint(x: 0, y: h * 0.3), CGPoint(x: w * 0.5, y: 0)])
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLines([CGPoint(x: w * 0.7, y: h * 0.4), CGPoint(x: w * 0.5, y: h), CGPoint(x: w * 0.3, y: h * 0.4), CGPoint(x: w * 0.5, y: 0)])
        return p
    }
}
