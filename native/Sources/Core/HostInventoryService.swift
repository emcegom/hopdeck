import Foundation

public final class HostInventoryService {
    private let store: HostDocumentStore
    private var document: NativeHostDocument

    public private(set) var hosts: [SSHHost]

    public init(store: HostDocumentStore = HostDocumentStore()) {
        self.store = store
        let loadedDocument = (try? store.load()) ?? NativeHostDocument()
        if loadedDocument.hosts.isEmpty {
            self.document = NativeHostDocument(hosts: Self.sampleHosts)
            self.hosts = Self.sampleHosts
        } else {
            self.document = loadedDocument
            self.hosts = loadedDocument.hosts
        }
    }

    public func upsert(_ host: SSHHost) throws {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        document.hosts = hosts
        try store.save(document)
    }

    public func delete(hostID: UUID) throws {
        hosts.removeAll { $0.id == hostID }
        document.hosts = hosts
        document.folders = document.folders.map { folder in
            HostFolder(id: folder.id, name: folder.name, hostIDs: folder.hostIDs.filter { $0 != hostID })
        }
        try store.save(document)
    }

    public static let sampleHosts: [SSHHost] = [
        SSHHost(
            id: UUID(uuidString: "1D8F65CB-2143-48D7-AF3B-9606718243E1")!,
            alias: "132.33",
            address: "172.17.132.33",
            user: "edm",
            port: 22,
            jumpChain: [],
            tags: ["sample"]
        ),
        SSHHost(
            id: UUID(uuidString: "31561744-632A-4A51-A554-D8F68B8AF3EF")!,
            alias: "113.71",
            address: "172.17.113.71",
            user: "edm",
            port: 22,
            jumpChain: [],
            tags: ["sample"]
        )
    ]
}
