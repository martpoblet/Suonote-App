import Foundation

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
}
