import SwiftUI
import AVFoundation
import UIKit

struct SettingsView: View {
    @State private var authorizationStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus? = nil
    @State private var personalVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoiceId: String? = TTSService.shared.preferredVoiceIdentifier
    @State private var showingHowToCreate: Bool = false
    
    var body: some View {
        List {
            Section("Personal Voice") {
                HStack {
                    Text("Authorization")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }
                Button("Request Access to Personal Voice") { requestAuthorization() }
                Button("How to Create Personal Voice…") { showingHowToCreate = true }
                
                if !personalVoices.isEmpty {
                    Picker("Narration Voice", selection: Binding(get: {
                        selectedVoiceId ?? ""
                    }, set: { newValue in
                        selectedVoiceId = newValue.isEmpty ? nil : newValue
                        TTSService.shared.preferredVoiceIdentifier = selectedVoiceId
                    })) {
                        Text("System Default").tag("")
                        ForEach(personalVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                } else {
                    Text("No Personal Voices available. After authorization, create one in Settings > Accessibility > Personal Voice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Section("Playback Defaults") {
                if let voice = personalVoices.first(where: { $0.identifier == selectedVoiceId }) {
                    Label("Using: \(voice.name)", systemImage: "waveform")
                } else {
                    Label("Using: System default voice", systemImage: "waveform")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            refreshPersonalVoices()
        }
        .alert("Create a Personal Voice", isPresented: $showingHowToCreate) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Go to Settings > Accessibility > Personal Voice, tap Create a Personal Voice, and enable 'Allow Apps to Request to Use'.")
        }
    }
    
    private var statusText: String {
        switch authorizationStatus {
        case .none: return "Unknown"
        case .some(.authorized): return "Authorized"
        case .some(.denied): return "Denied"
        case .some(.unsupported): return "Unsupported"
        @unknown default: return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch authorizationStatus {
        case .some(.authorized): return .green
        case .some(.denied): return .red
        case .some(.unsupported): return .gray
        default: return .secondary
        }
    }
    
    private func requestAuthorization() {
        TTSService.requestPersonalVoiceAuthorization { status in
            DispatchQueue.main.async {
                authorizationStatus = status
                refreshPersonalVoices()
            }
        }
    }
    
    private func refreshPersonalVoices() {
        personalVoices = TTSService.personalVoices()
        authorizationStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    }
}

