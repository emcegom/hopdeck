import XCTest
@testable import Hopdeck

final class AutoLoginRunnerTests: XCTestCase {
    func testScriptContainsSequentialPasswordListWithoutRefs() {
        let credentials = [
            AutoLoginCredentials(passwordRef: "password:jump", password: "jump-secret"),
            AutoLoginCredentials(passwordRef: "password:target", password: "target-secret")
        ]

        let script = AutoLoginRunner().scriptSource(
            sshCommand: "ssh -J 'jump@1.2.3.4:22' 'app@10.0.1.20' -p 22",
            credentials: credentials
        )

        XCTAssertTrue(script.contains("set hopdeck_passwords [list \"jump-secret\" \"target-secret\"]"))
        XCTAssertTrue(script.contains("incr hopdeck_password_index"))
        XCTAssertFalse(script.contains("password:jump"))
        XCTAssertFalse(script.contains("password:target"))
    }
}
