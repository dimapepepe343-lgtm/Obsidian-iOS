import SwiftUI

@main
struct ObsidianApp: App {
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserRoot()
                .environmentObject(browser)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
