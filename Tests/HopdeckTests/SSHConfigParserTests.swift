import XCTest
@testable import Hopdeck

final class SSHConfigParserTests: XCTestCase {
    func testParsesBasicHostsAndProxyJump() {
        let text = """
        Host jump-prod
          HostName 1.2.3.4
          User zane
          Port 2222

        Host prod-app
          HostName 10.0.1.20
          User app
          ProxyJump jump-prod

        Host *
          ServerAliveInterval 30
        """

        let hosts = SSHConfigParser().parse(text)

        XCTAssertEqual(hosts.map(\.alias), ["jump-prod", "prod-app"])
        XCTAssertEqual(hosts[0].host, "1.2.3.4")
        XCTAssertEqual(hosts[0].user, "zane")
        XCTAssertEqual(hosts[0].port, 2222)
        XCTAssertEqual(hosts[1].jumpChain, ["jump-prod"])
    }
}
