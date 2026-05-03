import Foundation

public final class HostInventoryService {
    public private(set) var hosts: [SSHHost] = [
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

    public init() {}
}
