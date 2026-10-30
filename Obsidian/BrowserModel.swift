import Foundation
import SwiftUI
import WebKit
import UIKit

struct SavedPage: Identifiable, Codable {
    var id: String { url.absoluteString }
    var title: String
    var url: URL
    var visited: Date = Date()
}

enum Atmosphere: String, CaseIterable, Identifiable {
    case obsidian, graphite, midnight, forest, dusk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .obsidian: return "Обсидиан"
        case .graphite: return "Графит"
        case .midnight: return "Полночь"
        case .forest: return "Хвоя"
        case .dusk: return "Сумерки"
        }
    }
    var color: Color {
        switch self {
        case .obsidian: return Color(red: 0.15, green: 0.16, blue: 0.19)
        case .graphite: return Color(red: 0.25, green: 0.28, blue: 0.33)
        case .midnight: return Color(red: 0.16, green: 0.20, blue: 0.36)
        case .forest: return Color(red: 0.13, green: 0.27, blue: 0.22)
        case .dusk: return Color(red: 0.29, green: 0.18, blue: 0.33)
        }
    }
}

enum SearchEngine: String, CaseIterable, Identifiable {
    case google, yandex, duckduckgo
    var id: String { rawValue }
    var title: String {
        switch self {
        case .google: return "Google"
        case .yandex: return "Яндекс"
        case .duckduckgo: return "DuckDuckGo"
        }
    }
    var base: String {
        switch self {
        case .google: return "https://www.google.com/search"
        case .yandex: return "https://yandex.ru/search/"
        case .duckduckgo: return "https://duckduckgo.com/"
        }
    }
    func search(_ query: String) -> URL {
        var parts = URLComponents(string: base)!
        parts.queryItems = [URLQueryItem(name: self == .yandex ? "text" : "q", value: query)]
        return parts.url!
    }
}

@MainActor
final class BrowserModel: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedID: UUID
    @Published var bookmarks: [SavedPage] = []
    @Published var history: [SavedPage] = []
    @Published var atmosphere: Atmosphere = .obsidian { didSet { UserDefaults.standard.set(atmosphere.rawValue, forKey: "atmosphere") } }
    @Published var searchEngine: SearchEngine = .google { didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") } }
    @Published var dim: Double = 0.35 { didSet { UserDefaults.standard.set(dim, forKey: "wallpaperDim") } }
    @Published var wallpaper: UIImage?
    @Published var notice: String?
    private let encoder = JSONEncoder()

    var active: BrowserTab { tabs.first { $0.id == selectedID } ?? tabs[0] }
    private static var wallpaperURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Obsidian", isDirectory: true).appendingPathComponent("wallpaper.jpg")
    }

    init() {
        let tab = BrowserTab()
        selectedID = tab.id
        tabs = [tab]
        let defaults = UserDefaults.standard
        atmosphere = Atmosphere(rawValue: defaults.string(forKey: "atmosphere") ?? "") ?? .obsidian
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: "searchEngine") ?? "") ?? .google
        if defaults.object(forKey: "wallpaperDim") != nil { dim = defaults.double(forKey: "wallpaperDim") }
        if let data = defaults.data(forKey: "bookmarks") { bookmarks = (try? JSONDecoder().decode([SavedPage].self, from: data)) ?? [] }
        if let data = defaults.data(forKey: "history") { history = (try? JSONDecoder().decode([SavedPage].self, from: data)) ?? [] }
        if let data = try? Data(contentsOf: Self.wallpaperURL) { wallpaper = UIImage(data: data) }
        attach(tab)
    }

    private func attach(_ tab: BrowserTab) {
        tab.openNewTab = { [weak self] url in self?.newTab(url: url) }
        tab.finished = { [weak self] page in
            guard let self else { return }
            history.removeAll { $0.url == page.url }
            history.insert(page, at: 0)
            history = Array(history.prefix(300))
            UserDefaults.standard.set(try? encoder.encode(history), forKey: "history")
        }
    }

    @discardableResult
    func newTab(url: URL? = nil) -> BrowserTab {
        let tab = BrowserTab()
        attach(tab)
        tabs.append(tab)
        selectedID = tab.id
        if let url { tab.load(url) }
        return tab
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.webView?.stopLoading()
        if tabs.count == 1 {
            let replacement = BrowserTab()
            attach(replacement)
            tabs = [replacement]
            selectedID = replacement.id
        } else {
            tabs.remove(at: index)
            if selectedID == tab.id { selectedID = tabs[min(index, tabs.count - 1)].id }
        }
    }

    func navigate(_ input: String) {
        guard let url = Self.resolve(input, engine: searchEngine) else { return }
        active.load(url)
    }

    static func resolve(_ input: String, engine: SearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let aliases = ["ютуб": "https://www.youtube.com/", "ютюб": "https://www.youtube.com/", "youtube": "https://www.youtube.com/", "яндекс": "https://ya.ru/", "yandex": "https://ya.ru/", "гугл": "https://www.google.com/", "google": "https://www.google.com/", "твич": "https://www.twitch.tv/", "twitch": "https://www.twitch.tv/"]
        if let alias = aliases[text.lowercased()] { return URL(string: alias) }
        if let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil { return url }
        if text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, !text.contains("://"), text.contains("."), let url = URL(string: "https://" + text), url.host != nil { return url }
        return engine.search(text)
    }

    func isBookmarked(_ url: URL?) -> Bool { bookmarks.contains { $0.url == url } }
    func toggleBookmark(_ tab: BrowserTab) {
        guard let url = tab.url else { return }
        if isBookmarked(url) { bookmarks.removeAll { $0.url == url } }
        else { bookmarks.append(SavedPage(title: tab.title, url: url)) }
        saveBookmarks()
    }
    func removeBookmark(_ page: SavedPage) { bookmarks.removeAll { $0.id == page.id }; saveBookmarks() }
    private func saveBookmarks() { UserDefaults.standard.set(try? encoder.encode(bookmarks), forKey: "bookmarks") }
    func clearHistory() { history = []; UserDefaults.standard.removeObject(forKey: "history") }

    func changeWallpaper(_ image: UIImage?) {
        do {
            let url = Self.wallpaperURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let image {
                guard let data = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: url, options: .atomic)
            } else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            wallpaper = image
        } catch { notice = "Не удалось сохранить фон: \(error.localizedDescription)" }
    }
}
