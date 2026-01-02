import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var name: String
    var fileName: String
    var duration: TimeInterval
    var bpm: Int
    var timeTop: Int
    var timeBottom: Int
    var countIn: Int
    var createdAt: Date
    var isFavorite: Bool
    
    var project: Project?
    
    init(
        name: String = "Take",
        fileName: String,
        duration: TimeInterval = 0,
        bpm: Int = 120,
        timeTop: Int = 4,
        timeBottom: Int = 4,
        countIn: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.duration = duration
        self.bpm = bpm
        self.timeTop = timeTop
        self.timeBottom = timeTop
        self.countIn = countIn
        self.createdAt = Date()
        self.isFavorite = false
    }
}
