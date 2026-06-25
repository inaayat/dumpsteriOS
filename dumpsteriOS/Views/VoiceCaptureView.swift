import SwiftUI
import Speech
import AVFoundation

struct VoiceCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var error: String?
    @State private var audioEngine = AVAudioEngine()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var saved = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Status
            if saved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.successColor)
                Text("Bullet saved!")
                    .font(.inter(17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            } else if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.warnColor)
                Text(error)
                    .font(.inter(14))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if isRecording {
                pulsingMic
                Text("Listening...")
                    .font(.inter(15, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)
                Text("Tap the mic to start")
                    .font(.inter(15))
                    .foregroundStyle(Theme.textMuted)
            }

            // Live transcription preview
            if !transcribedText.isEmpty && !saved {
                Text(transcribedText)
                    .font(.inter(16))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Record / Stop button
            if !saved {
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Theme.accent)
                            .frame(width: 80, height: 80)
                        if isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .shadow(color: (isRecording ? Color.red : Theme.accent).opacity(0.3), radius: 12, y: 4)

                if isRecording {
                    Text("Tap to stop")
                        .font(.inter(12))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            Spacer()

            // Cancel button
            Button {
                stopRecording()
                dismiss()
            } label: {
                Text(saved ? "Done" : "Cancel")
                    .font(.inter(15, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
        .onAppear { requestPermissions() }
        .onChange(of: saved) { _, isSaved in
            if isSaved {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Pulsing Mic Animation

    private var pulsingMic: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 100, height: 100)
                .scaleEffect(isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 72, height: 72)
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    error = "Speech recognition not authorized. Enable in Settings > Dumpster."
                }
            }
        }
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    error = "Microphone not authorized. Enable in Settings > Dumpster."
                }
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard error == nil else { return }

        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognition not available on this device."
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
            isRecording = true
        } catch {
            self.error = "Could not start audio engine."
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, taskError in
            if let result {
                DispatchQueue.main.async {
                    transcribedText = result.bestTranscription.formattedString
                }
            }
            if taskError != nil || (result?.isFinal == true) {
                // Recording ended naturally
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        saveBullet()
    }

    // MARK: - Save

    private func saveBullet() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard let dump = try? Queries.getOrCreateTodayDump() else { return }
        let bulletLine = "• \(text)"
        let newContent: String
        if dump.content.isEmpty {
            newContent = bulletLine
        } else {
            newContent = dump.content + "\n" + bulletLine
        }
        try? Queries.updateDumpContent(id: dump.id, content: newContent)

        // Process tags in the bullet
        if let bullet = DumpBullet.parse(from: bulletLine).first {
            for tagName in bullet.tags {
                _ = try? Queries.getOrCreateTag(name: tagName)
            }
        }
        MagicTagProcessor.processLine(bulletLine)

        saved = true
    }
}
