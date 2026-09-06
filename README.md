# VisionHermes

![VisionHermes](assets/teaserimage.png)

A real-time AI assistant for **Meta Ray-Ban smart glasses** and **iPhone**, adapted from VisionClaw to work with **Hermes Agent**. See what you see, hear what you say, and take actions on your behalf -- all through voice.

![Cover](assets/cover.png)

Built on [Meta Wearables DAT SDK](https://github.com/facebook/meta-wearables-dat-ios) (iOS) / [DAT Android SDK](https://github.com/facebook/meta-wearables-dat-android) (Android) + [Gemini Live API](https://ai.google.dev/gemini-api/docs/live) + [Hermes Agent](https://hermes-agent.nousresearch.com) (tool execution).

**Supported platforms:** iOS (iPhone) and Android (Pixel, Samsung, etc.)

---

## 🌟 NEW: Gemini + Hermes Tool Ecosystem (v2.6)

VisionHermes now features **21+ specialized tools** connecting Gemini's real-time voice+vision intelligence to Hermes Agent's execution power, remote PC management, Obsidian vault, and Telegram:

| Tool | What it does | Gemini contributes | Hermes / Device executes |
|------|-------------|-------------------|--------------------------|
| `enviar_reporte_telegram` | **Telegram Executive Dispatch** | Compiles structured report, takes POV photo | Pushes markdown + high-res POV photo to Telegram |
| `ejecutar_script_remoto` | **Remote PC Terminal & Scripts** | Speaks 1-sentence vocal summary to glasses | Runs shell, Python, Git, Docker, or TouchDesigner on PC & sends logs to Telegram |
| `resumen_walk_and_talk` | **Walk & Talk Brainstorm Wrap-up** | Synthesizes ideas & extracts action items/to-dos | Saves note to Obsidian (`🧠 Ideas`) and pushes summary to Telegram |
| `guardar_referencia_visual` | **Field Scout (TouchDesigner)** | Analyzes composition, suggests TouchDesigner nodes (Feedback, GLSL, Noise) | Saves to Obsidian (`🎯 TouchDesigner`) & sends photo to Telegram |
| `consultar_briefing_diario` | **Daily Audio Briefing** | Delivers 30-45s spoken morning briefing to glasses | Queries Obsidian daily notes, pending tasks, and recent commits |
| `consultar_estado_hermes` | **Hermes Introspection** | Checks active sessions, running subagents, and memory | Returns live status via Cloudflare tunnel |
| `controlar_tarea_hermes` | **Process & Task Control** | Understands stop/cancel/pause voice commands | Halts or pauses background tasks and subagents |
| `delegar_investigacion_profunda` | **Autonomous Deep Research** | Speaks 1-sentence dispatch confirmation | Spawns background subagent on PC, creates prototype, logs report to Telegram & Obsidian |
| `capturar_paleta_y_texturas` | **Field Scout 2.0 (Colors & Textures)** | Extracts 3-5 HEX color codes, lighting & noise | Saves palette to Obsidian (`🎯 TouchDesigner/Paletas/`) and sends swatches to Telegram |
| `inspeccionar_pantalla_o_pizarra` | **Screen & Whiteboard Inspector** | Transcribes traceback, code, or architecture diagram | Converts to Mermaid/fixes, saves to Vault or generates patch |
| `recordar_contacto_o_networking` | **Personal CRM & Networking** | Formulates contact card + follow-up promise | Saves to Obsidian (`🤝 Contactos/`) and schedules Telegram follow-up alert |
| `registrar_gasto_o_habito` | **Voice-First Finance & Habit Tracker** | Confirms logged amount & running daily balance | Adds row to Obsidian Dataview financial tables |
| `repasar_conceptos_vault` | **Walk & Learn (Active Study)** | Quizzes the user conversationally with Socratic questions | Queries Obsidian notes & tracks studied concepts |
| `monitorear_proceso_o_render` | **Render & Process Telemetry** | Reports % progress, ETA, and GPU load to glasses | Monitors TD renders / Docker and sends Telegram alert when finished |
| `control_ambiente_pc` | **PC Shortcuts & System Control** | Speaks 1-sentence execution confirmation | Locks PC screen, suspends workstation, launches `.toe` projects |
| `donde_deje_mi_objeto` | **Temporal Visual Memory** | Estimates time & location from recent scene buffer | Finds candidate keyframe and sends photo to Telegram |
| `gemelo_guardar_respuesta` | **Avatar Personal** | Asks deep personal questions, analyzes emotions & speech traits | Saves structured responses + personality profile to Obsidian |
| `guardar_nota_rapida` | **Voice-to-Vault Notes** | Takes dictation with ambient context | Creates markdown files in Obsidian `📥 Inbox` |
| `buscar_en_vault` | **Semantic Vault Search** | Natural language queries | Searches Obsidian vault and speaks excerpts |
| `guardar_observacion` | **Visual Field Memory** | Vivid visual description + GPS location | Saves timestamped observations with photos to vault |
| `exportar_chat_md` | **Chat Export** | Generates clean markdown transcript | Saves locally and syncs to Obsidian `📜 Historial Chat` |
| `execute` | **General Execution** | General assistant queries | Web search, calendar, smart home, reminders |

This turns Gemini from a simple voice assistant into a **complete remote control interface for your PC, physical environment, and digital brain**.

---

## ⚡ Recent Innovations & Architecture Upgrades

### 1. 📲 Remote PC Control & Telegram Dispatch
- **Dual-Output Policy**: Gemini delivers concise 1-2 sentence spoken answers through the glasses to avoid audio overload while on the go, while dispatching complete logs, diffs, to-dos, and high-res POV photos directly to your private **Telegram** chat.
- **Low-Latency Image Compression**: POV snapshots are automatically resized (800px) and compressed to JPEG (~50-70 KB) via `encodeSnapshotForTransmission` for instant transmission over 4G/5G mobile networks.

### 2. 🎥 POV Demo Recording directly to iOS Photos
- **Dual Audio Mix**: Records synchronized 1080x1440 H.264 video with both microphone audio (your voice) and digital audio (Gemini Live speech output) mixed without drift.
- **Top-Bar REC Button**: Live status indicator with timer (`🔴 00:14`) and automatic save to `Photos.app`.

### 3. 🧠 Scene-Gating & "Fresh Eyes" (<250ms)
- **16x16 Pixel Thumbnail Engine**: Runs continuous mean absolute difference comparison (`FrameChange.swift`).
- When you turn your head to look at a new object or scene, the 1-second video throttle is bypassed immediately, delivering fresh visual context to Gemini in under 250ms.

### 4. 📍 CoreLocation Ambient Geocoding
- Automatic reverse geocoding provides city, neighborhood, and coordinates (`X-Client-Location` header) for visual observations and Telegram reports without draining battery.

### 5. 🛑 Smart Word-Boundary Stop & Low-Latency VAD
- Regex-based word boundary detection (`\bstop\b`, `\bsilencio\b`, `\bpara\b`) silences speech instantly without cutting video streaming.
- Gemini Live VAD configured to `silenceDurationMs: 250` and high sensitivity for natural conversational turns.

---

## 🌐 Remote Access (Cloudflare Tunnel)

VisionHermes connects to Hermes Agent through a **Cloudflare Tunnel** for secure access from anywhere:

```
https://your-hermes-domain.example.com → Hermes Agent (localhost:18789)
```

No open ports, no VPN needed. The tunnel handles SSL termination and routing automatically.

To set up your own tunnel:
1. Install [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
2. Authenticate: `cloudflared tunnel login`
3. Create tunnel: `cloudflared tunnel create <name>`
4. Configure DNS: `cloudflared tunnel route dns <name> your-domain.com`
5. Run: `cloudflared tunnel run <name>`

---

## What It Does

Put on your glasses, tap the AI button, and talk:

- **"What am I looking at?"** -- Gemini sees through your glasses camera and describes the scene
- **"Add milk to my shopping list"** -- delegates to Hermes Agent via `execute`
- **"Send a message to John saying I'll be late"** -- routes through Hermes Agent
- **"Search for the best coffee shops nearby"** -- web search via `execute`, results spoken back
- **NEW: "Let's do today's deep question"** -- starts a Avatar Personal session, Gemini asks profound questions about your life and values, saves to Obsidian
- **NEW: "Save this idea for later"** -- `guardar_nota_rapida` instantly creates a note in your vault
- **NEW: "What do I know about TouchDesigner noise?"** -- `buscar_en_vault` searches your entire Obsidian vault and Gemini reads the answer aloud
- **NEW: "Remember this place"** -- `guardar_observacion` captures what Gemini sees through the camera and saves it as a visual note
- **NEW: "Export this whole conversation"** -- `exportar_chat_md` saves the full transcript as markdown and optionally sends it to your vault

The glasses camera streams at ~1fps to Gemini for visual context, while audio flows bidirectionally in real-time.

---

## 🧬 Avatar Personal Project

One of the flagship features: **building a digital twin of the user's personality**.

Every day, a deep personal question is sent via Telegram (or asked directly by Gemini). The user responds naturally for 15-20 minutes. Gemini detects emotions, speech patterns, values, and recurring themes. The structured analysis is saved to Obsidian via `gemelo_guardar_respuesta`.

**10 categories, 57 questions total:**

| Category | Questions | Focus |
|----------|-----------|-------|
| 🧠 Philosophy of Life | 7 | Purpose, meaning, worldview |
| 📖 Foundational Memories | 6 | Formative moments |
| 🤝 Relationships | 6 | Connection with others |
| 🎨 Creativity & Process | 6 | Artistic drive |
| 😨 Fear & Vulnerability | 6 | What holds you back |
| 🚀 Dreams & Aspirations | 5 | Future self |
| 🆔 Identity | 6 | Who you really are |
| 🤖 Technology & Humanity | 5 | Relationship with tech |
| ⚖️ Ethics & Boundaries | 5 | Moral lines |
| ☠️ Death & Transcendence | 5 | Legacy |

After each session, the profile accumulates: detected traits, fundamental values, linguistic patterns, and emotional tendencies. The goal: a digital twin that talks, feels, and reacts like the user.

---

## 📜 Chat History & Markdown Export

Every conversation with Gemini is automatically saved to local chat history. You can:

- **Browse past sessions** — tap the Chat History button
- **Export as Markdown** — swipe left on any session and tap "Export as MD" to share or save
- **Send to Vault** — swipe left and tap "To Vault" to send the full transcript to your Obsidian vault via Hermes
- **Export from detail view** — tap the share button in the top right of any session to export or send to vault

Exported conversations land in `📜 Historial Chat/` in your Obsidian vault.

---

## How It Works

```
Meta Ray-Ban Glasses (or phone camera)
       |
       | video frames + mic audio
       v
iOS / Android App (VisionHermes)
       |
       | JPEG frames (~1fps) + PCM audio (16kHz)
       v
Gemini Live API (WebSocket)
       |
       |── Audio response (PCM 24kHz) ──> App ──> Glasses Speaker (Concise speech)
       |── Tool calls ──> App ──> Hermes Gateway (your-hermes-domain.example.com)
       |         |                         |
       |         | (POV Photo + GPS)       v
       |         |               ┌──────────────────────────────────────┐
       |         |               │           Tool Dispatcher            │
       |         |               │                                      │
       |         |               │  enviar_reporte_telegram             │
       |         |               │    → 📲 Telegram (Photo + Markdown)  │
       |         |               │                                      │
       |         |               │  ejecutar_script_remoto              │
       |         |               │    → 💻 PC Shell, Python, TD render  │
       |         |               │    → 📲 Full logs to Telegram        │
       |         |               │                                      │
       |         |               │  resumen_walk_and_talk               │
       |         |               │    → 🧠 Obsidian + 📲 Telegram       │
       |         |               │                                      │
       |         |               │  guardar_referencia_visual           │
       |         |               │    → 🎯 TouchDesigner nodes + Photo   │
       |         |               │                                      │
       |         |               │  consultar_estado_hermes / controlar │
       |         |               │    → 🖥️ Sessions, subagents, control │
       |         |               │                                      │
       |         |               │  gemelo_guardar_respuesta            │
       |         |               │    → 🧬 Avatar Personal perfil        │
       |         |               │                                      │
       |         |               │  guardar_nota_rapida / buscar_vault  │
       |         |               │    → 📥 Inbox / 🔍 Vault Search       │
       |         |               │                                      │
       |         |               │  exportar_chat_md / execute          │
       |         |               │    → 📜 Historial Chat / Web actions │
       |         |               └──────────────────────────────────────┘
       |         |                                 |
       |<────────┴── Tool response (text) <── App <┘
       |
       v
  Gemini speaks the result
```

**Key pieces:**
- **Gemini Live** -- real-time voice + vision AI over WebSocket (native audio, not STT-first)
- **Hermes Agent** -- local/cloud gateway that gives Gemini access to your PC terminal, background subagents, Obsidian vault, and Telegram bot
- **12+ specialized tools** -- purpose-built tools for field scouting, remote execution, Telegram delivery, and introspection
- **Dual-Output Architecture** -- concise voice replies in the glasses, comprehensive logs/diffs/photos pushed to Telegram
- **Session Recorder** -- 1080x1440 H.264 video recorder saving directly to Photos with dual audio mix
- **Scene-Gating (<250ms)** -- 16x16 thumbnail comparator bypassing video throttle on head movements
- **CoreLocation Engine** -- automatic GPS context and reverse geocoding in observations and reports
- **Chat History Manager** -- persists all conversations with markdown export + vault sync
- **Phone mode** -- test the full pipeline using your phone camera instead of glasses
- **WebRTC streaming** -- share your glasses POV live to a browser viewer

---

## Quick Start (iOS)

### 1. Clone and open

```bash
git clone https://github.com/tolchx/Vision-Hermes-Agent.git
cd Vision-Hermes-Agent/samples/CameraAccess
open CameraAccess.xcodeproj
```

### 2. Add your secrets

```bash
cp CameraAccess/Secrets.swift.example CameraAccess/Secrets.swift
```

Edit `Secrets.swift` with your [Gemini API key](https://aistudio.google.com/apikey) (required) and your Hermes Agent gateway URL.

**Default values (Cloudflare tunnel):**
- `hermesHost = "https://your-hermes-domain.example.com"`
- `hermesPort = 443`

### 3. Build & Run

Select your iPhone as the target device and hit Run (Cmd+R).

### 4. Build IPA (GitHub Actions)

This repo includes a GitHub Actions workflow that builds an unsigned IPA for sideloading:

1. Push to `main` → build triggers automatically
2. Download the artifact from **Actions → Build iOS App → CameraAccess-Sideloadly**
3. Sideload with [Sideloadly](https://sideloadly.io) or AltStore

### 4. Try it out

**Without glasses (iPhone mode):**
1. Tap **"Start on iPhone"** -- uses your iPhone's back camera
2. Tap the **AI button** to start a Gemini Live session
3. Talk to the AI -- it can see through your iPhone camera

**With Meta Ray-Ban glasses:**

First, enable Developer Mode in the Meta AI app:

1. Open the **Meta AI** app on your iPhone
2. Go to **Settings** (gear icon, bottom left)
3. Tap **App Info**
4. Tap the **App version** number **5 times** -- this unlocks Developer Mode
5. Go back to Settings -- you'll now see a **Developer Mode** toggle. Turn it on.

![How to enable Developer Mode](assets/dev_mode.png)

Then in VisionHermes:
1. Tap **"Start Streaming"** in the app
2. Tap the **AI button** for voice + vision conversation

---

## Quick Start (Android)

### 1. Clone and open

```bash
git clone https://github.com/tolchx/Vision-Hermes-Agent.git
```

Open `samples/CameraAccessAndroid/` in Android Studio.

### 2. Configure GitHub Packages (DAT SDK)

The Meta DAT Android SDK is distributed via GitHub Packages. You need a GitHub Personal Access Token with `read:packages` scope.

1. Go to [GitHub > Settings > Developer Settings > Personal Access Tokens](https://github.com/settings/tokens) and create a token with `read:packages` scope
2. In `samples/CameraAccessAndroid/local.properties`, add:

```properties
gpr.user=YOUR_GITHUB_USERNAME
gpr.token=YOUR_GITHUB_TOKEN
```

> **Tip:** If you have the `gh` CLI installed, you can run `gh auth token` to get a valid token. Make sure it has `read:packages` scope -- if not, run `gh auth refresh -s read:packages`.

### 3. Add your secrets

```bash
cd samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/
cp Secrets.kt.example Secrets.kt
```

Edit `Secrets.kt` with your [Gemini API key](https://aistudio.google.com/apikey) (required) and optional Hermes Agent/WebRTC config.

### 4. Build and run

1. Let Gradle sync in Android Studio (it will download the DAT SDK from GitHub Packages)
2. Select your Android phone as the target device
3. Click Run (Shift+F10)

> **Wireless debugging:** You can also install via ADB wirelessly. Enable **Wireless debugging** in your phone's Developer Options, then pair with `adb pair <ip>:<port>`.

### 5. Try it out

**Without glasses (Phone mode):**
1. Tap **"Start on Phone"** -- uses your phone's back camera
2. Tap the **AI button** (sparkle icon) to start a Gemini Live session
3. Talk to the AI -- it can see through your phone camera

**With Meta Ray-Ban glasses:**

Enable Developer Mode in the Meta AI app (same steps as iOS above), then:
1. Tap **"Start Streaming"** in the app
2. Tap the **AI button** for voice + vision conversation

---

## Setup: Hermes Agent (Optional)

Hermes Agent gives Gemini the ability to take real-world actions and access your Obsidian vault. Without it, Gemini is voice + vision only.

### 1. Install and configure Hermes Agent

Follow the [Hermes Agent setup guide](https://github.com/nichochar/openclaw). Make sure the gateway is enabled:

In `~/.hermes/config.yaml`:

```yaml
gateway:
  port: 18789
  bind: "lan"
  auth:
    mode: token
    token: "your-gateway-token-here"
  http:
    endpoints:
      chatCompletions: { enabled: true }
```

Key settings:
- `bind: "lan"` -- exposes the gateway on your local network so your phone can reach it
- `chatCompletions.enabled: true` -- enables the `/v1/chat/completions` endpoint (off by default)
- `auth.token` -- the token your app will use to authenticate

### 2. Configure the app

**iOS** -- In `Secrets.swift`:
```swift
static let hermesHost = "https://your-hermes-domain.example.com"
static let hermesPort = 443
static let hermesGatewayToken = "your-gateway-token-here"
```

**Android** -- In `Secrets.kt`:
```kotlin
const val hermesHost = "https://your-hermes-domain.example.com"
const val hermesPort = 443
const val hermesGatewayToken = "your-gateway-token-here"
```

> Both iOS and Android also have an in-app Settings screen where you can change these values at runtime without editing source code.

### 3. Start the gateway

```bash
hermes gateway restart
```

Verify it's running:

```bash
curl http://localhost:18789/health
```

Now when you talk to the AI, it can execute tasks through Hermes Agent.

---

## Architecture

### Key Files (iOS)

All source code is in `samples/CameraAccess/CameraAccess/`:

| File | Purpose |
|------|---------|
| `Gemini/GeminiConfig.swift` | API keys, model config, system prompt (includes Avatar Personal + tool instructions) |
| `Gemini/GeminiLiveService.swift` | WebSocket client for Gemini Live API |
| `Gemini/AudioManager.swift` | Mic capture (PCM 16kHz) + audio playback (PCM 24kHz) |
| `Gemini/ChatModels.swift` | ChatSession, ChatMessage, Role data models |
| `Gemini/ChatHistoryManager.swift` | Persists chat sessions, exports to Markdown, vault sync |
| `Gemini/GeminiSessionViewModel.swift` | Session lifecycle, tool call wiring, transcript state, history manager integration |
| `Hermes/ToolCallModels.swift` | **6 tool declarations** (execute, gemelo_guardar_respuesta, guardar_nota_rapida, buscar_en_vault, guardar_observacion, exportar_chat_md) |
| `Hermes/HermesBridge.swift` | HTTP client for Hermes Agent gateway (chat completions endpoint) |
| `Hermes/ToolCallRouter.swift` | Routes Gemini tool calls to correct handler, export sharing |
| `Views/ChatHistoryView.swift` | Chat history UI with MD export + vault sync for each session |
| `iPhone/IPhoneCameraManager.swift` | AVCaptureSession wrapper for iPhone camera mode |
| `WebRTC/WebRTCClient.swift` | WebRTC peer connection + SDP negotiation |
| `WebRTC/SignalingClient.swift` | WebSocket signaling for WebRTC rooms |

### Key Files (Android)

*Note: Android tool declarations need to be updated to match iOS v2.0 tools*

All source code is in `samples/CameraAccessAndroid/app/src/main/java/.../cameraaccess/`:

| File | Purpose |
|------|---------|
| `gemini/GeminiConfig.kt` | API keys, model config, system prompt |
| `gemini/GeminiLiveService.kt` | OkHttp WebSocket client for Gemini Live API |
| `gemini/AudioManager.kt` | AudioRecord (16kHz) + AudioTrack (24kHz) |
| `gemini/GeminiSessionViewModel.kt` | Session lifecycle, tool call wiring, UI state |
| `openclaw/ToolCallModels.kt` | Tool declarations, data classes |
| `openclaw/HermesBridge.kt` | OkHttp HTTP client for Hermes Agent gateway |
| `openclaw/ToolCallRouter.kt` | Routes Gemini tool calls to Hermes Agent |
| `phone/PhoneCameraManager.kt` | CameraX wrapper for phone camera mode |
| `webrtc/WebRTCClient.kt` | WebRTC peer connection (stream-webrtc-android) |
| `webrtc/SignalingClient.kt` | OkHttp WebSocket signaling for WebRTC rooms |
| `settings/SettingsManager.kt` | SharedPreferences with Secrets.kt fallback |

### Audio Pipeline

- **Input**: Phone mic -> AudioManager (PCM Int16, 16kHz mono, 100ms chunks) -> Gemini WebSocket
- **Output**: Gemini WebSocket -> AudioManager playback queue -> Phone speaker
- **iOS iPhone mode**: Uses `.voiceChat` audio session for echo cancellation + mic gating during AI speech
- **iOS Glasses mode**: Uses `.videoChat` audio session (mic is on glasses, speaker is on phone -- no echo)
- **Android**: Uses `VOICE_COMMUNICATION` audio source for built-in acoustic echo cancellation

### Video Pipeline

- **Glasses**: DAT SDK video stream (24fps) -> throttle to ~1fps -> JPEG (50% quality) -> Gemini
- **Phone**: Camera capture (30fps) -> throttle to ~1fps -> JPEG -> Gemini

### Tool Calling

VisionHermes now supports **6 specialized tool declarations** (previously just 1). Each tool has its own data schema and routing logic:

1. **`execute(task)`** — General-purpose. Web search, messages, reminders, smart home, etc. Be detailed in the task description.

2. **`gemelo_guardar_respuesta(categoria, pregunta, respuesta, analisis_emocion?, frases_clave?, nuevo_rasgo?)`** — Saves Avatar Personal responses. Captures category, question, answer, emotional analysis, key quotes, and new personality traits.

3. **`guardar_nota_rapida(titulo, contenido, carpeta?)`** — Voice-to-vault. Creates markdown notes in the specified folder (default: 📥 Inbox).

4. **`buscar_en_vault(consulta, limite?)`** — Semantic search of your Obsidian vault. Gemini interprets the natural language query, Hermes searches the vault and returns relevant excerpts.

5. **`guardar_observacion(titulo, descripcion, contexto?, tags?)`** — Visual memory. Gemini describes what it sees through the camera, saves as a timestamped observation in the vault.

6. **`exportar_chat_md(titulo, guardar_en_vault?)`** — Conversation export. Generates a full markdown transcript locally (shares via activity sheet) and optionally sends to Obsidian.

**Flow:**
1. User speaks a request
2. Gemini acknowledges verbally (e.g. "Saving that idea now")
3. Gemini sends `toolCall` with the appropriate function name and parameters
4. `ToolCallRouter` parses the function name and routes to the correct handler
5. Handler builds a structured task string (with `[PREFIX]`) and sends to Hermes gateway
6. Hermes recognizes the prefix and executes the correct action (file write, search, export)
7. Result returns to Gemini via `toolResponse`
8. Gemini speaks the confirmation

---

## Requirements

### iOS
- iOS 17.0+
- Xcode 15.0+
- Gemini API key ([get one free](https://aistudio.google.com/apikey))
- Meta Ray-Ban glasses (optional -- use iPhone mode for testing)
- Hermes Agent running locally or via Cloudflare Tunnel (optional -- for agentic actions)

### Android
- Android 14+ (API 34+)
- Android Studio Ladybug or newer
- GitHub account with `read:packages` token (for DAT SDK)
- Gemini API key ([get one free](https://aistudio.google.com/apikey))
- Meta Ray-Ban glasses (optional -- use Phone mode for testing)
- Hermes Agent running locally or via Cloudflare Tunnel (optional -- for agentic actions)

---

## Troubleshooting

### General

**Gemini doesn't hear me** -- Check that microphone permission is granted. The app uses aggressive voice activity detection -- speak clearly and at normal volume.

**Hermes connection timeout** -- Make sure your iPhone can reach the gateway. Test by opening `https://your-hermes-domain.example.com/v1/models` in Safari — should return JSON. If it works in Safari but not the app, check Settings → Debug → App Log for the exact error.

**Duplicate browser tabs** — This is a known upstream issue in Hermes Agent's CDP connection management.

### iOS-specific

**"Gemini API key not configured"** -- Add your API key in Secrets.swift or in the in-app Settings.

**Echo/feedback in iPhone mode** -- The app mutes the mic while the AI is speaking. If you still hear echo, try turning down the volume.

### Android-specific

**Gradle sync fails with 401 Unauthorized** -- Your GitHub token is missing or doesn't have `read:packages` scope. Check `local.properties` for `gpr.user` and `gpr.token`. Generate a new token at [github.com/settings/tokens](https://github.com/settings/tokens).

**Gemini WebSocket times out** -- The Gemini Live API sends binary WebSocket frames. If you're building a custom client, make sure to handle both text and binary frame types.

**Audio not working** -- Ensure `RECORD_AUDIO` permission is granted. On Android 13+, you may need to grant this permission manually in Settings > Apps.

**Phone camera not starting** -- Ensure `CAMERA` permission is granted. CameraX requires both the permission and a valid lifecycle.

For DAT SDK issues, see the [developer documentation](https://wearables.developer.meta.com/docs/develop/) or the [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions).

---

## 🐛 Debug Features

### App Log
Settings → **Debug → App Log** shows real-time logs from the app: connection attempts, errors, URL construction, and tool call results.

### Test Connection
Settings → **AI Backend → Hermes Settings → Test Connection** lets you manually test the Hermes gateway and see the exact error.

---

## 🔇 Background Audio (Lock Screen)

VisionHermes supports **background audio playback**, so you can keep talking to the AI even with the screen locked — perfect for using with Bluetooth headphones while the phone is in your pocket.

**How it works:**
- The app registers as an audio app with the system (like Music or Podcasts)
- Audio continues streaming through Gemini Live even when the screen is off
- Bluetooth headphones (HFP/A2DP) work seamlessly
- The app shows in the **Now Playing** control center and lock screen

**Requirements:**
- iOS 17.0+
- Bluetooth headphones (AirPods, etc.) recommended for best experience
- Active Gemini Live session

**No configuration needed** — it works automatically after installing the latest IPA.

---

## 📦 Pre-built IPA (iOS)

The latest unsigned IPA is built via GitHub Actions on every push to `main`.

1. Go to **Actions → Build iOS App**
2. Download **CameraAccess-Sideloadly** artifact
3. Install with [Sideloadly](https://sideloadly.io) or AltStore

## 📦 Pre-built APK (Android)

The debug APK is built via GitHub Actions on every push to `main`.

1. Go to **Actions → Build Android APK**
2. Download **CameraAccess-Android-Debug** artifact
3. Install directly or via `adb install`

---

## License

This source code is licensed under the license found in the [LICENSE](LICENSE) file in the root directory of this source tree.

