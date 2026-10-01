#if DEBUG
import Foundation
import AVFoundation
import SwiftData

/// Fills the library with sample songs for App Store screenshots.
/// Debug builds only; run with the launch arguments
/// `-SeedScreenshotData YES -hasLaunchedBefore YES`.
///
/// "Golden Hour" gets a fixed id so screens can be opened by deep link:
/// `suonote://project/<goldenHourID>/studio`.
@MainActor
enum ScreenshotSeeder {
    static let goldenHourID = UUID(uuidString: "60D00000-0000-4000-8000-000000000001")!

    static func seedIfRequested(_ context: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: "SeedScreenshotData") else { return }

        for project in (try? context.fetch(FetchDescriptor<Project>())) ?? [] {
            context.delete(project)
        }

        song("Midnight Horizon", .idea, tags: ["Indie", "Pop"], key: "C", bpm: 120,
             starter: "aaba", ago: 86_400 * 3, in: context)
        song("Velvet Carousel", .finished, tags: ["Acoustic"], key: "A", bpm: 112, meter: 3,
             starter: "verse-chorus", ago: 86_400, in: context)
        song("Paper Planes", .polished, tags: ["Lo-fi"], key: "E", mode: .minor, bpm: 84,
             starter: "loop", ago: 86_400 * 6, in: context)
        song("Gravity Fades", .inProgress, tags: ["Alternative"], key: "D", mode: .minor, bpm: 76,
             starter: "pop", ago: 3_600 * 5, in: context)

        let demo = DemoSong.make(in: context, style: .pop)
        demo.id = goldenHourID
        demo.tags = ["Pop"]
        demo.updatedAt = .now.addingTimeInterval(-60 * 12)
        try? context.save()

        // A few takes with real waveforms: the band, the keys and the guitar.
        let takes: [(name: String, solo: StudioInstrument?, type: RecordingType)] = [
            (String(localized: "Chorus idea"), nil, .sketch),
            (String(localized: "Piano voicings"), .piano, .piano),
            (String(localized: "Guitar riff"), .guitar, .guitar),
        ]
        for take in takes {
            for track in demo.studioTracks { track.isSolo = track.instrument == take.solo }
            guard let rendered = try? await StudioOfflineRenderer.render(project: demo, format: .m4a) else { continue }
            let fileName = "screenshot-\(UUID().uuidString).m4a"
            let destination = FileManagerUtils.recordingURL(for: fileName)
            try? FileManager.default.removeItem(at: destination)
            guard (try? FileManager.default.copyItem(at: rendered, to: destination)) != nil else { continue }
            let duration = (try? AVAudioFile(forReading: destination)).map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0
            let recording = Recording(name: take.name, fileName: fileName, duration: duration,
                                      bpm: demo.bpm, recordingType: take.type)
            recording.project = demo
            demo.recordings.append(recording)
            context.insert(recording)
        }
        for track in demo.studioTracks { track.isSolo = false }
        demo.updatedAt = .now.addingTimeInterval(-60 * 12)
        try? context.save()
    }

    private static func song(
        _ title: String, _ status: ProjectStatus, tags: [String], key: String, mode: KeyMode = .major,
        bpm: Int, meter: Int = 4, starter: String, ago: TimeInterval, in context: ModelContext
    ) {
        let project = Project(title: title, status: status, tags: tags, keyRoot: key, keyMode: mode,
                              bpm: bpm, timeTop: meter, timeBottom: 4)
        context.insert(project)
        LibraryStarter.all.first { $0.id == starter }?.apply(to: project)
        project.updatedAt = .now.addingTimeInterval(-ago)
    }
}
#endif
