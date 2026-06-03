---
description: How to dynamically alter iOS audio routing streams during a bidirectional translation mode for smart glasses.
---
# iOS Translation Audio Routing 

Building a fluent "Star Trek Translator" experience with smart glasses involves two actors (the Glasses Wearer and the Foreign Speaker). A bidirectional translation mode requires aggressive manipulation of iOS audio routing (`AVAudioSession`) to ensure playback is directed to the appropriate hardware speaker at the exact right moment.

## 1. The Scenario

1. **Wearer speaks Spanish**. Audio is captured via Glasses Mic.
2. AI translates to English. 
3. **Crucial Step:** AI speaks English, but we route iOS audio to the **iPhone's bottom loudspeaker**, pointing it at the foreign speaker so they hear it loud and clear. (If played in the glasses, the foreign speaker wouldn't hear it).
4. **Foreign Speaker replies in English**. iPhone captures via bottom Mic or Glasses Mic.
5. AI translates to Spanish.
6. **Crucial Step:** We route audio back to the **Glasses Bluetooth earpiece** so the wearer hears the translation privately.

## 2. Managing the `AVAudioSession`

In iOS, `AVAudioSession.sharedInstance()` controls where audio plays. 

Usually, when Bluetooth is connected, iOS aggressively defaults all playback to the Bluetooth device (the glasses). To play audio out of the iPhone speaker while the glasses are connected, we must override the port.

```swift
import AVFoundation

enum TranslationDirection {
    case toLoudspeaker  // For the foreign person to hear
    case toGlasses      // For the wearer to hear privately
}

class AudioRoutingManager {
    static let shared = AudioRoutingManager()
    
    func setRoute(for direction: TranslationDirection) {
        let session = AVAudioSession.sharedInstance()
        
        do {
            // Ensure the category allows playback and recording
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            
            switch direction {
            case .toLoudspeaker:
                // Force audio out the bottom speaker of the iPhone
                print("Routing audio to iPhone Loudspeaker")
                try session.overrideOutputAudioPort(.speaker)
                
            case .toGlasses:
                // Remove the speaker override; iOS will fall back to the connected Bluetooth glasses
                print("Routing audio back to Bluetooth Glasses")
                try session.overrideOutputAudioPort(.none)
            }
            
            try session.setActive(true)
            
        } catch {
            print("Failed to change audio route: \(error.localizedDescription)")
        }
    }
}
```

## 3. Handling Live Streams

If you are using a WebSocket streaming API (like Gemini Live), manipulating the `AVAudioSession` while audio is actively playing can sometimes cause the `AVAudioEngine` to crash or glitch.

To do this safely:
1. **Pause** the `AVAudioPlayerNode`.
2. Apply the `overrideOutputAudioPort` change.
3. **Resume** the `AVAudioPlayerNode`.

## 4. Instructing the AI

To make the bidirectional translation work, explicitly instruct the AI to act as a bridging interpreter in your System Prompt.

```swift
let interpreterPrompt = """
You are a real-time bilingual interpreter between Spanish and English.
The user wearing the smart glasses speaks Spanish.
The person they are talking to speaks English.

RULES:
1. If you hear Spanish, you MUST translate and speak the response in English.
2. If you hear English, you MUST translate and speak the response in Spanish.
3. Only output the direct translation. Do not summarize or add conversational filler.
"""
```

When the AI stream begins to respond, you can detect the language of the output text (if known) or rely on a strict turn-based system to flip the `AudioRoutingManager.setRoute()`.
