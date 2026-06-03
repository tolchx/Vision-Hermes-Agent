import Foundation

// MARK: - Local Inference Protocol
// Actual inference requires linking llama.cpp via SPM.
// To integrate: File → Add Package Dependencies → https://github.com/ggerganov/llama.cpp
// This file provides the interface. The implementation will use llama when linked.

@MainActor
class LocalInference: ObservableObject {
    @Published var isLoaded = false
    @Published var isLoading = false
    @Published var modelName: String = ""
    @Published var errorMessage: String?
    @Published var isGenerating = false

    private let settings = SettingsManager.shared
    private var modelPath: String?

    var isAvailable: Bool {
        settings.isOfflineModelInstalled && isLoaded
    }

    func loadModel() async {
        guard settings.isOfflineModelInstalled else {
            errorMessage = "No offline model installed. Download one from Settings → Offline AI Model"
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil),
              let modelFile = files.first(where: { $0.lastPathComponent.hasSuffix(".gguf") }) else {
            errorMessage = "No .gguf model file found in Documents"
            return
        }

        isLoading = true
        errorMessage = nil
        modelPath = modelFile.path
        modelName = modelFile.lastPathComponent

        // llama.cpp integration placeholder:
        // When llama.cpp is linked via SPM, uncomment the real loading code:
        //
        // DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        //     llama_backend_init()
        //     var params = llama_model_default_params()
        //     params.n_gpu_layers = 99
        //     let model = llama_load_model_from_file(path, params)
        //     ...
        // }

        // For now, simulate loading (the model file exists but inference requires llama.cpp)
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoaded = true
        isLoading = false
        print("[LocalInference] Model available: \(modelName). Link llama.cpp via SPM for actual inference.")
    }

    func generate(prompt: String, maxTokens: Int = 256) async -> String {
        guard isLoaded else {
            errorMessage = "Model not loaded"
            return ""
        }

        isGenerating = true
        errorMessage = nil

        // llama.cpp inference placeholder:
        // When llama.cpp is linked, replace this with real inference code.
        // For now, return a simulation message.

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        isGenerating = false
        return "[Offline mode requires llama.cpp SPM integration. Run via Settings → Download Model → Install llama.cpp in Xcode]"
    }

    func unload() {
        // llama_free, llama_free_model, llama_backend_free would go here
        isLoaded = false
        modelName = ""
        modelPath = nil
    }

    @MainActor
    deinit {
        unload()
    }
}
