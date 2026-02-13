import SwiftData
import SwiftUI

/// Global search across projects, chords, lyrics, tags, and recordings (F-01)
struct GlobalSearchResult: Identifiable {
    let id = UUID()
    let project: Project
    let matchType: MatchType
    let matchDetail: String
    
    enum MatchType: String {
        case title = "Title"
        case chord = "Chord"
        case lyrics = "Lyrics"
        case tag = "Tag"
        case notes = "Notes"
        case key = "Key"
        case bpm = "BPM"
    }
}

class GlobalSearchEngine {
    
    static func search(query: String, in projects: [Project]) -> [GlobalSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        var results: [GlobalSearchResult] = []
        
        for project in projects {
            // Title match
            if project.title.lowercased().contains(q) {
                results.append(GlobalSearchResult(
                    project: project,
                    matchType: .title,
                    matchDetail: project.title
                ))
            }
            
            // Tag match
            for tag in project.tags where tag.lowercased().contains(q) {
                results.append(GlobalSearchResult(
                    project: project,
                    matchType: .tag,
                    matchDetail: tag
                ))
            }
            
            // Key match
            let keyStr = "\(project.keyRoot) \(project.keyMode.rawValue)".lowercased()
            if keyStr.contains(q) {
                results.append(GlobalSearchResult(
                    project: project,
                    matchType: .key,
                    matchDetail: "\(project.keyRoot) \(project.keyMode.rawValue)"
                ))
            }
            
            // BPM match
            if q == "\(project.bpm)" || "bpm \(project.bpm)".contains(q) {
                results.append(GlobalSearchResult(
                    project: project,
                    matchType: .bpm,
                    matchDetail: "\(project.bpm) BPM"
                ))
            }
            
            // Section content
            for section in project.sectionTemplates {
                // Chord match
                for chord in section.chordEvents {
                    if chord.display.lowercased().contains(q) || chord.root.lowercased().contains(q) {
                        results.append(GlobalSearchResult(
                            project: project,
                            matchType: .chord,
                            matchDetail: "\(section.name): \(chord.display)"
                        ))
                        break  // One match per section
                    }
                }
                
                // Lyrics match
                if section.lyricsText.lowercased().contains(q) {
                    let snippet = extractSnippet(from: section.lyricsText, around: q)
                    results.append(GlobalSearchResult(
                        project: project,
                        matchType: .lyrics,
                        matchDetail: "\(section.name): \(snippet)"
                    ))
                }
                
                // Notes match
                if section.notesText.lowercased().contains(q) {
                    results.append(GlobalSearchResult(
                        project: project,
                        matchType: .notes,
                        matchDetail: "\(section.name): \(String(section.notesText.prefix(60)))"
                    ))
                }
            }
        }
        
        return results
    }
    
    private static func extractSnippet(from text: String, around query: String, window: Int = 40) -> String {
        guard let range = text.lowercased().range(of: query) else {
            return String(text.prefix(60))
        }
        
        let startDist = text.distance(from: text.startIndex, to: range.lowerBound)
        let snippetStart = max(0, startDist - window / 2)
        let startIdx = text.index(text.startIndex, offsetBy: snippetStart)
        let endIdx = text.index(startIdx, offsetBy: min(window + query.count, text.distance(from: startIdx, to: text.endIndex)))
        
        var snippet = String(text[startIdx..<endIdx])
        if snippetStart > 0 { snippet = "…" + snippet }
        if endIdx < text.endIndex { snippet += "…" }
        return snippet
    }
}
