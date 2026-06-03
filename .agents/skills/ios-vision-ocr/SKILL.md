---
description: How to listen for physical screenshots on iOS and secretly extract their text locally using Apple Vision to feed AI context.
---
# Contextual Screenshot OCR on iOS

When building voice or AR assistants on iOS, Apple's sandyboxing strictly prohibits continuous background screen recording (without complex ReplayKit broadcast extensions). If a user wants to ask the AI "What does this email mean?", you can't see their screen.

A powerful workaround is the **Contextual Screenshot OCR** pattern. The user takes a standard iPhone screenshot, and the app grabs the resulting image from the Photo Library to read its text.

## 1. Required Permissions
In `Info.plist`, you must request Photo Library access:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your recent screenshot to provide context to the AI.</string>
```

## 2. OCRService (Native Apple Vision)
Do not send huge images to an LLM over the network if you only need the text. Use the local `Vision` framework. It is fast, accurate, and offline.

```swift
import Vision

class OCRService {
    static let shared = OCRService()
    
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.invalid }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { return continuation.resume(throwing: error) }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return continuation.resume(returning: "")
                }
                
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate 
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
```

## 3. Listen for Screenshots (`UIApplication.userDidTakeScreenshotNotification`)
In your SwiftUI View or ViewController, observe the system screenshot notification.

```swift
@State private var ocrContext: String? = nil

var body: some View {
    MainView()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            captureScreenshotContext()
        }
}

private func captureScreenshotContext() {
    Task {
        // 1. Request access
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        
        // 2. Fetch the *most recent* image (the screenshot just taken)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        guard let latestAsset = PHAsset.fetchAssets(with: .image, options: fetchOptions).firstObject else { return }
        
        // 3. Load the UIImage
        PHImageManager.default().requestImage(for: latestAsset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: .init()) { image, _ in
            guard let image = image else { return }
            
            // 4. Run OCR
            Task {
                let text = try await OCRService.shared.extractText(from: image)
                await MainActor.run { 
                    self.ocrContext = text 
                    // Optional: Play a haptic tick to confirm to the user!
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}
```

## 4. Injecting into Context
When the user issues their next voice command (`"Summarize this!"`), inject `ocrContext` into the prompt under the hood, then clear it.

```swift
var finalPrompt = userCommand
if let context = ocrContext {
    finalPrompt = "Context from my recent phone screenshot: \"\(context)\"\n\nUser command: \(userCommand)"
    ocrContext = nil // Clear it so it's not reused
}
```
