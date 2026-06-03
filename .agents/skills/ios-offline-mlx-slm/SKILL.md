---
description: How to run a Small Language Model (SLM) locally on an iOS device using Apple MLX or Llama.cpp to provide offline AI assistance.
---
# iOS Offline SLM Execution

When building AI voice assistants, network requests to cloud LLMs (like OpenAI or Gemini) will inevitably fail in elevators, subways, or remote areas. To make smart glasses truly reliable, the app must gracefully fallback to a local Small Language Model (SLM) running directly on the iPhone's Neural Engine / GPU.

## 1. Choosing an Engine

There are two primary ways to run LLMs effectively on iOS today:
1. **[MLX-Swift](https://github.com/ml-explore/mlx-swift)**: Apple's official machine learning array framework. Highly optimized for Apple Silicon (A-series and M-series chips). Preferred for modern devices.
2. **[llama.cpp](https://github.com/ggerganov/llama.cpp) (via Swift wrappers)**: The industry standard for running heavily quantized GGUF models. Excellent compatibility and RAM efficiency.

## 2. Model Selection & Constraints

**Memory is your enemy on iOS.** An iPhone 15 Pro has 8GB of RAM, but iOS will terminate any single app that uses more than ~50-60% of it. 
*   You cannot run a 7B or 8B model comfortably alongside other apps.
*   **Target Models:** Look for 1B to 3B parameter models.
    *   `Llama-3.2-1B-Instruct`
    *   `Gemma-2-2B-It`
    *   `Qwen2.5-1.5B`
*   **Quantization:** You *must* use 4-bit quantization (e.g., `Q4_K_M` in GGUF or 4-bit MLX formats) to keep the model size between 1GB - 2GB.

## 3. Architecture: The Network Fallback Pattern

Instead of forcing the user to toggle "Offline Mode", the app should detect network drops automatically. 

```swift
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    @Published var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
}
```

In your main `VoiceAgentService` routing logic:

```swift
func submitUserCommand(_ text: String) async {
    if NetworkMonitor.shared.isConnected {
        // Fast cloud path
        do {
            try await CloudAIService.shared.generate(text)
        } catch {
            print("Cloud failed, falling back to local...")
            await fallbackToLocalLLM(text)
        }
    } else {
        // Direct local path (Elevator mode)
        await fallbackToLocalLLM(text)
    }
}

private func fallbackToLocalLLM(_ text: String) async {
    let response = await LocalSLMService.shared.generate(prompt: text)
    // Route response to local Text-To-Speech engine
    TTSService.shared.speak(response)
}
```

## 4. Local SLM Service (Pseudo-code)

Loading a 2GB model takes 1-3 seconds. Do not load the model when the app boots unless you are already offline. Lazy load it into RAM only when the fallback triggers, and unload it when WiFi returns to save battery.

```swift
class LocalSLMService {
    static let shared = LocalSLMService()
    private var isModelLoaded = false
    
    // Assuming you have an MLX or LlamaContext wrapper
    private var engine: InferenceEngine? 
    
    func generate(prompt: String) async -> String {
        if !isModelLoaded {
            await loadModelIntoRAM()
        }
        
        let systemPrompt = "You are an offline assistant running locally on a phone. Keep answers under 2 sentences."
        let fullPrompt = "<|system|>\n\(systemPrompt)\n<|user|>\n\(prompt)\n<|assistant|>\n"
        
        return await engine?.generate(fullPrompt) ?? "Error generating response locally."
    }
    
    private func loadModelIntoRAM() async {
        // Find the .gguf file bundled in the iOS App bundle
        guard let modelURL = Bundle.main.url(forResource: "Llama-3.2-1B-Instruct-Q4", withExtension: "gguf") else {
            return
        }
        self.engine = InferenceEngine(modelPath: modelURL)
        self.isModelLoaded = true
    }
    
    func unloadToFreeMemory() {
        self.engine = nil
        self.isModelLoaded = false
    }
}
```
