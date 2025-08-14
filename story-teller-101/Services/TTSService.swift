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
    
    // Constants for pause durations
    private let commaPause: TimeInterval = 0.15  // Reduced from 0.3
    private let colonSemicolonPause: TimeInterval = 0.25  // New: for colons and semicolons
    private let hyphenDashPause: TimeInterval = 0.2  // New: for hyphens and dashes
    private let sentencePause: TimeInterval = 0.6
    private let paragraphPause: TimeInterval = 1.0
    
    // Speech rate adjustments for different punctuation
    private let commaRateMultiplier: Float = 0.9  // Slightly slower at commas
    private let sentenceRateMultiplier: Float = 0.95  // Slightly slower at sentence ends
    
    // Queue for managing speech chunks
    private var speechQueue: [AVSpeechUtterance] = []
    private var currentUtterance: AVSpeechUtterance?
    private var spokenUtteranceIds: Set<ObjectIdentifier> = []
    
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
            case .colonSemicolon:
                adjustedRate = rate
            case .hyphenDash:
                adjustedRate = rate
            case .none:
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
        
        // Start speaking the first utterance only if we have chunks
        if let firstUtterance = speechQueue.first {
            isSpeaking = true
            safelySpeak(firstUtterance)
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speechQueue.removeAll()
        currentUtterance = nil
        isSpeaking = false
        spokenUtteranceIds.removeAll()
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func resume() {
        if currentUtterance != nil {
            synthesizer.continueSpeaking()
            isSpeaking = true
        }
    }
    
    func updateRate(_ newRate: Float) {
        // Update rate for current and remaining utterances
        for utterance in speechQueue {
            utterance.rate = newRate
        }
    }
    
    func updatePitch(_ newPitch: Float) {
        // Update pitch for current and remaining utterances
        for utterance in speechQueue {
            utterance.pitchMultiplier = newPitch
        }
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
        safelySpeak(nextUtterance)
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
        safelySpeak(previousUtterance)
    }
    
    func skipToChunk(at index: Int) {
        guard index >= 0 && index < speechQueue.count else { return }
        
        // Stop current utterance
        synthesizer.stopSpeaking(at: .immediate)
        
        // Start with specified utterance
        let targetUtterance = speechQueue[index]
        safelySpeak(targetUtterance)
    }
    
    private func safelySpeak(_ utterance: AVSpeechUtterance) {
        // Check if this utterance has already been spoken
        let utteranceId = ObjectIdentifier(utterance)
        if !spokenUtteranceIds.contains(utteranceId) && !synthesizer.isSpeaking {
            currentUtterance = utterance
            spokenUtteranceIds.insert(utteranceId)
            synthesizer.speak(utterance)
        }
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
            
            // Only speak the next utterance if we're still supposed to be speaking
            if isSpeaking, let nextUtterance = speechQueue.first {
                safelySpeak(nextUtterance)
            } else if speechQueue.isEmpty {
                // All utterances finished
                isSpeaking = false
                currentUtterance = nil
                spokenUtteranceIds.removeAll()
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speechQueue.removeAll()
            isSpeaking = false
            currentUtterance = nil
            spokenUtteranceIds.removeAll()
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
        case colonSemicolon
        case hyphenDash
        case none
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
            
            // Split sentence by punctuation
            let punctuationChunks = splitSentenceByPunctuation(sentence)
            
            for (index, chunk) in punctuationChunks.enumerated() {
                let isLastInSentence = index == punctuationChunks.count - 1
                
                // Check if this is actually a paragraph break (multiple newlines or significant spacing)
                let isLastInParagraph = isLastInSentence && (
                    sentenceRange.upperBound == text.endIndex || 
                    (sentenceRange.upperBound < text.endIndex && 
                     text[sentenceRange.upperBound...].prefix(3).allSatisfy { $0.isNewline || $0.isWhitespace })
                )
                
                let chunkType: ChunkType
                let pauseDuration: TimeInterval
                
                if !isLastInSentence {
                    // Determine pause type based on the punctuation that follows
                    let nextChunk = punctuationChunks[index + 1]
                    let punctuationType = getPunctuationType(for: nextChunk)
                    
                    switch punctuationType {
                    case .comma:
                        chunkType = .comma
                        pauseDuration = 0.15
                    case .colonSemicolon:
                        chunkType = .colonSemicolon
                        pauseDuration = 0.25
                    case .hyphenDash:
                        chunkType = .hyphenDash
                        pauseDuration = 0.2
                    case .none:
                        chunkType = .regular
                        pauseDuration = 0.0
                    case .sentence, .paragraph, .regular:
                        chunkType = .regular
                        pauseDuration = 0.0
                    }
                } else if isLastInParagraph {
                    // Add paragraph pause only for actual paragraph breaks
                    chunkType = .paragraph
                    pauseDuration = 1.0
                } else {
                    // Add sentence pause
                    chunkType = .sentence
                    pauseDuration = 0.6
                }
                
                chunks.append(SpeechChunk(
                    text: chunk.trimmingCharacters(in: .whitespaces),
                    pauseDuration: pauseDuration,
                    type: chunkType
                ))
            }
        }
        
        return chunks
    }
    
    private static func splitSentenceByPunctuation(_ sentence: String) -> [String] {
        var result: [String] = []
        var currentChunk = ""
        var parenthesesDepth = 0
        var quoteDepth = 0
        
        for char in sentence {
            if char == "(" { parenthesesDepth += 1 }
            if char == ")" { parenthesesDepth -= 1 }
            if char == "\"" { quoteDepth += 1 }
            if char == "'" { quoteDepth += 1 }
            
            // Split on commas, semicolons, colons, hyphens, and dashes if we're not inside parentheses or quotes
            if (char == "," || char == ";" || char == ":" || char == "-" || char == "—" || char == "–") && 
               parenthesesDepth == 0 && quoteDepth % 2 == 0 {
                if !currentChunk.trimmingCharacters(in: .whitespaces).isEmpty {
                    result.append(currentChunk.trimmingCharacters(in: .whitespaces))
                }
                currentChunk = ""
            } else {
                currentChunk.append(char)
            }
        }
        
        // Add the last chunk
        if !currentChunk.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(currentChunk.trimmingCharacters(in: .whitespaces))
        }
        
        return result.isEmpty ? [sentence] : result
    }
    
    private static func getPunctuationType(for text: String) -> ChunkType {
        if text.hasSuffix(",") { return .comma }
        if text.hasSuffix(";") { return .colonSemicolon }
        if text.hasSuffix("-") { return .hyphenDash }
        if text.hasSuffix("—") { return .hyphenDash } // Em dash
        if text.hasSuffix("–") { return .hyphenDash } // En dash
        return .none
    }
}

// MARK: - Character Extensions
extension Character {
    var isNewline: Bool {
        return self == "\n" || self == "\r" || self == "\r\n"
    }
}

