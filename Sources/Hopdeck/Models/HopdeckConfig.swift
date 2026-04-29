import Foundation

struct HopdeckConfig: Codable, Hashable {
    var version: Int
    var hosts: [SSHHost]

    init(version: Int = 1, hosts: [SSHHost]) {
        self.version = version
        self.hosts = hosts
    }
}
