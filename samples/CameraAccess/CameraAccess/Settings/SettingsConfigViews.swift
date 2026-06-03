import SwiftUI

struct SettingsField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(keyboardType)
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

struct HermesConnectionSettingsView: View {
    @Binding var hermesHost: String
    @Binding var hermesPort: String
    @Binding var hermesGatewayToken: String
    @Binding var webrtcSignalingURL: String
    @Environment(\.dismiss) private var dismiss

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
                    Text("Hermes Config Detail")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        SettingsManager.shared.hermesHost = hermesHost.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let port = Int(hermesPort.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            SettingsManager.shared.hermesPort = port
                        }
                        SettingsManager.shared.hermesGatewayToken = hermesGatewayToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        SettingsManager.shared.webrtcSignalingURL = webrtcSignalingURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        SettingsField(title: "Hermes Host", placeholder: "http://your-mac.local", text: $hermesHost)
                        SettingsField(title: "Hermes Port", placeholder: "18789", text: $hermesPort, keyboardType: .numberPad)
                        SettingsField(title: "Gateway Token", placeholder: "Optional", text: $hermesGatewayToken, isSecure: true)
                        SettingsField(title: "WebRTC Signaling URL", placeholder: "wss://...", text: $webrtcSignalingURL)

                        // Test Connection Button
                        Button(action: {
                            Task {
                                await testConnection()
                            }
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(testResult.isEmpty ? "Test Connection" : testResult)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(testResult.contains("✅") ? .green : testResult.contains("❌") ? .red : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(testResult.contains("✅") ? Color.green.opacity(0.15) : testResult.contains("❌") ? Color.red.opacity(0.15) : Color.blue.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadDefaults()
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    @State private var testResult: String = ""

    private func loadDefaults() {
        if hermesHost.isEmpty { hermesHost = Secrets.hermesHost }
        if hermesPort.isEmpty { hermesPort = String(Secrets.hermesPort) }
        if hermesGatewayToken.isEmpty { hermesGatewayToken = Secrets.hermesGatewayToken }
        if webrtcSignalingURL.isEmpty { webrtcSignalingURL = Secrets.webrtcSignalingURL }
    }

    private func testConnection() async {
        testResult = "Testing..."
        let baseHost = hermesHost.hasPrefix("http") ? hermesHost : "https://\(hermesHost)"
        let portStr = hermesPort.trimmingCharacters(in: .whitespaces)
        let urlStr = portStr.isEmpty || portStr == "443" ? "\(baseHost)/v1/models" : "\(baseHost):\(portStr)/v1/models"
        guard let url = URL(string: urlStr) else {
            testResult = "❌ Invalid URL: \(urlStr)"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    if let str = String(data: data, encoding: .utf8) {
                        testResult = "✅ Connected! (HTTP \(http.statusCode))"
                    }
                } else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    testResult = "❌ HTTP \(http.statusCode): \(body.prefix(80))"
                }
            }
        } catch {
            testResult = "❌ \(error.localizedDescription)"
        }
    }
}

struct GeminiConnectionSettingsView: View {
    @Binding var geminiAPIKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var savedKey: String = ""

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("Gemini Config Detail")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        SettingsManager.shared.geminiAPIKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        savedKey = geminiAPIKey
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        SettingsField(title: "Gemini API Key", placeholder: "YOUR_GEMINI_API_KEY", text: $geminiAPIKey, isSecure: true)

                        // Informational Text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your API key is stored securely on your device.")
                                .font(.caption2)
                                .foregroundColor(.gray)

                            Link("Get an API key from Google AI Studio ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                                .font(.caption2.bold())
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            savedKey = geminiAPIKey
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

struct GlassesConnectionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
         ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("Glasses Connection")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                Spacer()
                Text("Not Connected")
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

struct MemoriesSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newMemory: String = ""

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("Memories")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    Section(header: Text("ADD NEW MEMORY").foregroundColor(.gray)) {
                        HStack {
                            TextField("Something to remember...", text: $newMemory)
                                .foregroundColor(.white)
                            Button(action: addMemory) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .disabled(newMemory.isEmpty)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    Section(header: Text("STORED MEMORIES").foregroundColor(.gray)) {
                        if settings.memories.isEmpty {
                            Text("No memories stored yet.")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(settings.memories, id: \.self) { memory in
                                Text(memory)
                                    .foregroundColor(.white)
                            }
                            .onDelete(perform: deleteMemory)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func addMemory() {
        let trimmed = newMemory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            settings.memories.append(trimmed)
            newMemory = ""
        }
    }

    private func deleteMemory(at offsets: IndexSet) {
        settings.memories.remove(atOffsets: offsets)
    }
}
