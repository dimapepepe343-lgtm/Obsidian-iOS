import SwiftUI
import PhotosUI
import ImageIO

struct TabsView: View {
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(browser.tabs) { tab in
                        TabCard(tab: tab, selected: tab.id == browser.selectedID) {
                            browser.selectedID = tab.id
                            dismiss()
                        } close: { browser.close(tab) }
                    }
                }.padding(20)
            }
            .background(Color(white: 0.05)).navigationTitle("Твои вкладки")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { browser.newTab(); dismiss() } label: { Label("Новая", systemImage: "plus") }.accessibilityIdentifier("newTabButton")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
        }.preferredColorScheme(.dark)
    }
}

private struct TabCard: View {
    @ObservedObject var tab: BrowserTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: tab.isHome ? "diamond" : "globe").font(.system(size: 12)).foregroundStyle(.secondary)
                Text(tab.isHome ? "Новая вкладка" : tab.title).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 11)).frame(width: 28, height: 28) }.accessibilityLabel("Закрыть вкладку")
            }.padding(.leading, 11).padding(.trailing, 3).padding(.top, 3)
            Button(action: select) {
                VStack(spacing: 14) {
                    if let url = tab.url, !tab.isHome { SiteIcon(url: url, size: 43) }
                    else { DiamondMark().stroke(.white.opacity(0.5), lineWidth: 1.2).frame(width: 31, height: 37) }
                    Text(tab.isHome ? "Твоё пространство" : tab.url?.host ?? "Страница")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                }.frame(maxWidth: .infinity).frame(height: 135).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .background(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.065)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(selected ? 0.5 : 0.09), lineWidth: selected ? 1.5 : 1))
    }
}

struct SavedPagesView: View {
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss
    let showHistory: Bool
    private var pages: [SavedPage] { showHistory ? browser.history : browser.bookmarks }

    var body: some View {
        NavigationStack {
            List {
                if pages.isEmpty {
                    ContentUnavailableView(showHistory ? "История пока пуста" : "Сохрани любимое", systemImage: showHistory ? "clock" : "star", description: Text(showHistory ? "Открытые страницы появятся здесь." : "Звёздочка сохранит текущую страницу."))
                }
                ForEach(pages) { page in
                    Button {
                        browser.newTab(url: page.url)
                        dismiss()
                    } label: {
                        HStack(spacing: 13) {
                            SiteIcon(url: page.url, size: 34)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(page.title).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                                Text(page.url.host ?? "").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                    .swipeActions {
                        if !showHistory { Button("Удалить", role: .destructive) { browser.removeBookmark(page) } }
                    }
                }
            }
            .navigationTitle(showHistory ? "История" : "Закладки")
            .toolbar {
                if showHistory { ToolbarItem(placement: .topBarLeading) { Button("Очистить") { browser.clearHistory() }.disabled(pages.isEmpty) } }
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
        }.preferredColorScheme(.dark)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Тихие оттенки. Мягкий свет. Твоё изображение.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).listRowBackground(Color.clear)
                }
                Section("Цвет пространства") {
                    HStack(spacing: 0) {
                        ForEach(Atmosphere.allCases) { atmosphere in
                            Button { withAnimation(.easeInOut(duration: 0.25)) { browser.atmosphere = atmosphere } } label: {
                                VStack(spacing: 9) {
                                    Circle().fill(atmosphere.color.gradient).frame(width: 35, height: 35)
                                        .overlay(Circle().stroke(.white.opacity(0.15)))
                                        .overlay { if browser.atmosphere == atmosphere { Image(systemName: "checkmark").font(.system(size: 12, weight: .medium)) } }
                                        .padding(4).overlay(Circle().stroke(.white.opacity(browser.atmosphere == atmosphere ? 0.6 : 0)))
                                    Text(atmosphere.title).font(.system(size: 8)).foregroundStyle(.white.opacity(0.6))
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 12)
                }
                Section {
                    PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                        Label("Выбрать изображение", systemImage: "photo.badge.plus")
                    }
                    if browser.wallpaper != nil {
                        Button { browser.changeWallpaper(nil) } label: { Label("Убрать фон", systemImage: "arrow.uturn.backward") }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Затемнение"); Spacer(); Text("\(Int(browser.dim * 100))%").foregroundStyle(.secondary) }
                            .font(.system(size: 13))
                        Slider(value: $browser.dim, in: 0...0.85)
                    }.padding(.vertical, 7)
                } header: { Text("За стеклом") } footer: { Text("Изображение сохраняется на этом iPhone и не загружается на сервер.") }
                Section("Твой поиск") {
                    Picker("Поисковик", selection: $browser.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in Text(engine.title).tag(engine) }
                    }
                }
                Section {
                    NavigationLink { SavedPagesView(showHistory: false) } label: { Label("Закладки", systemImage: "star") }
                    NavigationLink { SavedPagesView(showHistory: true) } label: { Label("История", systemImage: "clock") }
                    if !browser.active.isHome {
                        Button { browser.toggleBookmark(browser.active) } label: {
                            Label(browser.isBookmarked(browser.active.url) ? "Убрать страницу из закладок" : "Сохранить текущую страницу", systemImage: browser.isBookmarked(browser.active.url) ? "star.fill" : "star")
                        }
                    }
                }
                Section {
                    HStack(spacing: 13) {
                        DiamondMark().stroke(.white.opacity(0.6), lineWidth: 1.3).frame(width: 27, height: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("obsidian").font(.system(size: 21, weight: .semibold, design: .rounded)).tracking(-0.8)
                            Text("iPhone · 1.0").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 5).listRowBackground(Color.clear)
                } footer: { Text("Место, куда приятно возвращаться.") }
            }
            .navigationTitle("Сделай своим")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
            .onChange(of: photo) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2048
                          ] as CFDictionary) else { return }
                    browser.changeWallpaper(UIImage(cgImage: thumbnail))
                }
            }
        }.preferredColorScheme(.dark)
    }
}
