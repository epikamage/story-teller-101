import SwiftUI
import AVFoundation

struct ReaderView: View {
    @State private var rate: Float = 0.5
    @State private var pitch: Float = 1.0
    @State private var isSpeaking: Bool = false
    
    let chapter: Chapter
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if isSpeaking {
                            // Show chunked text with highlighting
                            ChunkedTextView(text: chapter.text, currentChunkIndex: TTSService.shared.currentChunkIndex)
                        } else {
                            // Show regular text
                            Text(chapter.text)
                                .font(.system(.body, design: .default))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: TTSService.shared.currentChunkIndex) { newIndex in
                    if isSpeaking {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            Divider()
            
            // Enhanced TTS Controls
            VStack(spacing: 12) {
                // Progress and Current Chunk Info
                if isSpeaking {
                    VStack(spacing: 8) {
                        ProgressView(value: TTSService.shared.speakingProgress)
                            .progressViewStyle(.linear)
                        
                        HStack {
                            Text("Chunk \(TTSService.shared.currentChunkIndex + 1) of \(TTSService.shared.totalChunks)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if let currentText = TTSService.shared.currentChunkText {
                                Text(currentText.prefix(50) + (currentText.count > 50 ? "..." : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Pause duration info
                        if TTSService.shared.currentChunkIndex < TTSService.shared.totalChunks - 1 {
                            let chunks = TextSegmenter.segmentText(chapter.text)
                            let currentChunk = chunks[TTSService.shared.currentChunkIndex]
                            HStack {
                                Text("Next pause: \(String(format: "%.1f", currentChunk.pauseDuration))s")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("Type: \(chunkTypeDescription(currentChunk.type))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Time estimates
                        HStack {
                            Text("Total: \(formatTime(TTSService.shared.estimatedSpeakingTime))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Remaining: \(formatTime(TTSService.shared.estimatedRemainingTime))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Main Controls
                HStack(spacing: 16) {
                    // Previous Chunk
                    Button {
                        TTSService.shared.skipToPreviousChunk()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                    }
                    .disabled(!isSpeaking || TTSService.shared.currentChunkIndex <= 0)
                    
                    // Play/Pause
                    Button {
                        if isSpeaking {
                            TTSService.shared.pause()
                            isSpeaking = false
                        } else {
                            TTSService.shared.speak(text: chapter.text, voiceId: TTSService.shared.preferredVoiceIdentifier, rate: rate, pitch: pitch)
                            isSpeaking = true
                        }
                    } label: {
                        Image(systemName: isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                    }
                    
                    // Stop
                    Button {
                        TTSService.shared.stop()
                        isSpeaking = false
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 20))
                    }
                    
                    // Next Chunk
                    Button {
                        TTSService.shared.skipToNextChunk()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                    }
                    .disabled(!isSpeaking || TTSService.shared.currentChunkIndex >= TTSService.shared.totalChunks - 1)
                    
                    Spacer()
                }
                
                // Settings Controls
                HStack(spacing: 16) {
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
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func chunkTypeDescription(_ type: TextSegmenter.ChunkType) -> String {
        switch type {
        case .comma: return "Comma"
        case .sentence: return "Sentence"
        case .paragraph: return "Paragraph"
        case .regular: return "Regular"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Chunked Text View
struct ChunkedTextView: View {
    let text: String
    let currentChunkIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let chunks = TextSegmenter.segmentText(text)
            
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                Text(chunk.text)
                    .font(.system(.body, design: .default))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(index == currentChunkIndex ? Color.blue.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(index == currentChunkIndex ? Color.blue : Color.clear, lineWidth: 1)
                    )
                    .id(index) // For scrolling
            }
        }
    }
}

