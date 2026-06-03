import SwiftUI

struct VoiceControlView: View {
    @ObservedObject private var settings = SettingsManager.shared
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
                    Text("Voice Control")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        // Wake Word Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("WAKE WORD")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                ToggleRow(title: "Enable Wake Word", 
                                          subtitle: "Only listen after wake phrase", 
                                          isOn: $settings.enableWakeWord)
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    Text("Wake Phrase")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                    Spacer()
                                    TextField("Phrase", text: $settings.wakePhrase)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.white)
                                }
                                .padding()
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                            
                            Text("Say \"\(settings.wakePhrase)\" to activate the assistant. This protects your privacy.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                        }
                        
                        // Conversation Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONVERSATION")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                HStack {
                                    Text("Auto-End Timeout")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("", selection: $settings.autoEndTimeout) {
                                        Text("10 seconds").tag(10.0)
                                        Text("30 seconds").tag(30.0)
                                        Text("1 minute").tag(60.0)
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(.gray)
                                }
                                .padding()
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                        
                        // Output Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OUTPUT VOICE")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                NavigationLink(destination: Text("Voice Selection Detail")) {
                                    HStack {
                                        Text("TTS Voice")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(settings.ttsVoice)
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                ToggleRow(title: "Activation Sound", 
                                          subtitle: "Play chime on wake word", 
                                          isOn: $settings.activationSound)
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
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.green)
        }
        .padding()
    }
}
