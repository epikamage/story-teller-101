import SwiftUI

struct ReaderView: View {
    @State private var rate: Float = 0.5
    @State private var pitch: Float = 1.0
    @State private var isSpeaking: Bool = false
    
    let chapter: Chapter
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(chapter.text)
                    .font(.system(.body, design: .default))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 16) {
                Button {
                    if isSpeaking {
                        TTSService.shared.pause()
                        isSpeaking = false
                    } else {
                        // If user selected a preferred voice (e.g., Personal Voice), it will be used
                        TTSService.shared.speak(text: chapter.text, voiceId: TTSService.shared.preferredVoiceIdentifier, rate: rate, pitch: pitch)
                        isSpeaking = true
                    }
                } label: {
                    Image(systemName: isSpeaking ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 28))
                }
                Button {
                    TTSService.shared.stop()
                    isSpeaking = false
                } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 28))
                }
                VStack(alignment: .leading) {
                    Text("Rate: \(String(format: "%.2f", rate))").font(.caption)
                    Slider(value: Binding(get: { Double(rate) }, set: { rate = Float($0) }), in: 0.3...0.6)
                }
                VStack(alignment: .leading) {
                    Text("Pitch: \(String(format: "%.2f", pitch))").font(.caption)
                    Slider(value: Binding(get: { Double(pitch) }, set: { pitch = Float($0) }), in: 0.5...2.0)
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

