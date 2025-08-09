import Foundation
import Vision

enum OCRServiceError: Error {
    case recognitionFailed
}

struct OCRService {
    static func recognizeText(in cgImage: CGImage, languages: [String]) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
        return text
    }
}

