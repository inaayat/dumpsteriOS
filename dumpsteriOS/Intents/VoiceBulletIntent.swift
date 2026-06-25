import AppIntents

struct VoiceBulletIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Voice Bullet"
    static var description: IntentDescription = "Record a voice note and add it as a bullet to your daily dump."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCaptureCoordinator.shared.triggerCapture()
        return .result()
    }
}

struct DumpsterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VoiceBulletIntent(),
            phrases: [
                "Add a bullet to \(.applicationName)",
                "Voice note in \(.applicationName)",
                "Quick add to \(.applicationName)"
            ],
            shortTitle: "Voice Bullet",
            systemImageName: "mic.fill"
        )
    }
}
