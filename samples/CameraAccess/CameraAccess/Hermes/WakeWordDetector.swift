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
    var onStopDetected: (() -> Void)?
    var onStopVideoDetected: (() -> Void)?

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

            // Check for stop commands first (stop video vs stop audio)
            if self.matchesStopVideo(text: transcription) {
                self.lastDetectedPhrase = transcription
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.onStopVideoDetected?()
                return
            } else if self.matchesStop(text: transcription) {
                self.lastDetectedPhrase = transcription
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.onStopDetected?()
                return
            }

            // Check if the wake phrase appears with word boundary matching
            if self.matchesPhrase(text: transcription, phrase: wakePhrase) {
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

    // MARK: - Word Boundary Matching Helpers

    func matchesPhrase(text: String, phrase: String) -> Bool {
        let cleanText = text.lowercased()
        let cleanPhrase = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPhrase.isEmpty else { return false }
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: cleanPhrase).replacingOccurrences(of: "\\ ", with: "\\s+") + "\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(cleanText.startIndex..., in: cleanText)
            return regex.firstMatch(in: cleanText, options: [], range: range) != nil
        }
        return cleanText.contains(cleanPhrase)
    }

    func matchesStop(text: String) -> Bool {
        let stopKeywords = ["stop", "quiet", "silence", "enough", "para", "basta", "silencio", "cállate"]
        let stopPhrases = ["be quiet", "shut up", "ok stop", "okay stop", "stop talking", "para de hablar", "guarda silencio"]
        let lower = text.lowercased()
        if stopPhrases.contains(where: { lower.contains($0) }) { return true }
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        return !words.isDisjoint(with: Set(stopKeywords))
    }

    func matchesStopVideo(text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("stop video") || lower.contains("detener video") || lower.contains("cerrar video") || lower.contains("terminar llamada")
    }
}
