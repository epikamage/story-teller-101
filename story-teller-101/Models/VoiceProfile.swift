import Foundation
import SwiftData

@Model
final class VoiceProfile {
    @Attribute(.unique)
    var id: UUID
    
    var name: String
    var defaultVoiceId: String
    var perCharacter: [String: String]
    
    init(
        id: UUID = UUID(),
        name: String,
        defaultVoiceId: String,
        perCharacter: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.defaultVoiceId = defaultVoiceId
        self.perCharacter = perCharacter
    }
}

