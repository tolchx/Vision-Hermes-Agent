import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Photos
import UIKit
import Combine

/// Records POV video streams from Meta Ray-Ban glasses or iPhone camera directly to the iOS Photos library,
/// with dual digital audio mixing (user speech from microphone + assistant voice from Gemini Live).
@MainActor
final class SessionRecorder: ObservableObject {
  static let shared = SessionRecorder()

  // MARK: - Published UI Properties

  @Published private(set) var isRecording: Bool = false
  @Published private(set) var duration: TimeInterval = 0
  @Published private(set) var isSaving: Bool = false
  @Published private(set) var lastSavedURL: URL? = nil
  @Published var errorMessage: String? = nil
  @Published var toastMessage: String? = nil

  var formattedDuration: String {
    let totalSeconds = Int(duration)
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  // MARK: - Internal Recording State (Protected by queue)

  private let queue = DispatchQueue(label: "hermes.session.recorder", qos: .userInitiated)
  private var active: Bool = false
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var tempVideoURL: URL?
  private var videoStartTime: CFAbsoluteTime?
  private var frameCount: Int = 0
  private var targetSize: CGSize = CGSize(width: 1080, height: 1440)

  // Audio capture
  private var micAudioFile: AVAudioFile?
  private var tempMicURL: URL?
  private var aiAudioFile: AVAudioFile?
  private var tempAIURL: URL?
  private var aiSegmentStartTime: TimeInterval?

  // Timer
  private var timer: Timer?

  private init() {}

  // MARK: - Recording Control

  func startRecording(size: CGSize = CGSize(width: 1080, height: 1440)) {
    guard !isRecording else { return }

    targetSize = size
    duration = 0
    errorMessage = nil
    toastMessage = nil

    let tempDir = FileManager.default.temporaryDirectory
    let runId = UUID().uuidString
    let videoURL = tempDir.appendingPathComponent("hermes_rec_video_\(runId).mp4")
    let micURL = tempDir.appendingPathComponent("hermes_rec_mic_\(runId).caf")
    let aiURL = tempDir.appendingPathComponent("hermes_rec_ai_\(runId).caf")

    // Cleanup old files if any
    try? FileManager.default.removeItem(at: videoURL)
    try? FileManager.default.removeItem(at: micURL)
    try? FileManager.default.removeItem(at: aiURL)

    self.tempVideoURL = videoURL
    self.tempMicURL = micURL
    self.tempAIURL = aiURL

    // 1. Setup Video Writer
    do {
      let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)

      let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(targetSize.width),
        AVVideoHeightKey: Int(targetSize.height),
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
      ]

      let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
      input.expectsMediaDataInRealTime = true

      let sourceAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: Int(targetSize.width),
        kCVPixelBufferHeightKey as String: Int(targetSize.height)
      ]

      let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: sourceAttributes
      )

      if writer.canAdd(input) {
        writer.add(input)
      }

      self.assetWriter = writer
      self.videoInput = input
      self.pixelBufferAdaptor = adaptor

      writer.startWriting()
      writer.startSession(atSourceTime: .zero)
    } catch {
      NSLog("[SessionRecorder] Failed to initialize AVAssetWriter: %@", error.localizedDescription)
      self.errorMessage = "Error initializing video recorder: \(error.localizedDescription)"
      return
    }

    // 2. Setup Standard Float32 44.1kHz mono Audio Files
    let standardFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 44100.0,
      channels: 1,
      interleaved: false
    )!

    do {
      micAudioFile = try AVAudioFile(
        forWriting: micURL,
        settings: standardFormat.settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false
      )
    } catch {
      NSLog("[SessionRecorder] Failed to create mic audio file: %@", error.localizedDescription)
    }

    do {
      aiAudioFile = try AVAudioFile(
        forWriting: aiURL,
        settings: standardFormat.settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false
      )
    } catch {
      NSLog("[SessionRecorder] Failed to create AI audio file: %@", error.localizedDescription)
    }

    queue.sync {
      self.active = true
      self.frameCount = 0
      self.videoStartTime = nil
      self.aiSegmentStartTime = nil
    }

    isRecording = true
    let startTime = CFAbsoluteTimeGetCurrent()

    // Timer for duration updates
    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.isRecording else { return }
        self.duration = CFAbsoluteTimeGetCurrent() - startTime
      }
    }

    NSLog("[SessionRecorder] Started recording POV demo session (%dx%d)", Int(targetSize.width), Int(targetSize.height))
  }

  // MARK: - Frame & Audio Append (Thread-Safe)

  nonisolated func appendVideoFrame(_ image: UIImage) {
    queue.async {
      guard self.active,
            let adaptor = self.pixelBufferAdaptor,
            let writer = self.assetWriter,
            writer.status == .writing,
            adaptor.assetWriterInput.isReadyForMoreMediaData else {
        return
      }

      let now = CFAbsoluteTimeGetCurrent()
      if self.videoStartTime == nil {
        self.videoStartTime = now
      }
      let elapsed = now - (self.videoStartTime ?? now)
      let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)

      if let pixelBuffer = self.createPixelBuffer(from: image, targetSize: self.targetSize) {
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        self.frameCount += 1
      }
    }
  }

  nonisolated func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
    queue.async {
      guard self.active,
            let adaptor = self.pixelBufferAdaptor,
            let writer = self.assetWriter,
            writer.status == .writing,
            adaptor.assetWriterInput.isReadyForMoreMediaData else {
        return
      }

      let now = CFAbsoluteTimeGetCurrent()
      if self.videoStartTime == nil {
        self.videoStartTime = now
      }
      let elapsed = now - (self.videoStartTime ?? now)
      let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)

      adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
      self.frameCount += 1
    }
  }

  nonisolated func appendMicAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    queue.async {
      guard self.active, let file = self.micAudioFile else { return }
      try? file.write(from: buffer)
    }
  }

  nonisolated func appendAIAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    queue.async {
      guard self.active, let file = self.aiAudioFile else { return }
      if self.aiSegmentStartTime == nil, let start = self.videoStartTime {
        self.aiSegmentStartTime = CFAbsoluteTimeGetCurrent() - start
      }
      try? file.write(from: buffer)
    }
  }

  // MARK: - Stop and Save to Photos

  @discardableResult
  func stopRecording() async -> URL? {
    guard isRecording else { return nil }

    isRecording = false
    timer?.invalidate()
    timer = nil
    isSaving = true

    queue.sync {
      self.active = false
    }

    NSLog("[SessionRecorder] Stopping recording (%d frames, %.1fs)", frameCount, duration)

    // Finish video writer
    videoInput?.markAsFinished()
    await withCheckedContinuation { continuation in
      if let writer = self.assetWriter, writer.status == .writing {
        writer.finishWriting {
          continuation.resume()
        }
      } else {
        continuation.resume()
      }
    }

    // Close audio files
    micAudioFile = nil
    aiAudioFile = nil

    guard let videoURL = tempVideoURL else {
      isSaving = false
      return nil
    }

    // Mux video + audio
    let finalURL = await muxMedia(videoURL: videoURL, micURL: tempMicURL, aiURL: tempAIURL)

    // Save to Photos
    let saved = await saveVideoToPhotoLibrary(fileURL: finalURL)
    isSaving = false

    if saved {
      lastSavedURL = finalURL
      toastMessage = "Video POV guardado en Fotos"
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(.success)
    } else {
      toastMessage = "No se pudo guardar en Fotos"
    }

    // Cleanup temp input files
    try? FileManager.default.removeItem(at: videoURL)
    if let m = tempMicURL { try? FileManager.default.removeItem(at: m) }
    if let a = tempAIURL { try? FileManager.default.removeItem(at: a) }

    return finalURL
  }

  // MARK: - Media Muxing

  private func muxMedia(videoURL: URL, micURL: URL?, aiURL: URL?) async -> URL {
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: videoURL)

    guard let assetVideoTrack = try? await videoAsset.loadTracks(withMediaType: .video).first else {
      return videoURL
    }

    let videoDuration: CMTime
    do {
      videoDuration = try await videoAsset.load(.duration)
    } catch {
      return videoURL
    }

    // Insert video track
    guard let compVideoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      return videoURL
    }

    try? compVideoTrack.insertTimeRange(
      CMTimeRange(start: .zero, duration: videoDuration),
      of: assetVideoTrack,
      at: .zero
    )

    // Insert Mic Audio track if valid
    if let micURL, FileManager.default.fileExists(atPath: micURL.path) {
      let micAsset = AVURLAsset(url: micURL)
      if let micTrack = try? await micAsset.loadTracks(withMediaType: .audio).first,
         let micDuration = try? await micAsset.load(.duration),
         micDuration.seconds > 0,
         let compMicTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        let insertDuration = CMTimeMinimum(videoDuration, micDuration)
        try? compMicTrack.insertTimeRange(
          CMTimeRange(start: .zero, duration: insertDuration),
          of: micTrack,
          at: .zero
        )
      }
    }

    // Insert AI Audio track if valid
    if let aiURL, FileManager.default.fileExists(atPath: aiURL.path) {
      let aiAsset = AVURLAsset(url: aiURL)
      if let aiTrack = try? await aiAsset.loadTracks(withMediaType: .audio).first,
         let aiDuration = try? await aiAsset.load(.duration),
         aiDuration.seconds > 0,
         let compAITrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        let startTime = CMTime(seconds: aiSegmentStartTime ?? 0, preferredTimescale: 600)
        let insertDuration = CMTimeMinimum(videoDuration - startTime, aiDuration)
        if insertDuration.seconds > 0 {
          try? compAITrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: insertDuration),
            of: aiTrack,
            at: startTime
          )
        }
      }
    }

    // Export final output
    let tempDir = FileManager.default.temporaryDirectory
    let finalURL = tempDir.appendingPathComponent("VisionHermes_POV_\(Int(Date().timeIntervalSince1970)).mp4")
    try? FileManager.default.removeItem(at: finalURL)

    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      return videoURL
    }

    exportSession.outputURL = finalURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true

    await exportSession.export()

    if exportSession.status == .completed {
      return finalURL
    } else {
      NSLog("[SessionRecorder] Export failed: %@", exportSession.error?.localizedDescription ?? "unknown error")
      return videoURL
    }
  }

  // MARK: - Photos Library Saving

  private func saveVideoToPhotoLibrary(fileURL: URL) async -> Bool {
    let authorized = await requestPhotoLibraryPermission()
    guard authorized else {
      NSLog("[SessionRecorder] Photo library permission denied")
      return false
    }

    return await withCheckedContinuation { continuation in
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
      }) { success, error in
        if let error {
          NSLog("[SessionRecorder] Failed to save video to Photos: %@", error.localizedDescription)
        } else {
          NSLog("[SessionRecorder] Video successfully saved to Photos!")
        }
        continuation.resume(returning: success)
      }
    }
  }

  private func requestPhotoLibraryPermission() async -> Bool {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    switch status {
    case .authorized, .limited:
      return true
    case .notDetermined:
      return await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
          continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
        }
      }
    default:
      return false
    }
  }

  // MARK: - Pixel Buffer Helper

  nonisolated private func createPixelBuffer(from image: UIImage, targetSize: CGSize) -> CVPixelBuffer? {
    let attrs: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(targetSize.width),
      Int(targetSize.height),
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let pxData = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
      data: pxData,
      width: Int(targetSize.width),
      height: Int(targetSize.height),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: rgbColorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
      return nil
    }

    if let cg = image.cgImage {
      context.draw(cg, in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
    }
    return buffer
  }
}
