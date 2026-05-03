import Foundation

public final class SettingsDocumentStore {
    public let documentURL: URL

    public init(documentURL: URL = SettingsDocumentStore.defaultDocumentURL()) {
        self.documentURL = documentURL
    }

    public static func defaultDocumentURL() -> URL {
        NativeDocumentPaths.documentURL(filename: "settings.json")
    }

    public func load() throws -> NativeSettingsDocument {
        try NativeJSONDocumentStore.load(from: documentURL, defaultDocument: NativeSettingsDocument())
    }

    public func save(_ document: NativeSettingsDocument) throws {
        try NativeJSONDocumentStore.save(document, to: documentURL)
    }
}
