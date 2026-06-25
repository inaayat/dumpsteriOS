import SwiftUI

@main
struct dumpsteriOSApp: App {
    init() {
        FontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.host == "voice-add" {
                        VoiceCaptureCoordinator.shared.triggerCapture()
                    }
                }
        }
    }
}
