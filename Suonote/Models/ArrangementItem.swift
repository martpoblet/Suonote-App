import Foundation
import SwiftData

@Model
final class ArrangementItem {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var labelOverride: String? = nil
    
    var sectionTemplateId: UUID? = nil
    var projectStore: Project?
    
    init(orderIndex: Int, labelOverride: String? = nil) {
        self.orderIndex = orderIndex
        self.labelOverride = labelOverride
    }

    var sectionTemplate: SectionTemplate? {
        get {
            guard let projectStore, let sectionTemplateId else { return nil }
            return projectStore.sectionTemplates.first { $0.id == sectionTemplateId }
        }
        set {
            sectionTemplateId = newValue?.id
        }
    }

    var project: Project? {
        get { projectStore }
        set { projectStore = newValue }
    }
}
