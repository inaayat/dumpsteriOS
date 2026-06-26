import WidgetKit
import SwiftUI
import AppIntents

// Mirror of the main app's VoiceBulletIntent — iOS routes perform() to the main app
// because openAppWhenRun = true. Widget extension only needs the type for configuration.
struct VoiceBulletIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Voice Bullet"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct VoiceBulletControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.dumpster.voiceBulletControl") {
            ControlWidgetButton(action: VoiceBulletIntent()) {
                Label("Voice Bullet", systemImage: "trash.fill")
            }
        }
        .displayName("Voice Bullet")
        .description("Tap to record a voice note and add it to your daily dump.")
    }
}
