import Foundation
import AVFoundation

enum FileManagerUtils {
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
    
    /// Extract waveform samples from an audio file, returns normalized 0...1 values
    static func extractWaveform(from fileName: String, samples: Int = 50) -> [CGFloat] {
        guard let url = existingRecordingURL(for: fileName) else {
            return (0..<samples).map { _ in CGFloat.random(in: 0.1...0.5) }
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
            return (0..<samples).map { _ in CGFloat.random(in: 0.1...0.5) }
        }
    }
}
