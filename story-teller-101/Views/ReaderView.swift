import SwiftUI
import AVFoundation

struct ReaderView: View {
    let chapter: Chapter
    @State private var rate: Float = 0.5
    @State private var pitch: Float = 1.0
    @State private var isSpeaking: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(chapter.text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Divider()
            
            // TTS Controls
            VStack(spacing: 16) {
                // Progress and Chunk Info
                if TTSService.shared.isSpeaking {
                    VStack(spacing: 8) {
                        ProgressView(value: TTSService.shared.speakingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        HStack {
                            Text("Chunk \(TTSService.shared.currentChunkIndex + 1) of \(TTSService.shared.totalChunks)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let currentText = TTSService.shared.currentChunkText {
                                Text("\(currentText.prefix(50))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if TTSService.shared.currentChunkIndex < TTSService.shared.totalChunks - 1 {
                            let nextChunk = TextSegmenter.segmentText(chapter.text)[TTSService.shared.currentChunkIndex + 1]
                            HStack {
                                Text("Next: \(chunkTypeDescription(nextChunk.type))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Pause: \(String(format: "%.1fs", nextChunk.pauseDuration))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Total: \(formatTime(TTSService.shared.estimatedSpeakingTime))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Remaining: \(formatTime(TTSService.shared.estimatedRemainingTime))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Navigation Controls
                HStack(spacing: 20) {
                    Button(action: {
                        TTSService.shared.skipToPreviousChunk()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .disabled(!TTSService.shared.isSpeaking || TTSService.shared.currentChunkIndex <= 0)
                    
                    Button(action: {
                        if TTSService.shared.isSpeaking {
                            TTSService.shared.pause()
                        } else {
                            // Start speaking from the beginning if not already speaking
                            TTSService.shared.speak(text: chapter.text, voiceId: TTSService.shared.preferredVoiceIdentifier, rate: rate, pitch: pitch)
                        }
                    }) {
                        Image(systemName: TTSService.shared.isSpeaking ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                    
                    Button(action: {
                        TTSService.shared.skipToNextChunk()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .disabled(!TTSService.shared.isSpeaking || TTSService.shared.currentChunkIndex >= TTSService.shared.totalChunks - 1)
                }
                
                // Stop Button
                Button(action: {
                    TTSService.shared.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                // Rate and Pitch Controls
                VStack(spacing: 12) {
                    HStack {
                        Text("Rate")
                        Slider(value: $rate, in: 0.1...1.0, step: 0.1)
                        Text("\(String(format: "%.1f", rate))")
                    }
                    
                    HStack {
                        Text("Pitch")
                        Slider(value: $pitch, in: 0.5...2.0, step: 0.1)
                        Text("\(String(format: "%.1f", pitch))")
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(chapter.title)
        .onAppear {
            isSpeaking = TTSService.shared.isSpeaking
        }
        .onChange(of: TTSService.shared.isSpeaking) { newValue in
            isSpeaking = newValue
        }
        .onChange(of: rate) { newRate in
            if TTSService.shared.isSpeaking {
                TTSService.shared.updateRate(newRate)
            }
        }
        .onChange(of: pitch) { newPitch in
            if TTSService.shared.isSpeaking {
                TTSService.shared.updatePitch(newPitch)
            }
        }
    }
    
    private func chunkTypeDescription(_ type: TextSegmenter.ChunkType) -> String {
        switch type {
        case .comma: return "Comma"
        case .sentence: return "Sentence"
        case .paragraph: return "Paragraph"
        case .regular: return "Regular"
        case .colonSemicolon: return "Colon/Semicolon"
        case .hyphenDash: return "Hyphen/Dash"
        case .none: return "None"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

