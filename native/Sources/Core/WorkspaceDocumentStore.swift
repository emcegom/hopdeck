import Foundation

public final class WorkspaceDocumentStore {
    public let documentURL: URL

    public init(documentURL: URL = WorkspaceDocumentStore.defaultDocumentURL()) {
        self.documentURL = documentURL
    }

    public static func defaultDocumentURL() -> URL {
        NativeDocumentPaths.documentURL(filename: "workspaces.json")
    }

    public func load() throws -> NativeWorkspaceDocument {
        try NativeJSONDocumentStore.load(from: documentURL, defaultDocument: NativeWorkspaceDocument())
    }

    public func save(_ document: NativeWorkspaceDocument) throws {
        try NativeJSONDocumentStore.save(document, to: documentURL)
    }
}
