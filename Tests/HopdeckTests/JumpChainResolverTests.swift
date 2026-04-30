import XCTest
@testable import Hopdeck

final class JumpChainResolverTests: XCTestCase {
    func testResolvesAliasesToJumpSpecs() throws {
        let jump = SSHHost.samples[0]

        let resolved = try JumpChainResolver().resolve(["jump-prod"], allHosts: [jump])

        XCTAssertEqual(resolved.aliases, ["jump-prod"])
        XCTAssertEqual(resolved.specs, ["zane@1.2.3.4:22"])
    }

    func testThrowsWhenJumpAliasIsMissing() {
        XCTAssertThrowsError(try JumpChainResolver().resolve(["missing"], allHosts: []))
    }
}
