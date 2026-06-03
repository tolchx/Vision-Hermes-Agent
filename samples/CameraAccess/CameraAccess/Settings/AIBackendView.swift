import SwiftUI

struct AIBackendView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // Bindings passed from SettingsView to edit the configuration directly
    @Binding var hermesHost: String
    @Binding var hermesPort: String
    @Binding var hermesGatewayToken: String
    @Binding var webrtcSignalingURL: String
    @Binding var geminiAPIKey: String
    
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
                    Text("AI Backend")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Section: Choose Your AI
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CHOOSE YOUR AI")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                BackendSelectionRow(title: "Hermes", 
                                                   description: "Wake word activation, 56+ tools, task execution", 
                                                   icon: "terminal", 
                                                   isSelected: settings.activeAIBackend == "Hermes") {
                                    settings.activeAIBackend = "Hermes"
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                BackendSelectionRow(title: "Gemini Live", 
                                                   description: "Real-time voice + vision, continuous conversation", 
                                                   icon: "waveform", 
                                                   isSelected: settings.activeAIBackend == "Gemini Live") {
                                    settings.activeAIBackend = "Gemini Live"
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                            
                            Text("Hermes offers more tools and privacy. Gemini Live has lower latency.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                        }
                        
                        // Section: Configuration status
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONFIGURATION")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                NavigationLink(destination: HermesConnectionSettingsView(hermesHost: $hermesHost, hermesPort: $hermesPort, hermesGatewayToken: $hermesGatewayToken, webrtcSignalingURL: $webrtcSignalingURL)) {
                                    ConfigStatusRow(title: "Hermes Settings", 
                                                   isConfigured: GeminiConfig.isHermesConfigured)
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NavigationLink(destination: GeminiConnectionSettingsView(geminiAPIKey: $geminiAPIKey)) {
                                    ConfigStatusRow(title: "Gemini Settings", 
                                                   isConfigured: GeminiConfig.isConfigured)
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

struct BackendSelectionRow: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.6))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
}

struct ConfigStatusRow: View {
    let title: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(isConfigured ? "Configured" : "Not configured")
                    .font(.caption)
                    .foregroundColor(isConfigured ? .green : .orange)
                Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(isConfigured ? .green : .orange)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding()
    }
}
