import Foundation
import AVFoundation

// Pure file I/O with no UI state; safe to call from any actor
// (the module default isolation is MainActor).
nonisolated enum FileManagerUtils {
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func recordingURL(for fileName: String) -> URL {
        getDocumentsDirectory().appendingPathComponent(fileName)
    }

    static func existingRecordingURL(for fileName: String) -> URL? {
        let candidates = [
            getDocumentsDirectory().appendingPathComponent(fileName),
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName),
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
        ]
        return candidates.first(where: { fileExists(at: $0) })
    }

    /// True when the audio file for a recording exists on this device.
    /// Recording metadata syncs through iCloud but the audio files do not, so a
    /// take recorded on another device has no local file.
    static func audioFileExists(fileName: String) -> Bool {
        existingRecordingURL(for: fileName) != nil
    }

    /// Extract waveform samples from an audio file, returns normalized 0...1 values.
    /// Returns an empty array when the file is missing or unreadable — never
    /// fabricated data. Callers draw a flat placeholder for an empty result.
    static func extractWaveform(from fileName: String, samples: Int = 50) -> [CGFloat] {
        guard let url = existingRecordingURL(for: fileName) else {
            return []
        }
        
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return Array(repeating: 0.3, count: samples)
            }
            
            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else {
                return Array(repeating: 0.3, count: samples)
            }
            
            let framesPerSample = max(1, Int(frameCount) / samples)
            var waveform: [CGFloat] = []
            
            for i in 0..<samples {
                let start = i * framesPerSample
                let end = min(start + framesPerSample, Int(frameCount))
                var maxAmplitude: Float = 0
                for j in start..<end {
                    maxAmplitude = max(maxAmplitude, abs(channelData[j]))
                }
                waveform.append(CGFloat(maxAmplitude))
            }
            
            // Normalize to 0...1
            let peak = waveform.max() ?? 1
            if peak > 0 {
                waveform = waveform.map { $0 / peak }
            }
            
            return waveform
        } catch {
            return []
        }
    }
}
