import XCTest
@testable import Hopdeck

final class SSHCommandBuilderTests: XCTestCase {
    func testBuildsDirectCommand() throws {
        let host = SSHHost(
            id: "prod-app",
            alias: "prod-app",
            host: "10.0.1.20",
            user: "app",
            port: 2222,
            group: "Production",
            tags: [],
            jumpChain: [],
            auth: AuthConfig(type: .password, passwordRef: nil, autoLogin: false),
            notes: "",
            lastConnectedAt: nil
        )

        let command = try SSHCommandBuilder().buildCommand(for: host, allHosts: [host])

        XCTAssertEqual(command.command, "ssh 'app@10.0.1.20' -p 2222")
        XCTAssertEqual(command.jumpSpecs, [])
    }

    func testBuildsJumpCommandFromHopdeckHosts() throws {
        let jump = SSHHost.samples[0]
        let target = SSHHost.samples[1]

        let command = try SSHCommandBuilder().buildCommand(for: target, allHosts: [jump, target])

        XCTAssertEqual(command.jumpSpecs, ["zane@1.2.3.4:22"])
        XCTAssertEqual(command.command, "ssh -J 'zane@1.2.3.4:22' 'app@10.0.1.20' -p 22")
    }

    func testThrowsForMissingJumpHost() {
        let target = SSHHost.samples[1]

        XCTAssertThrowsError(try SSHCommandBuilder().buildCommand(for: target, allHosts: [target]))
    }
}
