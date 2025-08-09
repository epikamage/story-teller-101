import Foundation
import SwiftData

@Model
final class Chapter {
    @Attribute(.unique)
    var id: UUID
    
    var index: Int
    var title: String
    var text: String
    var characterMap: [String: String]?
    var progress: Double
    
    var book: Book?
    
    init(
        id: UUID = UUID(),
        index: Int,
        title: String,
        text: String,
        characterMap: [String: String]? = nil,
        progress: Double = 0.0,
        book: Book? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.text = text
        self.characterMap = characterMap
        self.progress = progress
        self.book = book
    }
}

