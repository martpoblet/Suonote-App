import Foundation
import SwiftData

@Model
final class ArrangementItem {
    var id: UUID
    var orderIndex: Int
    var labelOverride: String?
    
    var sectionTemplate: SectionTemplate?
    var project: Project?
    
    init(orderIndex: Int, labelOverride: String? = nil) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.labelOverride = labelOverride
    }
}
