import Foundation
import AVFoundation
import NaturalLanguage

@MainActor
@preconcurrency
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking: Bool = false
    private let preferredVoiceIdKey = "preferredVoiceIdentifier"
    
    // Pause durations in seconds
    private let commaPause: TimeInterval = 0.3
    private let sentencePause: TimeInterval = 0.6
    private let paragraphPause: TimeInterval = 1.0
    
    // Speech rate adjustments for different punctuation
    private let commaRateMultiplier: Float = 0.9  // Slightly slower at commas
    private let sentenceRateMultiplier: Float = 0.95  // Slightly slower at sentence ends
    
    // Queue for managing speech chunks
    private var speechQueue: [AVSpeechUtterance] = []
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
    
    func speak(text: String, voiceId: String?, rate: Float, pitch: Float) {
        stop() // Stop any current speech
        
        // Split text into intelligently segmented chunks
        let chunks = TextSegmenter.segmentText(text)
        
        // Create utterances for each chunk with appropriate pauses
        speechQueue = chunks.enumerated().map { index, chunk in
            let utterance = AVSpeechUtterance(string: chunk.text)
            
            // Apply rate adjustments based on chunk type
            var adjustedRate = rate
            switch chunk.type {
            case .comma:
                adjustedRate *= commaRateMultiplier
            case .sentence:
                adjustedRate *= sentenceRateMultiplier
            case .paragraph, .regular:
                adjustedRate = rate
            }
            
            utterance.rate = adjustedRate
            utterance.pitchMultiplier = pitch
            
            // Set voice
            let resolvedVoiceId = voiceId ?? preferredVoiceIdentifier
            if let resolvedVoiceId, let voice = AVSpeechSynthesisVoice(identifier: resolvedVoiceId) {
                utterance.voice = voice
            }
            
            // Add appropriate pause after this chunk
            if index < chunks.count - 1 {
                let nextChunk = chunks[index + 1]
                utterance.postUtteranceDelay = nextChunk.pauseDuration
            }
            
            return utterance
        }
        
        // Start speaking the first utterance
        if let firstUtterance = speechQueue.first {
            currentUtterance = firstUtterance
            synthesizer.speak(firstUtterance)
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speechQueue.removeAll()
        currentUtterance = nil
        isSpeaking = false
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    func skipToNextChunk() {
        guard let utterance = currentUtterance,
              let currentIndex = speechQueue.firstIndex(where: { $0 == utterance }),
              currentIndex + 1 < speechQueue.count else {
            return
        }
        
        // Stop current utterance
        synthesizer.stopSpeaking(at: .immediate)
        
        // Start with next utterance
        let nextUtterance = speechQueue[currentIndex + 1]
        currentUtterance = nextUtterance
        synthesizer.speak(nextUtterance)
    }
    
    func skipToPreviousChunk() {
        guard let utterance = currentUtterance,
              let currentIndex = speechQueue.firstIndex(where: { $0 == utterance }),
              currentIndex > 0 else {
            return
        }
        
        // Stop current utterance
        synthesizer.stopSpeaking(at: .immediate)
        
        // Start with previous utterance
        let previousUtterance = speechQueue[currentIndex - 1]
        currentUtterance = previousUtterance
        synthesizer.speak(previousUtterance)
    }
    
    func skipToChunk(at index: Int) {
        guard index >= 0 && index < speechQueue.count else { return }
        
        // Stop current utterance
        synthesizer.stopSpeaking(at: .immediate)
        
        // Start with specified utterance
        let targetUtterance = speechQueue[index]
        currentUtterance = targetUtterance
        synthesizer.speak(targetUtterance)
    }
    
    // MARK: - Progress and State
    var currentChunkIndex: Int {
        guard let utterance = currentUtterance,
              let index = speechQueue.firstIndex(where: { $0 == utterance }) else {
            return 0
        }
        return index
    }
    
    var totalChunks: Int {
        return speechQueue.count
    }
    
    var speakingProgress: Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(currentChunkIndex) / Double(totalChunks)
    }
    
    var currentChunkText: String? {
        return currentUtterance?.speechString
    }
    
    var remainingChunks: Int {
        return max(0, totalChunks - currentChunkIndex)
    }
    
    var estimatedSpeakingTime: TimeInterval {
        guard totalChunks > 0 else { return 0.0 }
        
        var totalTime: TimeInterval = 0
        
        for chunk in speechQueue {
            // Estimate time for this chunk based on text length and speech rate
            let estimatedChunkTime = TimeInterval(chunk.speechString.count) / 10.0 // Rough estimate: 10 chars per second at normal rate
            totalTime += estimatedChunkTime
            
            // Add pause time
            totalTime += chunk.postUtteranceDelay
        }
        
        return totalTime
    }
    
    var estimatedRemainingTime: TimeInterval {
        guard totalChunks > 0 else { return 0.0 }
        
        let progress = speakingProgress
        let totalTime = estimatedSpeakingTime
        return totalTime * (1.0 - progress)
    }
    
    // MARK: - Personal Voice & Preferences
    var preferredVoiceIdentifier: String? {
        get { UserDefaults.standard.string(forKey: preferredVoiceIdKey) }
        set { UserDefaults.standard.setValue(newValue, forKey: preferredVoiceIdKey) }
    }
    
    nonisolated static func requestPersonalVoiceAuthorization(completion: @escaping (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void) {
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
            completion(status)
        }
    }
    
    nonisolated static func personalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Remove the finished utterance from queue
            if let index = speechQueue.firstIndex(where: { $0 == utterance }) {
                speechQueue.remove(at: index)
            }
            
            // Speak the next utterance if available
            if let nextUtterance = speechQueue.first {
                currentUtterance = nextUtterance
                synthesizer.speak(nextUtterance)
            } else {
                // All utterances finished
                isSpeaking = false
                currentUtterance = nil
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speechQueue.removeAll()
            isSpeaking = false
            currentUtterance = nil
        }
    }
}

// MARK: - Text Segmentation
struct TextSegmenter {
    
    struct SpeechChunk {
        let text: String
        let pauseDuration: TimeInterval
        let type: ChunkType
    }
    
    enum ChunkType {
        case comma
        case sentence
        case paragraph
        case regular
    }
    
    static func segmentText(_ text: String) -> [SpeechChunk] {
        var chunks: [SpeechChunk] = []
        
        // Create tokenizer for sentence and word boundaries
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        // Get sentence ranges
        let sentenceRanges = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        
        for sentenceRange in sentenceRanges {
            let sentence = String(text[sentenceRange])
            
            // Split sentence by commas and other punctuation
            let commaChunks = splitSentenceByPunctuation(sentence)
            
            for (index, commaChunk) in commaChunks.enumerated() {
                let isLastInSentence = index == commaChunks.count - 1
                let isLastInParagraph = sentenceRange.upperBound == text.endIndex || 
                    (sentenceRange.upperBound < text.endIndex && 
                     text[sentenceRange.upperBound].isNewline)
                
                let chunkType: ChunkType
                let pauseDuration: TimeInterval
                
                if !isLastInSentence {
                    // Add comma pause
                    chunkType = .comma
                    pauseDuration = 0.3
                } else if isLastInParagraph {
                    // Add paragraph pause
                    chunkType = .paragraph
                    pauseDuration = 1.0
                } else {
                    // Add sentence pause
                    chunkType = .sentence
                    pauseDuration = 0.6
                }
                
                chunks.append(SpeechChunk(
                    text: commaChunk.trimmingCharacters(in: .whitespaces),
                    pauseDuration: pauseDuration,
                    type: chunkType
                ))
            }
        }
        
        return chunks.filter { !$0.text.isEmpty }
    }
    
    private static func splitSentenceByPunctuation(_ sentence: String) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        var parenthesesDepth = 0
        var bracketDepth = 0
        var quoteDepth = 0
        
        for char in sentence {
            // Track nested structures
            switch char {
            case "(": parenthesesDepth += 1
            case ")": parenthesesDepth -= 1
            case "[": bracketDepth += 1
            case "]": bracketDepth -= 1
            case "\"": quoteDepth += 1
            case "'": quoteDepth += 1
            default: break
            }
            
            // Only split on punctuation when not inside nested structures
            if (char == "," || char == ";" || char == ":") && 
               parenthesesDepth == 0 && bracketDepth == 0 && quoteDepth % 2 == 0 {
                chunks.append(currentChunk)
                currentChunk = ""
            } else {
                currentChunk.append(char)
            }
        }
        
        // Add the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
}

// MARK: - Character Extensions
extension Character {
    var isNewline: Bool {
        return self == "\n" || self == "\r" || self == "\r\n"
    }
}

