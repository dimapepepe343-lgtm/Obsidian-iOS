import SwiftUI

struct QuickSite: Identifiable {
    var id: String { url.absoluteString }
    let name: String
    let url: URL
    let symbol: String
    static let all = [
        QuickSite(name: "YouTube", url: URL(string: "https://www.youtube.com/")!, symbol: "play.rectangle.fill"),
        QuickSite(name: "Google", url: URL(string: "https://www.google.com/")!, symbol: "magnifyingglass"),
        QuickSite(name: "Яндекс", url: URL(string: "https://ya.ru/")!, symbol: "globe"),
        QuickSite(name: "Twitch", url: URL(string: "https://www.twitch.tv/")!, symbol: "bubble.left.and.text.bubble.right"),
        QuickSite(name: "GitHub", url: URL(string: "https://github.com/")!, symbol: "chevron.left.forwardslash.chevron.right"),
        QuickSite(name: "Wikipedia", url: URL(string: "https://ru.wikipedia.org/")!, symbol: "book.closed")
    ]
}

struct HomeView: View {
    @EnvironmentObject private var browser: BrowserModel
    @State private var query = ""
    @FocusState private var focused: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Rectangle().fill(browser.atmosphere.color.gradient)
            if let wallpaper = browser.wallpaper {
                GeometryReader { bounds in
                    Image(uiImage: wallpaper).resizable().scaledToFill().frame(width: bounds.size.width, height: bounds.size.height).clipped()
                }
                Color.black.opacity(browser.dim)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Label("Личное пространство", systemImage: "diamond").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(Date(), format: .dateTime.day().month(.abbreviated)).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                    }
                    hero
                    VStack(spacing: 9) {
                        HStack(spacing: 11) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                            TextField("Найти или открыть сайт", text: $query)
                                .font(.system(size: 13)).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .submitLabel(.go).focused($focused).accessibilityIdentifier("homeQuery")
                                .onSubmit(submit)
                            Button(action: submit) {
                                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.black.opacity(0.85))
                                    .frame(width: 34, height: 34).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 11))
                            }.accessibilityLabel("Открыть или найти")
                        }
                        .padding(11).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
                        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(focused ? 0.23 : 0.12)))
                        HStack {
                            Text("Поиск \(browser.searchEngine.title)")
                            Spacer()
                            Text("Попробуй «ютуб»")
                        }.font(.system(size: 8)).foregroundStyle(.white.opacity(0.35)).padding(.horizontal, 4)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Всегда под рукой").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(QuickSite.all) { site in
                                Button { browser.navigate(site.url.absoluteString) } label: {
                                    VStack(spacing: 10) {
                                        SiteIcon(url: site.url, symbol: site.symbol)
                                        Text(site.name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 89)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
                                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.07)))
                                }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                    if let page = browser.history.first {
                        VStack(alignment: .leading, spacing: 11) {
                            Text("Продолжить просмотр").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            Button { browser.navigate(page.url.absoluteString) } label: {
                                HStack(spacing: 12) {
                                    SiteIcon(url: page.url, symbol: "globe", size: 30)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(page.title).font(.system(size: 11)).lineLimit(1).foregroundStyle(.white.opacity(0.75))
                                        Text(page.url.host ?? "").font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                                    }
                                    Spacer(minLength: 3)
                                    Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                                }.padding(13).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "diamond").font(.system(size: 9))
                        Text("МЕНЬШЕ ШУМА. БОЛЬШЕ ТВОЕГО.").font(.system(size: 7)).tracking(1.1)
                    }.foregroundStyle(.white.opacity(0.25)).padding(.vertical, 5)
                }.padding(23)
            }.scrollDismissesKeyboard(.interactively)
        }
    }
    private var hero: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 13) {
                Text(greeting).font(.system(size: 8, weight: .medium)).tracking(1.8).foregroundStyle(.white.opacity(0.45))
                Text("Открой\nчто-то своё.")
                    .font(.system(size: 39, weight: .light, design: .rounded)).tracking(-1.8).lineSpacing(-2)
                Text("Любимые места. Новые открытия.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
            HStack {
                Spacer()
                Ellipse()
                    .stroke(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.13), .black, Color(white: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 25)
                    .frame(width: 99, height: 75).rotationEffect(.degrees(-38)).rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0))
                    .shadow(color: .black.opacity(0.8), radius: 18, x: 7, y: 17)
                    .offset(x: 15, y: -8).opacity(0.8)
            }.allowsHitTesting(false)
        }.frame(minHeight: 185)
    }
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<6: return "ТИХОЙ НОЧИ"
        case 6..<12: return "ДОБРОГО УТРА"
        case 12..<18: return "ХОРОШЕГО ДНЯ"
        default: return "ХОРОШЕГО ВЕЧЕРА"
        }
    }
    private func submit() { browser.navigate(query); focused = false }
}

struct SiteIcon: View {
    let url: URL
    var symbol = "globe"
    var size: CGFloat = 38
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32)
                .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.065)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let image { Image(uiImage: image).resizable().scaledToFit().padding(size * 0.2) }
            else { Image(systemName: symbol).font(.system(size: size * 0.43, weight: .regular)).foregroundStyle(.white.opacity(0.65)) }
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.32).stroke(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .task(id: url.host) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.path = url.host?.hasSuffix("wikipedia.org") == true ? "/static/favicon/wikipedia.ico" : "/favicon.ico"
            components?.query = nil
            components?.fragment = nil
            guard let iconURL = components?.url else { return }
            var request = URLRequest(url: iconURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count <= 1_000_000, !Task.isCancelled else { return }
            image = UIImage(data: data)
        }
        .accessibilityHidden(true)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
