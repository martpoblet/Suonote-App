import SwiftUI
import SwiftData
import Observation

/// ViewModel for Studio tab — handles async generation and caching (A-07, A-08)
@Observable
@MainActor
class StudioViewModel {
    var isGenerating: Bool = false
    var generationProgress: String = ""
    
    // Cached timeline data (A-08)
    private(set) var cachedTimeline: (chords: [StudioGenerator.ChordSpan], totalBars: Int)?
    private var lastTimelineSignature: String?
    
    /// Generate or regenerate tracks asynchronously
    func generateTracks(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext
    ) async {
        isGenerating = true
        generationProgress = "Generating arrangement..."
        
        // Capture values needed off main actor
        let projectRef = project
        let styleRef = style
        
        // Run generation - StudioGenerator is @MainActor so we run it here
        // but we yield periodically to keep UI responsive
        await Task.yield()
        
        let _ = StudioGenerator.generateTracks(
            for: projectRef,
            style: styleRef,
            modelContext: modelContext
        )
        
        generationProgress = ""
        isGenerating = false
    }
    
    /// Regenerate notes asynchronously
    func regenerateNotes(
        for project: Project,
        style: StudioStyle,
        modelContext: ModelContext,
        resetDrumPreset: Bool = false,
        includeDrums: Bool = true
    ) async {
        isGenerating = true
        generationProgress = "Regenerating notes..."
        
        await Task.yield()
        
        StudioGenerator.regenerateNotes(
            for: project,
            style: style,
            modelContext: modelContext,
            resetDrumPreset: resetDrumPreset,
            includeDrums: includeDrums
        )
        
        generationProgress = ""
        isGenerating = false
    }
    
    /// Update cached timeline if project content changed
    func updateTimelineIfNeeded(for project: Project) {
        let signature = project.studioLastChordSignature ?? ""
        guard signature != lastTimelineSignature else { return }
        
        cachedTimeline = StudioGenerator.timeline(for: project)
        lastTimelineSignature = signature
    }
    
    /// Invalidate caches when project changes significantly
    func invalidateCache() {
        cachedTimeline = nil
        lastTimelineSignature = nil
    }
}
