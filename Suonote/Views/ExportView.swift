import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var showingShareSheet = false
    @State private var shareItem: ShareItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.backgroundSecondary,
                        DesignSystem.Colors.backgroundTertiary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(DesignSystem.Typography.jumbo)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.info],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Export Project")
                                .font(DesignSystem.Typography.title)
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            
                            Text(project.title)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Export options
                        VStack(spacing: 16) {
                            ExportOptionCard(
                                title: "MIDI File",
                                subtitle: "For DAWs like Logic, Ableton, FL Studio",
                                icon: "pianokeys",
                                color: DesignSystem.Colors.primary
                            ) {
                                exportMIDI()
                            }
                            
                            ExportOptionCard(
                                title: "Chord Chart (Text)",
                                subtitle: "Lyrics and chords in plain text",
                                icon: "doc.text",
                                color: DesignSystem.Colors.info
                            ) {
                                exportText()
                            }
                            
                            ExportOptionCard(
                                title: "Full Project (Text)",
                                subtitle: "Complete project information",
                                icon: "doc.plaintext",
                                color: DesignSystem.Colors.accent
                            ) {
                                exportFullText()
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .presentationBackground(DesignSystem.Colors.backgroundSecondary)
        .preferredColorScheme(.light)
        
        .sheet(isPresented: $showingShareSheet) {
            if let item = shareItem {
                ShareSheet(items: [item.url])
            }
        }
    }
    
    private func exportMIDI() {
        let exporter = MIDIExporter()
        if let url = exporter.exportProject(project) {
            shareItem = ShareItem(url: url, type: .midi)
            showingShareSheet = true
        }
    }
    
    private func exportText() {
        let exporter = TextExporter()
        if let url = exporter.exportChordChart(project) {
            shareItem = ShareItem(url: url, type: .text)
            showingShareSheet = true
        }
    }
    
    private func exportFullText() {
        let exporter = TextExporter()
        if let url = exporter.exportFullProject(project) {
            shareItem = ShareItem(url: url, type: .text)
            showingShareSheet = true
        }
    }
}

struct ExportOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShareItem {
    let url: URL
    let type: ExportType
    
    enum ExportType {
        case midi, text
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - MIDI Exporter

class MIDIExporter {
    func exportProject(_ project: Project) -> URL? {
        let midiData = generateMIDIData(project)
        
        let fileName = "\(project.title.replacingOccurrences(of: " ", with: "_")).mid"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try midiData.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing MIDI file: \(error)")
            return nil
        }
    }
    
    private func generateMIDIData(_ project: Project) -> Data {
        var data = Data()
        
        // MIDI Header
        data.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x06]) // Header length
        data.append(contentsOf: [0x00, 0x01]) // Format 1
        data.append(contentsOf: [0x00, 0x02]) // 2 tracks
        data.append(contentsOf: [0x01, 0xE0]) // 480 ticks per quarter note
        
        // Track 1: Tempo and metadata
        let track1 = generateMetadataTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        data.append(contentsOf: UInt32(track1.count).bigEndianBytes)
        data.append(track1)
        
        // Track 2: Chords
        let track2 = generateChordTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        data.append(contentsOf: UInt32(track2.count).bigEndianBytes)
        data.append(track2)
        
        return data
    }
    
    private func generateMetadataTrack(_ project: Project) -> Data {
        var data = Data()
        
        // Track name
        data.append(contentsOf: [0x00, 0xFF, 0x03])
        let titleBytes = project.title.data(using: .utf8) ?? Data()
        data.append(UInt8(titleBytes.count))
        data.append(titleBytes)
        
        // Tempo (microseconds per quarter note)
        let quarterBpm = project.quarterNoteBpm()
        let microsecondsPerQuarter = UInt32(60_000_000.0 / max(1.0, quarterBpm))
        data.append(contentsOf: [0x00, 0xFF, 0x51, 0x03])
        data.append(contentsOf: [
            UInt8((microsecondsPerQuarter >> 16) & 0xFF),
            UInt8((microsecondsPerQuarter >> 8) & 0xFF),
            UInt8(microsecondsPerQuarter & 0xFF)
        ])
        
        // Time signature
        data.append(contentsOf: [0x00, 0xFF, 0x58, 0x04])
        data.append(UInt8(project.timeTop))
        let denominator = UInt8(log2(Double(project.timeBottom)))
        data.append(denominator)
        data.append(contentsOf: [0x18, 0x08]) // Clocks per tick, 32nds per quarter
        
        // End of track
        data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        return data
    }
    
    private func generateChordTrack(_ project: Project) -> Data {
        var data = Data()
        
        // Track name
        data.append(contentsOf: [0x00, 0xFF, 0x03, 0x06])
        data.append(contentsOf: "Chords".data(using: .utf8)!)
        
        var currentTick: Double = 0
        let ticksPerQuarter: Double = 480
        let ticksPerGridBeat = ticksPerQuarter * (4.0 / Double(project.timeBottom))
        
        // Process arrangement
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            
            for chord in section.chordEvents.sorted(by: { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }) {
                let chordStart = currentTick + (Double(chord.barIndex * project.timeTop) + chord.beatOffset) * ticksPerGridBeat
                let deltaTime = UInt32(max(0, chordStart - currentTick).rounded())
                
                // Note on
                data.append(contentsOf: encodeVariableLength(deltaTime))
                data.append(contentsOf: [0x90, getMIDINote(chord), 0x64]) // Note on, velocity 100
                
                // Note off (after duration)
                let durationTicks = UInt32((Double(chord.duration) * ticksPerGridBeat).rounded())
                data.append(contentsOf: encodeVariableLength(durationTicks))
                data.append(contentsOf: [0x80, getMIDINote(chord), 0x00]) // Note off
                
                currentTick = chordStart + Double(durationTicks)
            }
            
            currentTick += Double(section.bars * project.timeTop) * ticksPerGridBeat
        }
        
        // End of track
        data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        return data
    }
    
    private func getMIDINote(_ chord: ChordEvent) -> UInt8 {
        let noteMap: [String: UInt8] = [
            "C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
            "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71
        ]
        return noteMap[chord.root] ?? 60
    }
    
    private func encodeVariableLength(_ value: UInt32) -> [UInt8] {
        var result: [UInt8] = []
        var val = value
        
        result.append(UInt8(val & 0x7F))
        val >>= 7
        
        while val > 0 {
            result.insert(UInt8((val & 0x7F) | 0x80), at: 0)
            val >>= 7
        }
        
        return result
    }
}

// MARK: - Text Exporter

class TextExporter {
    func exportChordChart(_ project: Project) -> URL? {
        var text = "\(project.title)\n"
        text += "Key: \(project.keyRoot) \(project.keyMode.rawValue)\n"
        text += "Tempo: \(project.bpm) BPM\n"
        text += "Time: \(project.timeTop)/\(project.timeBottom)\n\n"
        text += String(repeating: "=", count: 40) + "\n\n"
        
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            
            text += "[\(section.name)]\n"
            
            // Chords
            if !section.chordEvents.isEmpty {
                text += "Chords:\n"
                for bar in 0..<section.bars {
                    let barChords = section.chordEvents.filter { $0.barIndex == bar }
                        .sorted { $0.beatOffset < $1.beatOffset }
                    
                    if !barChords.isEmpty {
                        text += "  Bar \(bar + 1): "
                        text += barChords.map { $0.display }.joined(separator: " - ")
                        text += "\n"
                    }
                }
            }
            
            // Lyrics
            if !section.lyricsText.isEmpty {
                text += "\nLyrics:\n"
                text += section.lyricsText + "\n"
            }
            
            text += "\n" + String(repeating: "-", count: 40) + "\n\n"
        }
        
        return saveToFile(text, fileName: "\(project.title)_ChordChart.txt")
    }
    
    func exportFullProject(_ project: Project) -> URL? {
        var text = "PROJECT: \(project.title)\n\n"
        text += "STATUS: \(project.status.rawValue)\n"
        text += "KEY: \(project.keyRoot) \(project.keyMode.rawValue)\n"
        text += "TEMPO: \(project.bpm) BPM\n"
        text += "TIME SIGNATURE: \(project.timeTop)/\(project.timeBottom)\n"
        
        if !project.tags.isEmpty {
            text += "TAGS: \(project.tags.joined(separator: ", "))\n"
        }
        
        text += "\nCREATED: \(project.createdAt.formatted())\n"
        text += "UPDATED: \(project.updatedAt.formatted())\n"
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"
        
        text += "ARRANGEMENT\n\n"
        for (index, item) in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated() {
            guard let section = item.sectionTemplate else { continue }
            text += "\(index + 1). \(section.name) (\(section.bars) bars)\n"
        }
        
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"
        
        // Unique sections
        var seenSections = Set<UUID>()
        for item in project.arrangementItems {
            guard let section = item.sectionTemplate,
                  !seenSections.contains(section.id) else { continue }
            seenSections.insert(section.id)
            
            text += "SECTION: \(section.name)\n"
            text += "Bars: \(section.bars)\n\n"
            
            if !section.chordEvents.isEmpty {
                text += "CHORDS:\n"
                for bar in 0..<section.bars {
                    let barChords = section.chordEvents.filter { $0.barIndex == bar }
                        .sorted { $0.beatOffset < $1.beatOffset }
                    
                    if !barChords.isEmpty {
                        text += "  Bar \(bar + 1): "
                        text += barChords.map { "\($0.display) (beat \($0.beatOffset + 1), \($0.duration)b)" }
                            .joined(separator: ", ")
                        text += "\n"
                    }
                }
                text += "\n"
            }
            
            if !section.lyricsText.isEmpty {
                text += "LYRICS:\n\(section.lyricsText)\n\n"
            }
            
            text += String(repeating: "-", count: 60) + "\n\n"
        }
        
        if !project.recordings.isEmpty {
            text += "RECORDINGS (\(project.recordings.count))\n\n"
            for recording in project.recordings.sorted(by: { $0.createdAt > $1.createdAt }) {
                text += "- \(recording.name)\n"
                text += "  Duration: \(formatDuration(recording.duration))\n"
                text += "  Created: \(recording.createdAt.formatted())\n\n"
            }
        }
        
        return saveToFile(text, fileName: "\(project.title)_Full.txt")
    }
    
    private func saveToFile(_ text: String, fileName: String) -> URL? {
        let cleanFileName = fileName.replacingOccurrences(of: " ", with: "_")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(cleanFileName)
        
        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Error writing text file: \(error)")
            return nil
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        return [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF)
        ]
    }
}
