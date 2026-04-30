import XCTest
@testable import Hopdeck

final class StoreTests: XCTestCase {
    func testHostStoreRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        let store = HostStore(configURL: directory.appendingPathComponent("hosts.json"))
        let host = SSHHost.samples[0]

        try store.saveHosts([host])
        let loaded = try store.loadHosts()

        XCTAssertEqual(loaded, [host])
    }

    func testPasswordVaultRoundTripAndRemoval() throws {
        let directory = try makeTemporaryDirectory()
        let vault = PasswordVault(vaultURL: directory.appendingPathComponent("vault.json"))

        try vault.setItem(PasswordVaultItem(username: "app", password: "secret"), for: "password:app")

        XCTAssertEqual(try vault.password(for: "password:app"), "secret")

        try vault.removeItem(for: "password:app")

        XCTAssertNil(try vault.password(for: "password:app"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hopdeck-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
