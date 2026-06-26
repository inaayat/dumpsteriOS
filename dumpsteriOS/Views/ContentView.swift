import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    private var voiceCoordinator = VoiceCaptureCoordinator.shared

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("Dump", systemImage: "flame.fill", value: .dump) {
                NavigationStack {
                    DumpView(appState: appState)
                }
            }

            Tab("Items", systemImage: "square.stack.fill", value: .items) {
                NavigationStack {
                    ItemsView(appState: appState)
                }
            }

            Tab("Tags", systemImage: "number", value: .tags) {
                NavigationStack {
                    TagsView(appState: appState)
                }
            }

            Tab("Docs", systemImage: "doc.text.fill", value: .docs) {
                NavigationStack {
                    DocsListView(appState: appState)
                }
            }

            Tab("Guide", systemImage: "book.fill", value: .guide) {
                NavigationStack {
                    GuideView()
                }
            }
        }
        .tint(Theme.accent)
        .onAppear {
            _ = DatabaseManager.shared
            try? Queries.promoteDueSoonToHigh()
            appState.refreshCounts()
        }
        .sheet(isPresented: .init(
            get: { voiceCoordinator.showVoiceCapture },
            set: { voiceCoordinator.showVoiceCapture = $0 }
        )) {
            VoiceCaptureView()
        }
        .onOpenURL { url in
            if url.scheme == "dumpster" && url.host == "voice-bullet" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    voiceCoordinator.triggerCapture()
                }
            }
        }
    }
}
