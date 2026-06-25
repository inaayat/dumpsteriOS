import SwiftUI

@Observable
final class VoiceCaptureCoordinator {
    static let shared = VoiceCaptureCoordinator()
    var showVoiceCapture = false

    private init() {}

    func triggerCapture() {
        showVoiceCapture = true
    }
}
