---
description: How to intercept iOS notifications locally and read them aloud through smart glasses or headphones without user wake words.
---
# iOS Proactive TTS Notifications

Smart glasses shouldn't just wait to be spoken to. They should proactively alert you to time-sensitive events (like a meeting starting in 5 minutes) by reading the notification out loud. 

However, iOS strongly sandboxes third-party background execution and notification interception. You cannot easily read an incoming WhatsApp message natively. But you *can* schedule and read your own app's local notifications or integrate with a backend event stream.

## 1. Requesting `UNUserNotificationCenter`

First, ask the user for permission.

```swift
import UserNotifications

func requestNotificationAccess() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
        if granted {
            print("Notification access granted!")
        }
    }
}
```

## 2. Triggering Speech on Notification

When a notification arrives (either a local push you scheduled via `UNTimeIntervalNotificationTrigger`, or a Remote Push from your server), the `UNUserNotificationCenterDelegate`'s `willPresent` method fires.

This is where the magic happens: instead of just letting iOS show a banner on the locked phone, you intercept it and pump it through your `TTSService` (Text-To-Speech) via `AVAudioSession`.

```swift
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // Fires when a notification arrives while the app is in the FOREGROUND or active background mode (like when streaming audio)
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let title = notification.request.content.title
        let body = notification.request.content.body
        let fullSpeech = "You have a new alert: \(title). \(body)"
        
        // Use Apple's native AVSpeechSynthesizer to speak through the actively connected Bluetooth glasses!
        TTSService.shared.speak(fullSpeech)
        
        // Still show the banner on the phone screen just in case
        completionHandler([.banner, .sound]) 
    }
    
    // Fires when the user taps on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let body = response.notification.request.content.body
        // The user tapped the notification, maybe open a specific chat thread
        print("User tapped on: \(body)")
        completionHandler()
    }
}
```

## 3. Server-Sent Events (SSE) instead of APNS

Because relying on Apple Push Notification Service (APNS) or Background Modes can be flaky, a more reliable pattern for an active smart-glasses session is holding a WebSocket or SSE connection open.

If your backend needs to remind the user of a meeting, it sends a payload down the `wss://` socket.

```json
{
  "event": "proactive_alert",
  "text": "Your 3PM Zoom meeting with Sarah is starting in 2 minutes."
}
```

Your iOS Swift client parses this and immediately calls `TTSService.shared.speak(text)`. This bypasses `UNUserNotificationCenter` entirely for events originating from your own AI framework (like OpenClaw).
