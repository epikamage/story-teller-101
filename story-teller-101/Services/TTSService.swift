import Foundation
import AVFoundation

@MainActor
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking: Bool = false
    private let preferredVoiceIdKey = "preferredVoiceIdentifier"
    
    override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
    
    func speak(text: String, voiceId: String?, rate: Float, pitch: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        let resolvedVoiceId = voiceId ?? preferredVoiceIdentifier
        if let resolvedVoiceId, let voice = AVSpeechSynthesisVoice(identifier: resolvedVoiceId) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
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
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

