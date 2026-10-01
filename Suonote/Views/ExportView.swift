import SwiftUI
import os

/// Export & share: a clear menu of formats grouped by who they're for.
/// Each option builds its file(s), then hands off to the system share sheet.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var shareItem: ShareItem?
    @State private var working: ExportFormat?
    @State private var failedFormat: ExportFormat?
    @State private var mixProgress: Double = 0
    @State private var mixTask: Task<Void, Never>?

    enum ExportFormat: String, Identifiable {
        case pdf, chordText, lyrics, studioMix, midi, takes, fullText, projectFile
        var id: String { rawValue }

        var title: String {
            switch self {
            case .pdf: return String(localized: "Chord chart")
            case .chordText: return String(localized: "Chord chart, plain text")
            case .lyrics: return String(localized: "Lyric sheet")
            case .studioMix: return String(localized: "Studio mix")
            case .midi: return String(localized: "MIDI")
            case .takes: return String(localized: "Recorded takes")
            case .fullText: return String(localized: "Song notes")
            case .projectFile: return String(localized: "Suonote file")
            }
        }

        var badge: String {
            switch self {
            case .pdf: return "PDF"
            case .chordText, .lyrics, .fullText: return "TXT"
            case .midi: return "MID"
            case .studioMix: return "M4A"
            case .takes: return "AUDIO"
            case .projectFile: return "SUONOTE"
            }
        }

        var icon: String {
            switch self {
            case .pdf: return "doc.richtext"
            case .chordText: return "text.alignleft"
            case .lyrics: return "text.quote"
            case .midi: return "pianokeys"
            case .studioMix: return "hifispeaker.2"
            case .takes: return "waveform"
            case .fullText: return "doc.plaintext"
            case .projectFile: return "shippingbox"
            }
        }
    }

    // MARK: Availability

    private var sections: [SectionTemplate] { project.libraryArrangement }
    private var hasChords: Bool { sections.contains { !$0.chordEvents.isEmpty } }
    private var hasLyrics: Bool {
        sections.contains { !$0.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var hasStudioTracks: Bool { !project.studioTracks.isEmpty && project.libraryTotalBars > 0 }
    private var takeURLs: [URL] {
        project.recordings
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { FileManagerUtils.existingRecordingURL(for: $0.fileName) }
    }

    private func description(for format: ExportFormat) -> String {
        switch format {
        case .pdf: return String(localized: "Printable chart with every section and its chords.")
        case .chordText: return String(localized: "Chords bar by bar, with lyrics — paste anywhere.")
        case .lyrics: return hasLyrics ? String(localized: "Just the words, in song order.") : String(localized: "No lyrics written yet.")
        case .studioMix:
            if working == .studioMix { return String(localized: "Rendering… \(Int(mixProgress * 100))%") }
            return hasStudioTracks ? String(localized: "Your Studio arrangement as one finished audio file.") : String(localized: "Add instruments in Studio to export a mix.")
        case .midi: return hasChords ? String(localized: "Chords, bass and drums for Logic, Ableton, FL…") : String(localized: "Add chords in Compose to export MIDI.")
        case .takes:
            let count = takeURLs.count
            return count == 0 ? String(localized: "No takes recorded yet.") : String(localized: "\(count) audio files from Record.")
        case .fullText: return String(localized: "Everything: details, arrangement, chords, lyrics, takes.")
        case .projectFile: return String(localized: "The whole song, to open in Suonote on another device.")
        }
    }

    private func isAvailable(_ format: ExportFormat) -> Bool {
        switch format {
        case .lyrics: return hasLyrics
        case .midi: return hasChords
        case .studioMix: return hasStudioTracks
        case .takes: return !takeURLs.isEmpty
        default: return true
        }
    }

    // MARK: Body

    var body: some View {
        SheetScaffold(title: String(localized: "Export"), subtitle: String(localized: "Share “\(project.title)” with the band, the studio, or the printer.")) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                summary
                group(String(localized: "For the band"), [.pdf, .chordText, .lyrics])
                group(String(localized: "For production"), [.studioMix, .midi, .takes])
                group(String(localized: "Keep a copy"), [.fullText, .projectFile])
            }
        }
        .presentationDetents([.large])
        .studioModalStyle()
        .onDisappear { mixTask?.cancel() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.urls)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .alert(
            "Couldn't export",
            isPresented: Binding(get: { failedFormat != nil }, set: { if !$0 { failedFormat = nil } }),
            presenting: failedFormat
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { format in
            Text("The \(format.title.lowercased()) file couldn't be created. Please try again.")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            LibraryFactsRow(project: project)
            if !sections.isEmpty {
                LibraryArrangementStrip(project: project, height: 5)
                Text("\(sections.count) sections · \(project.libraryTotalBars) bars")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }

    private func group(_ title: String, _ formats: [ExportFormat]) -> some View {
        LibraryFormGroup(title: title) {
            VStack(spacing: 0) {
                ForEach(Array(formats.enumerated()), id: \.element) { index, format in
                    if index > 0 { Hairline().padding(.leading, 64) }
                    row(format)
                }
            }
            .cardStyle()
        }
    }

    private func row(_ format: ExportFormat) -> some View {
        let available = isAvailable(format)
        return Button {
            export(format)
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
                        .fill(available ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.surfaceSecondary)
                        .frame(width: 40, height: 40)
                    Image(systemName: format.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(available ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textMuted)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(format.title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(available ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        Text(format.badge)
                            .font(DesignSystem.Typography.nano)
                            .tracking(0.8)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(DesignSystem.Colors.border, lineWidth: 1))
                    }
                    Text(description(for: format))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Group {
                    if working == format {
                        ProgressView()
                    } else if available {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
                .frame(width: 24)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available || working != nil)
        .accessibilityLabel("\(format.title), \(format.badge)")
        .accessibilityHint(description(for: format))
    }

    // MARK: Export

    private func export(_ format: ExportFormat) {
        HapticFeedback.light.trigger()
        working = format
        if format == .studioMix {
            exportMix()
            return
        }
        // Yield a frame so the spinner shows before synchronous file work.
        DispatchQueue.main.async {
            let urls = makeFiles(for: format)
            working = nil
            if urls.isEmpty {
                HapticFeedback.error.trigger()
                failedFormat = format
            } else {
                shareItem = ShareItem(urls: urls, type: format == .midi ? .midi : .text)
            }
        }
    }

    /// Renders the Studio arrangement offline (faster than realtime) through
    /// the same mix as playback, then shares the file.
    private func exportMix() {
        mixProgress = 0
        mixTask = Task { @MainActor in
            do {
                let url = try await StudioOfflineRenderer.render(project: project, format: .m4a) { value in
                    mixProgress = value
                }
                working = nil
                HapticFeedback.success.trigger()
                shareItem = ShareItem(urls: [url], type: .text)
            } catch is CancellationError {
                working = nil
            } catch {
                AppLog.general.error("Mix export failed: \(error.localizedDescription)")
                working = nil
                HapticFeedback.error.trigger()
                failedFormat = .studioMix
            }
        }
    }

    private var safeFileStem: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let stem = project.title
            .replacingOccurrences(of: " ", with: "_")
            .unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(stem))
        return result.isEmpty ? "Song" : result
    }

    private func makeFiles(for format: ExportFormat) -> [URL] {
        switch format {
        case .midi:
            return MIDIExporter().exportProject(project).map { [$0] } ?? []
        case .chordText:
            return TextExporter().exportChordChart(project).map { [$0] } ?? []
        case .fullText:
            return TextExporter().exportFullProject(project).map { [$0] } ?? []
        case .lyrics:
            return TextExporter().exportLyrics(project).map { [$0] } ?? []
        case .takes:
            return takeURLs
        case .pdf:
            let data = ChordChartPDFGenerator.generatePDF(for: project)
            return write(data, name: "\(safeFileStem)_chords.pdf")
        case .projectFile:
            guard let data = SuonoteProjectExchange.export(project: project) else { return [] }
            return write(data, name: "\(safeFileStem).suonote")
        case .studioMix:
            return []   // rendered asynchronously in exportMix()
        }
    }

    private func write(_ data: Data, name: String) -> [URL] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return [url]
        } catch {
            AppLog.general.error("Export write failed: \(error.localizedDescription)")
            return []
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
    let type: ExportType

    var url: URL? { urls.first }

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
        text += String(localized: "Key: \(project.keyRoot) \(project.keyMode.libraryDisplayName)") + "\n"
        text += String(localized: "Tempo: \(project.bpm) BPM") + "\n"
        text += String(localized: "Time: \(project.timeTop)/\(project.timeBottom)") + "\n\n"
        text += String(repeating: "=", count: 40) + "\n\n"
        
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            
            text += "[\(section.name)]\n"
            
            // Chords
            if !section.chordEvents.isEmpty {
                text += String(localized: "Chords:") + "\n"
                for bar in 0..<section.bars {
                    let barChords = section.chordEvents.filter { $0.barIndex == bar }
                        .sorted { $0.beatOffset < $1.beatOffset }
                    
                    if !barChords.isEmpty {
                        text += "  " + String(localized: "Bar \(bar + 1):") + " "
                        text += barChords.map { $0.display }.joined(separator: " - ")
                        text += "\n"
                    }
                }
            }
            
            // Lyrics
            if !section.lyricsText.isEmpty {
                text += "\n" + String(localized: "Lyrics:") + "\n"
                text += section.lyricsText + "\n"
            }
            
            text += "\n" + String(repeating: "-", count: 40) + "\n\n"
        }
        
        return saveToFile(text, fileName: "\(project.title)_ChordChart.txt")
    }
    
    /// Lyric sheet in arrangement order; sections without words are skipped.
    func exportLyrics(_ project: Project) -> URL? {
        var text = "\(project.title)\n\n"
        var wroteAny = false
        for item in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            guard let section = item.sectionTemplate else { continue }
            let lyrics = section.lyricsText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lyrics.isEmpty else { continue }
            text += "[\(item.labelOverride ?? section.name)]\n\(lyrics)\n\n"
            wroteAny = true
        }
        guard wroteAny else { return nil }
        return saveToFile(text, fileName: "\(project.title)_Lyrics.txt")
    }

    func exportFullProject(_ project: Project) -> URL? {
        var text = String(localized: "PROJECT: \(project.title)") + "\n\n"
        text += String(localized: "STATUS: \(project.status.libraryDisplayName)") + "\n"
        text += String(localized: "KEY: \(project.keyRoot) \(project.keyMode.libraryDisplayName)") + "\n"
        text += String(localized: "TEMPO: \(project.bpm) BPM") + "\n"
        text += String(localized: "TIME SIGNATURE: \(project.timeTop)/\(project.timeBottom)") + "\n"
        
        if !project.tags.isEmpty {
            text += String(localized: "TAGS: \(project.tags.joined(separator: ", "))") + "\n"
        }
        
        text += "\n" + String(localized: "CREATED: \(project.createdAt.formatted())") + "\n"
        text += String(localized: "UPDATED: \(project.updatedAt.formatted())") + "\n"
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"
        
        text += String(localized: "ARRANGEMENT") + "\n\n"
        for (index, item) in project.arrangementItems.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated() {
            guard let section = item.sectionTemplate else { continue }
            text += "\(index + 1). " + String(localized: "\(section.name) (\(section.bars) bars)") + "\n"
        }
        
        text += "\n" + String(repeating: "=", count: 60) + "\n\n"
        
        // Unique sections
        var seenSections = Set<UUID>()
        for item in project.arrangementItems {
            guard let section = item.sectionTemplate,
                  !seenSections.contains(section.id) else { continue }
            seenSections.insert(section.id)
            
            text += String(localized: "SECTION: \(section.name)") + "\n"
            text += String(localized: "Bars: \(section.bars)") + "\n\n"
            
            if !section.chordEvents.isEmpty {
                text += String(localized: "CHORDS:") + "\n"
                for bar in 0..<section.bars {
                    let barChords = section.chordEvents.filter { $0.barIndex == bar }
                        .sorted { $0.beatOffset < $1.beatOffset }
                    
                    if !barChords.isEmpty {
                        text += "  " + String(localized: "Bar \(bar + 1):") + " "
                        text += barChords.map { String(localized: "\($0.display) (beat \($0.beatOffset + 1), \($0.duration)b)") }
                            .joined(separator: ", ")
                        text += "\n"
                    }
                }
                text += "\n"
            }
            
            if !section.lyricsText.isEmpty {
                text += String(localized: "LYRICS:") + "\n\(section.lyricsText)\n\n"
            }
            
            text += String(repeating: "-", count: 60) + "\n\n"
        }
        
        if !project.recordings.isEmpty {
            text += String(localized: "RECORDINGS (\(project.recordings.count))") + "\n\n"
            for recording in project.recordings.sorted(by: { $0.createdAt > $1.createdAt }) {
                text += "- \(recording.name)\n"
                text += "  " + String(localized: "Duration: \(formatDuration(recording.duration))") + "\n"
                text += "  " + String(localized: "Created: \(recording.createdAt.formatted())") + "\n\n"
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
