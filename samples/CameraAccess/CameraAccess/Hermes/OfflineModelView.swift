import SwiftUI

// MARK: - Model Catalog

struct OfflineModel: Identifiable {
    let id: String
    let name: String
    let family: String
    let params: String
    let quant: String
    let sizeMB: Int
    let ramRequired: Int  // MB
    let description: String
    let downloadURL: String
    let recommended: Bool
    let minDevice: String  // "iPhone 14 Pro", "iPhone 15 Pro", etc.

    var sizeLabel: String {
        if sizeMB > 1000 { return "\(sizeMB / 1000).\(sizeMB % 1000 / 100) GB" }
        return "\(sizeMB) MB"
    }

    var ramLabel: String {
        if ramRequired > 1000 { return "\(ramRequired / 1000) GB" }
        return "\(ramRequired) MB"
    }

    static let catalog: [OfflineModel] = [
        OfflineModel(
            id: "gemma-4-2b-it-Q4",
            name: "Gemma 4 2B",
            family: "Gemma",
            params: "2B",
            quant: "Q4_K_M",
            sizeMB: 1300,
            ramRequired: 2048,
            description: "Google's latest small model. Great for iPhone. Fast responses, good quality.",
            downloadURL: "https://huggingface.co/bartowski/gemma-4-2b-it-GGUF/resolve/main/gemma-4-2b-it-Q4_K_M.gguf",
            recommended: true,
            minDevice: "iPhone 14 Pro"
        ),
        OfflineModel(
            id: "gemma-4-2b-it-Q8",
            name: "Gemma 4 2B Q8",
            family: "Gemma",
            params: "2B",
            quant: "Q8_0",
            sizeMB: 2600,
            ramRequired: 3072,
            description: "Higher quality version of Gemma 4 2B. Better accuracy, more RAM needed.",
            downloadURL: "https://huggingface.co/bartowski/gemma-4-2b-it-GGUF/resolve/main/gemma-4-2b-it-Q8_0.gguf",
            recommended: false,
            minDevice: "iPhone 15 Pro"
        ),
        OfflineModel(
            id: "llama-3.2-3b-Q4",
            name: "Llama 3.2 3B",
            family: "Llama",
            params: "3B",
            quant: "Q4_K_M",
            sizeMB: 1900,
            ramRequired: 3072,
            description: "Meta's efficient 3B model. Solid general purpose, good for conversation.",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            recommended: true,
            minDevice: "iPhone 15 Pro"
        ),
        OfflineModel(
            id: "llama-3.2-1b-Q4",
            name: "Llama 3.2 1B",
            family: "Llama",
            params: "1B",
            quant: "Q4_K_M",
            sizeMB: 700,
            ramRequired: 1024,
            description: "Ultra-lightweight. Fastest option. Good for simple tasks & low RAM devices.",
            downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            recommended: false,
            minDevice: "iPhone 12"
        ),
        OfflineModel(
            id: "phi-3-mini-Q4",
            name: "Phi-3 Mini 3.8B",
            family: "Phi",
            params: "3.8B",
            quant: "Q4_K_M",
            sizeMB: 2400,
            ramRequired: 4096,
            description: "Microsoft's compact powerhouse. Excellent reasoning for its size.",
            downloadURL: "https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf",
            recommended: false,
            minDevice: "iPhone 15 Pro"
        ),
        OfflineModel(
            id: "qwen-2.5-3b-Q4",
            name: "Qwen 2.5 3B",
            family: "Qwen",
            params: "3B",
            quant: "Q4_K_M",
            sizeMB: 1800,
            ramRequired: 3072,
            description: "Alibaba's strong 3B model. Great multilingual support including Spanish.",
            downloadURL: "https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf",
            recommended: false,
            minDevice: "iPhone 15 Pro"
        ),
    ]

    static func compatibleWithCurrentDevice() -> [OfflineModel] {
        // iPhone 15 Pro has 8GB RAM, we'll be conservative
        catalog.filter { $0.ramRequired <= 4096 }
    }
}

// MARK: - Offline Model View

struct OfflineModelView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var downloadProgress: Double = 0
    @State private var isDownloading = false
    @State private var errorMessage: String? = nil
    @State private var selectedModelID: String? = nil
    @State private var downloadedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var downloadTask: URLSessionDownloadTask? = nil
    @State private var showDeleteConfirm = false

    private let models = OfflineModel.compatibleWithCurrentDevice()

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("Offline AI Model")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        infoSection
                        modelCatalogSection
                        activeModelSection
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Delete Model", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteModel() }
        } message: {
            Text("Remove the downloaded model from your device?")
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline AI allows you to run a small language model directly on your iPhone — no internet needed. Perfect for subway, elevators, or remote areas.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("Models run via llama.cpp. Requires iPhone 14 Pro or newer for best performance.")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Model Catalog

    private var modelCatalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVAILABLE MODELS")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .padding(.leading, 8)

            ForEach(models) { model in
                ModelCard(
                    model: model,
                    isSelected: selectedModelID == model.id,
                    isDownloading: isDownloading && selectedModelID == model.id,
                    progress: downloadProgress,
                    onSelect: { selectModel(model) }
                )
            }
        }
    }

    // MARK: - Active Model

    private var activeModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE LOCAL MODEL")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .padding(.leading, 8)

            HStack {
                if settings.isOfflineModelInstalled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Installed")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        Text(settings.offlineModelURL.components(separatedBy: "/").last ?? "Unknown model")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button(action: { showDeleteConfirm = true }) {
                        Text("Delete")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                } else {
                    Image(systemName: "tray")
                        .foregroundColor(.gray)
                    Text("No model downloaded. Select one above.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func selectModel(_ model: OfflineModel) {
        selectedModelID = model.id
        settings.offlineModelURL = model.downloadURL

        if settings.isOfflineModelInstalled {
            showDeleteConfirm = true
            return
        }

        startDownload(url: model.downloadURL, modelName: model.name)
    }

    private func startDownload(url: String, modelName: String) {
        guard let downloadURL = URL(string: url) else {
            errorMessage = "Invalid URL"
            return
        }

        isDownloading = true
        errorMessage = nil
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0

        let session = URLSession(configuration: .default, delegate: DownloadDelegate(), delegateQueue: nil)
        downloadTask = session.downloadTask(with: downloadURL)
        downloadTask?.resume()
    }

    private func deleteModel() {
        settings.isOfflineModelInstalled = false
        settings.offlineModelURL = ""
        selectedModelID = nil

        // Delete downloaded file
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let existing = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for file in existing where file.lastPathComponent.hasSuffix(".gguf") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

// MARK: - Model Card

struct ModelCard: View {
    let model: OfflineModel
    let isSelected: Bool
    let isDownloading: Bool
    let progress: Double
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                            .frame(width: 36, height: 36)
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: isSelected ? "checkmark" : "brain.head.profile")
                                .font(.system(size: 14))
                                .foregroundColor(isSelected ? .white : .gray)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            if model.recommended {
                                Text("BEST")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        Text(model.description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isDownloading {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }

                // Model specs
                HStack(spacing: 12) {
                    specBadge(icon: "tray.full", text: model.sizeLabel)
                    specBadge(icon: "memorychip", text: model.ramLabel)
                    specBadge(icon: "cpu", text: model.params)
                    specBadge(icon: "doc.text", text: model.quant)
                }

                // Download progress bar
                if isDownloading {
                    ProgressView(value: progress)
                        .tint(.blue)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white.opacity(0.03))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .disabled(isDownloading)
    }

    private func specBadge(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(.gray)
            Text(text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Download Delegate

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            // Update progress via notification or shared state
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let destination = documents.appendingPathComponent("model.gguf")
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.moveItem(at: location, to: destination)
            SettingsManager.shared.isOfflineModelInstalled = true
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                SettingsManager.shared.isOfflineModelInstalled = false
            }
        }
    }
}
