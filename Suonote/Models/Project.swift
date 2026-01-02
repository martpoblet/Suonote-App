import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var title: String
    var status: ProjectStatus
    var tags: [String]
    var keyRoot: String
    var keyMode: KeyMode
    var bpm: Int
    var timeTop: Int
    var timeBottom: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade)
    var sectionTemplates: [SectionTemplate]
    
    @Relationship(deleteRule: .cascade)
    var arrangementItems: [ArrangementItem]
    
    @Relationship(deleteRule: .cascade)
    var recordings: [Recording]
    
    init(
        title: String = "New Idea",
        status: ProjectStatus = .idea,
        tags: [String] = [],
        keyRoot: String = "C",
        keyMode: KeyMode = .major,
        bpm: Int = 120,
        timeTop: Int = 4,
        timeBottom: Int = 4
    ) {
        self.id = UUID()
        self.title = title
        self.status = status
        self.tags = tags
        self.keyRoot = keyRoot
        self.keyMode = keyMode
        self.bpm = bpm
        self.timeTop = timeTop
        self.timeBottom = timeBottom
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sectionTemplates = []
        self.arrangementItems = []
        self.recordings = []
    }
    
    var recordingsCount: Int {
        recordings.count
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case idea = "Idea"
    case inProgress = "In Progress"
    case polished = "Polished"
    case finished = "Finished"
    case archived = "Archived"
    
    var color: String {
        switch self {
        case .idea: return "blue"
        case .inProgress: return "orange"
        case .polished: return "purple"
        case .finished: return "green"
        case .archived: return "gray"
        }
    }
}

enum KeyMode: String, Codable, CaseIterable {
    case major = "Major"
    case minor = "Minor"
}
