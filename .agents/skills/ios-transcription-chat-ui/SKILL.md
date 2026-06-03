---
name: iOS Transcription Chat UI
description: Guidelines and specifications for implementing the glassmorphic Transcription Chat Mode UI based on OpenVision, specifically designed for AI voice agent interactions in other iOS apps.
---

# iOS Transcription Chat UI Guidelines

This skill provides the visual and structural characteristics of the "Transcription Chat Mode" UI. Use these guidelines when integrating this UI into another iOS application.

## 1. Core Visual Principles
- **Glassmorphism**: Heavy reliance on translucent "glass" cards with varying opacities and thin borders.
- **Dynamic Backgrounds**: Use animated backgrounds layered with subtle particle effects (e.g., opacity around 0.5) to give a sense of depth and activity.
- **Gradients & Glows**: Accentuate AI elements with purple-to-blue linear gradients and soft drop shadows.

## 2. Chat Bubbles (ChatMessageBubble)
Chat bubbles should differentiate clearly between the User and the AI Assistant.

### User Messages
- **Alignment**: Right-aligned (with leading spacer).
- **Background**: Glass card with `0.2` opacity.
- **Border/Stroke**: `Color.blue.opacity(0.3)` with a line width of 1.
- **Text Color**: White.

### Assistant Messages
- **Alignment**: Left-aligned (with trailing spacer).
- **Background**: Glass card with `0.1` opacity.
- **Border/Stroke**: `Color.purple.opacity(0.3)` with a line width of 1.
- **Text Color**: White.
- **Avatar**: A "sparkles" icon (`systemName: "sparkles"`) inside a circle. The circle has a `LinearGradient` (purple to blue), with a purple shadow (`radius: 4`).

### Image Attachments
- Images shared in the chat should be constrained (e.g., `maxWidth: 200`, `height: 150`), using `.scaledToFill()`, and clipped with a `RoundedRectangle(cornerRadius: 12)`.

## 3. Live Transcription / Active Turn (ActiveTurnBubble)
When the user is speaking or the AI is generating text, use a live streaming layout.

### Live User Input
- **Styling**: Similar to User Messages, but with specific opacity changes.
- **Text Color**: `White.opacity(0.8)`.
- **Background**: Glass card with `0.15` opacity.
- **Border/Stroke**: `Color.blue.opacity(0.5)`.

### Live AI Output
- **Pulsing Avatar**: The AI Avatar should pulse when the AI is streaming (scale from `1.0` to `1.1` in a repeating `easeInOut` animation).
- **Styling**: Glass card with `0.2` opacity, border stroke of `Color.purple.opacity(0.6)`.
- **Thinking Indicator**: If the AI is "thinking" but hasn't produced text, show three small white dots (`0.5` opacity) inside a small glass bubble (`0.1` opacity).

## 4. Input Area & Action Bar
The bottom area should allow for text/photo input alongside voice activation.

- **Text Field**: Pill-shaped (`cornerRadius: 24`), `White.opacity(0.1)` background, thin translucent stroke.
- **Interactive Mic Orb**: A compact round button representing the microphone.
  - While listening or thinking, wrap the microphone orb with an outer circle stroke (`Color.blue.opacity(0.5)`) that pulses based on the real-time audio input level (e.g., `scaleEffect(1.0 + audioLevel)`).

## 5. Agent States & Top Bar
- **Top Bar Pill**: Use an `.ultraThinMaterial` capsule to house utility icons and connection labels.
- **Agent Colors**: Map the agent's state to aesthetic color accents (e.g., in status pills):
  - Idle: Gray
  - Connecting/Running Tool: Orange
  - Listening: Blue
  - Thinking: Purple
  - Speaking: Green
  - Live Video Mode: Red

## 6. Layout Hierarchy
- **ZStack Base**: 
  1. Animated Background
  2. Particle Effect (ignores safe area)
  3. Main VStack containing Top Bar, Chat History ScrollView, and Bottom Input Box.
- **Animations**: Transition the state changes and live transcript updates with `.spring(response: 0.4)` to make it feel natural and snappy.
