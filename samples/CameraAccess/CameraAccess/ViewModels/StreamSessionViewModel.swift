/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionViewModel.swift
//
// Core view model demonstrating video streaming from Meta wearable devices using the DAT SDK.
// Upgraded to DAT SDK 0.9.0 model: DeviceSession owns the connection to the glasses,
// Camera owns the camera hardware, and camera.stream carries the video frames.
// Features auto-reconnection on mid-call drop without tearing down the audio/call session.
//

import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import MWDATCamera
import MWDATCore
import SwiftUI
import UIKit
import VideoToolbox

enum StreamingStatus: Equatable {
  case streaming
  case waiting
  case stopped
}

enum StreamingMode {
  case glasses
  case iPhone
}

enum GlassesIssue: Equatable {
  case sdkUnavailable
  case permissionNeeded
  case hingesClosed
  case reconnecting
}

@MainActor
class StreamSessionViewModel: ObservableObject {
  @Published var currentVideoFrame: UIImage?
  @Published var hasReceivedFirstFrame: Bool = false
  @Published var streamingStatus: StreamingStatus = .stopped
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var hasActiveDevice: Bool = false
  @Published var streamingMode: StreamingMode = .glasses
  @Published var selectedResolution: StreamingResolution = .low
  @Published var glassesIssue: GlassesIssue?

  var isStreaming: Bool {
    streamingStatus != .stopped
  }

  var resolutionLabel: String {
    switch selectedResolution {
    case .low: return "360x640"
    case .medium: return "504x896"
    case .high: return "720x1280"
    @unknown default: return "Unknown"
    }
  }

  // Photo capture properties
  @Published var capturedPhoto: UIImage?
  @Published var showPhotoPreview: Bool = false

  // Gemini Live integration
  var geminiSessionVM: GeminiSessionViewModel?

  // WebRTC Live streaming integration
  var webrtcSessionVM: WebRTCSessionViewModel?

  // DAT 0.9 device session and camera instances
  private var deviceSession: DeviceSession?
  private var camera: Camera?

  // Stream state tracking
  private var wantsStream: Bool = false
  private var userWantsCall: Bool = false
  private var reconnectTask: Task<Void, Never>?

  // Listener tokens
  private var sessionStateListenerToken: AnyListenerToken?
  private var stateListenerToken: AnyListenerToken?
  private var videoFrameListenerToken: AnyListenerToken?
  private var errorListenerToken: AnyListenerToken?
  private var photoDataListenerToken: AnyListenerToken?

  private let wearables: WearablesInterface
  private let deviceSelector: AutoDeviceSelector
  private var deviceMonitorTask: Task<Void, Never>?
  private var iPhoneCameraManager: IPhoneCameraManager?

  private let cpuCIContext = CIContext(options: [.useSoftwareRenderer: true])
  private let videoDecoder = VideoDecoder()
  private let requestedFrameRate: UInt = 24

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    self.deviceSelector = AutoDeviceSelector(wearables: wearables)

    // Monitor device availability
    deviceMonitorTask = Task { @MainActor in
      for await device in deviceSelector.activeDeviceStream() {
        self.hasActiveDevice = device != nil
      }
    }

    setupVideoDecoder()
  }

  private func setupVideoDecoder() {
    videoDecoder.setFrameCallback { [weak self] decodedFrame in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let pixelBuffer = decodedFrame.pixelBuffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        if let cgImage = self.cpuCIContext.createCGImage(ciImage, from: rect) {
          let image = UIImage(cgImage: cgImage)
          if UIApplication.shared.applicationState != .background {
            self.currentVideoFrame = image
          }
          self.geminiSessionVM?.sendVideoFrameIfThrottled(image: image)
          self.webrtcSessionVM?.pushVideoFrame(image)
          SessionRecorder.shared.appendVideoFrame(image)
        }
      }
    }
  }

  /// Store the resolution to use for the next stream. In 0.9 the config is applied
  /// when the camera is added, so this only takes effect when not streaming.
  func updateResolution(_ resolution: StreamingResolution) {
    guard !isStreaming else { return }
    selectedResolution = resolution
    NSLog("[Stream] Resolution changed to %@", resolutionLabel)
  }

  private func streamConfig() -> StreamConfiguration {
    StreamConfiguration(
      videoCodec: VideoCodec.raw,
      resolution: selectedResolution,
      frameRate: requestedFrameRate
    )
  }

  // MARK: - Streaming Lifecycle

  func handleStartStreaming() async {
    glassesIssue = nil
    userWantsCall = true
    reconnectTask?.cancel()

    let permission = Permission.camera
    do {
      let status = try await wearables.checkPermissionStatus(permission)
      if status == .granted {
        await startSession()
        return
      }
      let requestStatus = try await wearables.requestPermission(permission)
      if requestStatus == .granted {
        await startSession()
        return
      }
      glassesIssue = .permissionNeeded
      showError("Camera permission denied")
    } catch {
      let text = String(describing: error).lowercased()
      if text.contains("powered off") || text.contains("disconnected") || text.contains("no device") {
        NSLog("[Stream] glasses unavailable, waiting: %@", String(describing: error))
        glassesIssue = nil
      } else {
        glassesIssue = .reconnecting
      }
    }
  }

  /// Creates and starts the DeviceSession, then streams once it reaches `.started`.
  func startSession() async {
    guard deviceSession == nil else {
      wantsStream = true
      if deviceSession?.state == .started, camera == nil {
        beginStream()
      }
      return
    }

    wantsStream = true
    do {
      let session = try wearables.createSession(deviceSelector: deviceSelector)
      deviceSession = session
      observeSession(session)
      streamingStatus = .waiting
      try session.start()
    } catch {
      glassesIssue = mapDeviceSessionError(error)
      deviceSession = nil
      if userWantsCall {
        streamingStatus = .waiting
        scheduleReconnect()
      } else {
        wantsStream = false
        streamingStatus = .stopped
      }
    }
  }

  private func observeSession(_ session: DeviceSession) {
    sessionStateListenerToken = session.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in
        self?.handleSessionState(state)
      }
    }
  }

  private func handleSessionState(_ state: DeviceSessionState) {
    switch state {
    case .started:
      if wantsStream, camera == nil {
        beginStream()
      }
    case .idle, .stopped:
      camera = nil
      deviceSession = nil
      currentVideoFrame = nil
      if userWantsCall {
        glassesIssue = .reconnecting
        streamingStatus = .waiting
        scheduleReconnect()
      } else {
        wantsStream = false
        streamingStatus = .stopped
      }
    case .starting, .stopping, .paused:
      streamingStatus = .waiting
    }
  }

  /// Adds a camera to the started session and wires its stream's listeners.
  private func beginStream() {
    guard let session = deviceSession, session.state == .started else { return }
    do {
      guard let newCamera = try session.addCamera(config: streamConfig()) else {
        glassesIssue = .reconnecting
        return
      }
      camera = newCamera
      attachStreamListeners(to: newCamera.stream)
      newCamera.stream.start()
    } catch {
      camera = nil
      glassesIssue = mapDeviceSessionError(error)
    }
  }

  private func attachStreamListeners(to stream: MWDATCamera.Stream) {
    // Stream state listener
    stateListenerToken = stream.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in
        self?.updateStatusFromState(state)
      }
    }

    // Video frame listener
    videoFrameListenerToken = stream.videoFramePublisher.listen { [weak self] videoFrame in
      Task { @MainActor [weak self] in
        guard let self else { return }

        if let image = videoFrame.makeUIImage() {
          self.currentVideoFrame = image
          if !self.hasReceivedFirstFrame {
            self.hasReceivedFirstFrame = true
          }
          // Forward video frames to Gemini Live (throttled internally to ~1fps)
          self.geminiSessionVM?.sendVideoFrameIfThrottled(image: image)
          // Forward video frames to WebRTC
          self.webrtcSessionVM?.pushVideoFrame(image)
        }
      }
    }

    // Stream error listener
    errorListenerToken = stream.errorPublisher.listen { [weak self] error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        switch error {
        case .deviceNotConnected, .deviceNotFound:
          self.glassesIssue = nil
        case .hingesClosed:
          self.glassesIssue = .hingesClosed
        case .permissionDenied:
          self.glassesIssue = .permissionNeeded
        default:
          self.glassesIssue = .reconnecting
        }

        // Only show modal alerts when app is active
        if UIApplication.shared.applicationState == .active && self.streamingStatus != .stopped {
          let msg = error.localizedDescription
          if !msg.isEmpty && msg != self.errorMessage {
            self.showError(msg)
          }
        }
      }
    }

    // Photo capture listener
    photoDataListenerToken = stream.photoDataPublisher.listen { [weak self] photoData in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let uiImage = UIImage(data: photoData.data) {
          self.capturedPhoto = uiImage
          self.showPhotoPreview = true
        }
      }
    }
  }

  /// Stops camera and ends session.
  func stopSession() async {
    if streamingMode == .iPhone {
      stopIPhoneSession()
      return
    }

    userWantsCall = false
    reconnectTask?.cancel()
    reconnectTask = nil
    wantsStream = false

    if let camera {
      camera.stop()
    }
    deviceSession?.stop()
    camera = nil
    deviceSession = nil
    streamingStatus = .stopped
  }

  /// Auto-reconnect loop on a 1.5s cadence when stream drops mid-call
  private func scheduleReconnect() {
    guard userWantsCall else { return }
    reconnectTask?.cancel()
    reconnectTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      guard let self, !Task.isCancelled, self.userWantsCall,
            self.streamingStatus != .streaming else { return }
      NSLog("[Stream] auto-reconnecting glasses...")
      if self.deviceSession == nil {
        await self.startSession()
      } else if self.camera == nil, self.deviceSession?.state == .started {
        self.beginStream()
      }
      if self.streamingStatus != .streaming, self.userWantsCall {
        self.scheduleReconnect()
      }
    }
  }

  private func mapDeviceSessionError(_ error: Error) -> GlassesIssue? {
    if let deviceError = error as? DeviceSessionError {
      switch deviceError {
      case .noEligibleDevice:
        return nil
      default:
        return .reconnecting
      }
    }
    return .reconnecting
  }

  private func updateStatusFromState(_ state: MWDATCamera.Stream.State) {
    switch state {
    case .stopped:
      currentVideoFrame = nil
      if userWantsCall {
        glassesIssue = .reconnecting
        streamingStatus = .waiting
        scheduleReconnect()
      } else {
        streamingStatus = .stopped
      }
    case .streaming:
      glassesIssue = nil
      streamingStatus = .streaming
    default:
      streamingStatus = .waiting
    }
  }

  // MARK: - iPhone Camera Mode

  func handleStartIPhone() async {
    let granted = await IPhoneCameraManager.requestPermission()
    if granted {
      startIPhoneSession()
    } else {
      showError("Camera permission denied. Please grant access in Settings.")
    }
  }

  private func startIPhoneSession() {
    streamingMode = .iPhone
    let camera = IPhoneCameraManager()
    camera.onFrameCaptured = { [weak self] image in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.currentVideoFrame = image
        if !self.hasReceivedFirstFrame {
          self.hasReceivedFirstFrame = true
        }
        self.geminiSessionVM?.sendVideoFrameIfThrottled(image: image)
        self.webrtcSessionVM?.pushVideoFrame(image)
        SessionRecorder.shared.appendVideoFrame(image)
      }
    }
    camera.start()
    iPhoneCameraManager = camera
    streamingStatus = .streaming
    NSLog("[Stream] iPhone camera mode started")
  }

  private func stopIPhoneSession() {
    iPhoneCameraManager?.stop()
    iPhoneCameraManager = nil
    currentVideoFrame = nil
    hasReceivedFirstFrame = false
    streamingStatus = .stopped
    streamingMode = .glasses
    NSLog("[Stream] iPhone camera mode stopped")
  }

  // MARK: - Photo & UI Helpers

  func capturePhoto() {
    guard let stream = camera?.stream else {
      showError("Stream not active for photo capture")
      return
    }
    _ = stream.capturePhoto(format: .jpeg)
  }

  func dismissPhotoPreview() {
    showPhotoPreview = false
    capturedPhoto = nil
  }

  private func showError(_ message: String) {
    errorMessage = message
    showError = true
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }
}
