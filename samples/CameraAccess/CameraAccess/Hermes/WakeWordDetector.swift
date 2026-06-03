import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
class WakeWordDetector: ObservableObject {
    @Published var isListening = false
    @Published var lastDetectedPhrase: String?
    @Published var errorMessage: String?

    var onWakeWordDetected: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var isProcessing = false

    private let settings = SettingsManager.shared

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.queue = .main
    }

    var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func requestAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
        }
        return false
    }

    func startListening() {
        guard settings.enableWakeWord else {
            stopListening()
            return
        }

        guard isAvailable else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        guard !audioEngine.isRunning else { return }

        isProcessing = false
        isListening = true
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [.mixWithOthers, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            stopListening()
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Configure recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search  // optimized for short phrases

        // Remove previous tap if any
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Engine start error: \(error.localizedDescription)"
            stopListening()
            return
        }

        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error as? NSError {
                if error.code != 1 && error.code != 216 { // ignore "canceled" / "no speech"
                    self.errorMessage = "Recognition error: \(error.localizedDescription)"
                }
                return
            }

            guard let result = result, result.isFinal == false else { return }
            let transcription = result.bestTranscription.formattedString.lowercased()
            let wakePhrase = self.settings.wakePhrase.lowercased()

            // Check if the wake phrase appears anywhere in the transcription
            if transcription.contains(wakePhrase) {
                self.lastDetectedPhrase = transcription
                self.isProcessing = true
                // Brief haptic feedback
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

                // Stop listening and trigger
                self.stopListening()
                self.onWakeWordDetected?()
            }
        }
    }

    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isListening = false
        isProcessing = false

        // Deactivate audio session but keep background alive for other audio
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            Task { [weak self] in
                guard let self = self else { return }
                let authorized = await requestAuthorization()
                if authorized {
                    startListening()
                } else {
                    errorMessage = "Please grant speech recognition permission in Settings"
                }
            }
        }
    }
}
