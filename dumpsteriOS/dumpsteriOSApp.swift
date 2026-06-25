import SwiftUI

@main
struct dumpsteriOSApp: App {
    init() {
        FontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
