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
                DesignSystem.Colors.backgroundSecondary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(DesignSystem.Typography.jumbo)
                                .foregroundStyle(DesignSystem.Colors.primary)
                            
                            Text("Export Project")
                                .font(DesignSystem.Typography.title)
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                            
                            Text(project.title)
                                .font(DesignSystem.Typography.body)
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
                            
                            ExportOptionCard(
                                title: "Chord Chart (PDF)",
                                subtitle: "Printable chord chart with sections",
                                icon: "doc.richtext",
                                color: DesignSystem.Colors.success
                            ) {
                                exportPDF()
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
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
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
    
    private func exportPDF() {
        let data = ChordChartPDFGenerator.generatePDF(for: project)
        let fileName = "\(project.title.replacingOccurrences(of: " ", with: "_"))_chords.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            shareItem = ShareItem(url: url, type: .text)
            showingShareSheet = true
        } catch {
            print("PDF export error: \(error)")
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
        data.append(contentsOf: [0x00, 0x04]) // 4 tracks (meta, chords, bass, drums)
        data.append(contentsOf: [0x01, 0xE0]) // 480 ticks per quarter note
        
        // Track 1: Tempo and metadata
        let track1 = generateMetadataTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        data.append(contentsOf: UInt32(track1.count).bigEndianBytes)
        data.append(track1)
        
        // Track 2: Chords (channel 0)
        let track2 = generateChordTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        data.append(contentsOf: UInt32(track2.count).bigEndianBytes)
        data.append(track2)
        
        // Track 3: Bass (channel 1) — P-03
        let track3 = generateBassTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        data.append(contentsOf: UInt32(track3.count).bigEndianBytes)
        data.append(track3)
        
        // Track 4: Drums (channel 9) — P-03
        let track4 = generateDrumTrack(project)
        data.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        data.append(contentsOf: UInt32(track4.count).bigEndianBytes)
        data.append(track4)
        
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
                guard !chord.isRest else { continue }
                let chordStart = currentTick + (Double(chord.barIndex * project.timeTop) + chord.beatOffset) * ticksPerGridBeat
                let deltaTime = UInt32(max(0, chordStart - currentTick).rounded())
                let durationTicks = UInt32((Double(chord.duration) * ticksPerGridBeat).rounded())
                let midiNotes = getMIDINotes(chord)
                
                // Note on for all notes in the chord
                for (i, note) in midiNotes.enumerated() {
                    let delta: UInt32 = (i == 0) ? deltaTime : 0
                    data.append(contentsOf: encodeVariableLength(delta))
                    data.append(contentsOf: [0x90, note, 0x64])
                }
                
                // Note off for all notes in the chord
                for (i, note) in midiNotes.enumerated() {
                    let delta: UInt32 = (i == 0) ? durationTicks : 0
                    data.append(contentsOf: encodeVariableLength(delta))
                    data.append(contentsOf: [0x80, note, 0x00])
                }
                
                currentTick = chordStart + Double(durationTicks)
            }
            
            currentTick += Double(section.bars * project.timeTop) * ticksPerGridBeat
        }
        
        // End of track
        data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        return data
    }
    
    /// Returns all MIDI notes for a chord voicing (root in octave 4)
    private func getMIDINotes(_ chord: ChordEvent) -> [UInt8] {
        let noteMap: [String: UInt8] = [
            "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63,
            "E": 64, "F": 65, "F#": 66, "Gb": 66, "G": 67, "G#": 68,
            "Ab": 68, "A": 69, "A#": 70, "Bb": 70, "B": 71
        ]
        let rootMidi = noteMap[chord.root] ?? 60
        return chord.quality.intervals.map { interval in
            UInt8(clamping: Int(rootMidi) + interval)
        }
    }
    
    // Keep backward compatibility
    private func getMIDINote(_ chord: ChordEvent) -> UInt8 {
        getMIDINotes(chord).first ?? 60
    }
    
    /// Bass track: root notes one octave below chords (P-03)
    private func generateBassTrack(_ project: Project) -> Data {
        var data = Data()
        
        // Track name
        data.append(contentsOf: [0x00, 0xFF, 0x03, 0x04])
        data.append(contentsOf: "Bass".data(using: .utf8)!)
        
        // Program change: Acoustic Bass (program 32) on channel 1
        data.append(contentsOf: [0x00, 0xC1, 0x20])
        
        var currentTick: Double = 0
        let ticksPerQuarter: Double = 480
        let ticksPerGridBeat = ticksPerQuarter * (4.0 / Double(project.timeBottom))
        
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            
            for chord in section.chordEvents.sorted(by: { ($0.barIndex, $0.beatOffset) < ($1.barIndex, $1.beatOffset) }) {
                guard !chord.isRest else { continue }
                let chordStart = currentTick + (Double(chord.barIndex * project.timeTop) + chord.beatOffset) * ticksPerGridBeat
                let deltaTime = UInt32(max(0, chordStart - currentTick).rounded())
                let durationTicks = UInt32((Double(chord.duration) * ticksPerGridBeat).rounded())
                
                // Bass: root note 2 octaves below chord (C2 = 36)
                let bassNote = UInt8(clamping: Int(getMIDINote(chord)) - 24)
                let velocity: UInt8 = 0x60  // Moderate velocity
                
                data.append(contentsOf: encodeVariableLength(deltaTime))
                data.append(contentsOf: [0x91, bassNote, velocity])
                
                data.append(contentsOf: encodeVariableLength(durationTicks))
                data.append(contentsOf: [0x81, bassNote, 0x00])
                
                currentTick = chordStart + Double(durationTicks)
            }
            currentTick += Double(section.bars * project.timeTop) * ticksPerGridBeat
        }
        
        data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        return data
    }
    
    /// Drum track: basic kick/snare/hihat pattern (P-03)
    private func generateDrumTrack(_ project: Project) -> Data {
        var data = Data()
        
        // Track name
        data.append(contentsOf: [0x00, 0xFF, 0x03, 0x05])
        data.append(contentsOf: "Drums".data(using: .utf8)!)
        
        let ticksPerQuarter: Double = 480
        let ticksPerGridBeat = ticksPerQuarter * (4.0 / Double(project.timeBottom))
        let ticksPerBeat = UInt32(ticksPerGridBeat.rounded())
        let halfBeat = ticksPerBeat / 2
        
        // GM Drum notes
        let kick: UInt8 = 36
        let snare: UInt8 = 38
        let hihat: UInt8 = 42
        let velocity: UInt8 = 0x64
        
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let totalBeats = section.bars * project.timeTop
            
            for beat in 0..<totalBeats {
                let isDownbeat = beat % project.timeTop == 0
                let isBackbeat = project.timeTop >= 4 && (beat % project.timeTop == 2)
                
                // Hihat on every beat
                data.append(contentsOf: encodeVariableLength(0))
                data.append(contentsOf: [0x99, hihat, velocity])
                
                // Kick on downbeats
                if isDownbeat {
                    data.append(contentsOf: encodeVariableLength(0))
                    data.append(contentsOf: [0x99, kick, velocity])
                }
                
                // Snare on backbeats
                if isBackbeat {
                    data.append(contentsOf: encodeVariableLength(0))
                    data.append(contentsOf: [0x99, snare, velocity])
                }
                
                // Note offs after half beat
                data.append(contentsOf: encodeVariableLength(halfBeat))
                data.append(contentsOf: [0x89, hihat, 0x00])
                if isDownbeat {
                    data.append(contentsOf: encodeVariableLength(0))
                    data.append(contentsOf: [0x89, kick, 0x00])
                }
                if isBackbeat {
                    data.append(contentsOf: encodeVariableLength(0))
                    data.append(contentsOf: [0x89, snare, 0x00])
                }
                
                // Hihat on the "and" (8th note)
                data.append(contentsOf: encodeVariableLength(0))
                data.append(contentsOf: [0x99, hihat, UInt8(velocity - 20)])
                data.append(contentsOf: encodeVariableLength(halfBeat))
                data.append(contentsOf: [0x89, hihat, 0x00])
            }
        }
        
        data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        return data
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
