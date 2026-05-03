import Foundation

enum NativeDocumentPaths {
    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hopdeck", isDirectory: true)
    }

    static func documentURL(filename: String) -> URL {
        applicationSupportDirectory().appendingPathComponent(filename)
    }
}

enum NativeJSONDocumentStore {
    static func load<Document: Decodable>(from documentURL: URL, defaultDocument: @autoclosure () -> Document) throws -> Document {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return defaultDocument()
        }

        let data = try Data(contentsOf: documentURL)
        if data.isEmpty {
            return defaultDocument()
        }

        return try JSONDecoder().decode(Document.self, from: data)
    }

    static func save<Document: Encodable>(_ document: Document, to documentURL: URL) throws {
        let directory = documentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: documentURL, options: .atomic)
    }
}
