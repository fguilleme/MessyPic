import Foundation

struct AnalysisCache {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MessyPic", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("photo-analysis.json")
    }

    func load() -> [PhotoAnalysis] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PhotoAnalysis].self, from: data)) ?? []
    }

    func save(_ analyses: [PhotoAnalysis]) {
        guard let data = try? JSONEncoder().encode(analyses) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
