import Foundation
import AVFoundation
import os

/// Renders the Studio arrangement to an audio file faster than realtime,
/// through the exact same graph as playback (`StudioMixGraph`).
@MainActor
enum StudioOfflineRenderer {

    enum Format {
        case m4a
        case wav

        var fileExtension: String { self == .m4a ? "m4a" : "wav" }
    }

    enum RenderError: LocalizedError {
        case nothingToRender
        case engine(String)

        var errorDescription: String? {
            switch self {
            case .nothingToRender: return String(localized: "Add a Studio track before exporting audio.")
            case .engine(let message): return message
            }
        }
    }

    /// - Parameters:
    ///   - tail: seconds of release/reverb tail after the last bar.
    ///   - progress: 0…1, called on the main actor while rendering.
    static func render(
        project: Project,
        format: Format = .m4a,
        tail: Double = 2.5,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let tracks = project.studioTracks.sorted { $0.orderIndex < $1.orderIndex }
        guard !tracks.isEmpty else { throw RenderError.nothingToRender }

        let sampleRate = 44_100.0
        guard let renderFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw RenderError.engine(String(localized: "Unsupported render format."))
        }

        let engine = AVAudioEngine()
        do {
            try engine.enableManualRenderingMode(.offline, format: renderFormat, maximumFrameCount: 4096)
        } catch {
            throw RenderError.engine(String(localized: "Could not prepare the offline renderer."))
        }

        let graph = StudioMixGraph(engine: engine)
        graph.build(tracks: tracks, project: project, outputFormat: renderFormat)
        defer {
            engine.stop()
            graph.teardown()
        }

        do {
            try engine.start()
        } catch {
            throw RenderError.engine(String(localized: "Could not start the offline renderer."))
        }

        let beatScale = 4.0 / Double(max(1, project.timeBottom))
        let bpm = project.quarterNoteBpm()
        let sequencer = AVAudioSequencer(audioEngine: engine)
        graph.buildSequence(sequencer, tracks: tracks, beatScale: beatScale, beatsPerBar: project.timeTop)
        sequencer.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: bpm), at: 0)
        sequencer.prepareToPlay()

        // Audio tracks: schedule each recording at its start beat.
        let uiBeatSeconds = (60.0 / bpm) * beatScale
        for track in tracks where track.instrument.isAudio {
            guard let player = graph.chains[track.id]?.player,
                  let recordingId = track.audioRecordingId,
                  let recording = project.recordings.first(where: { $0.id == recordingId }),
                  let url = FileManagerUtils.existingRecordingURL(for: recording.fileName),
                  let file = try? AVAudioFile(forReading: url) else { continue }
            let startFrame = AVAudioFramePosition(max(0, track.audioStartBeat * uiBeatSeconds) * sampleRate)
            player.scheduleFile(file, at: AVAudioTime(sampleTime: startFrame, atRate: sampleRate), completionHandler: nil)
            player.play()
        }

        do {
            try sequencer.start()
        } catch {
            throw RenderError.engine(String(localized: "Could not start the sequencer."))
        }

        let bars = project.arrangementItems.compactMap { $0.sectionTemplate?.bars }.reduce(0, +)
        let songSeconds = Double(max(1, bars) * project.timeTop) * uiBeatSeconds
        let totalFrames = AVAudioFramePosition((songSeconds + tail) * sampleRate)

        let safeTitle = project.title
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle.isEmpty ? "Suonote" : safeTitle)_mix.\(format.fileExtension)")
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any]
        switch format {
        case .m4a:
            settings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 256_000
            ]
        case .wav:
            settings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        } catch {
            throw RenderError.engine(String(localized: "Could not create the audio file."))
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw RenderError.engine(String(localized: "Could not allocate the render buffer."))
        }

        var lastReported = -1.0
        while engine.manualRenderingSampleTime < totalFrames {
            try Task.checkCancellation()
            let remaining = totalFrames - engine.manualRenderingSampleTime
            let frames = min(AVAudioFrameCount(remaining), buffer.frameCapacity)
            let status: AVAudioEngineManualRenderingStatus
            do {
                status = try engine.renderOffline(frames, to: buffer)
            } catch {
                throw RenderError.engine(String(localized: "Rendering failed."))
            }
            switch status {
            case .success:
                try file.write(from: buffer)
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                continue
            case .error:
                throw RenderError.engine(String(localized: "Rendering failed."))
            @unknown default:
                throw RenderError.engine(String(localized: "Rendering failed."))
            }

            let fraction = Double(engine.manualRenderingSampleTime) / Double(totalFrames)
            if fraction - lastReported >= 0.02 {
                lastReported = fraction
                progress?(min(1, fraction))
                // Let the UI breathe between chunks.
                await Task.yield()
            }
        }
        sequencer.stop()
        progress?(1)
        AppLog.studio.info("Rendered mix to \(url.lastPathComponent)")
        return url
    }
}
