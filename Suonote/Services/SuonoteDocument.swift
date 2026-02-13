import SwiftUI
import UniformTypeIdentifiers

/// Suonote document type for sharing via AirDrop and Files app (F-09)
/// Uses .suonote extension backed by JSON (SuonoteProjectExchange)

extension UTType {
    static var suonoteProject: UTType {
        UTType(exportedAs: "com.suonote.project", conformingTo: .json)
    }
}

/// Document wrapper for sharing projects
struct SuonoteDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.suonoteProject, .json]
    static var writableContentTypes: [UTType] = [.suonoteProject]
    
    var projectData: Data
    
    init(projectData: Data) {
        self.projectData = projectData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.projectData = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: projectData)
    }
}

/// Share sheet for exporting .suonote files
struct ProjectShareView: View {
    let project: Project
    @State private var showingExporter = false
    @State private var document: SuonoteDocument?
    
    var body: some View {
        Button {
            if let data = SuonoteProjectExchange.export(project: project) {
                document = SuonoteDocument(projectData: data)
                showingExporter = true
            }
        } label: {
            Label("Share Project", systemImage: "square.and.arrow.up")
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: document,
            contentType: .suonoteProject,
            defaultFilename: "\(project.title).suonote"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}
