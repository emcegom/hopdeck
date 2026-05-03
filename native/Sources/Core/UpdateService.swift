import Foundation

public enum ReleaseStepState: String, Codable, Equatable, Sendable {
    case notStarted
    case ready
    case blocked
}

public struct ReleaseStep: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var state: ReleaseStepState

    public init(id: UUID = UUID(), title: String, detail: String, state: ReleaseStepState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct ReleaseReadinessReport: Codable, Equatable, Sendable {
    public var version: String
    public var steps: [ReleaseStep]

    public init(version: String, steps: [ReleaseStep]) {
        self.version = version
        self.steps = steps
    }

    public var isReleaseReady: Bool {
        steps.allSatisfy { $0.state == .ready }
    }
}

public struct UpdateService {
    public init() {}

    public func localSpikeReport(version: String = "0.1.0") -> ReleaseReadinessReport {
        ReleaseReadinessReport(
            version: version,
            steps: [
                ReleaseStep(title: "Swift build", detail: "Debug build and local app bundle are available.", state: .ready),
                ReleaseStep(title: "Ad-hoc signing", detail: "Local validation bundle can be ad-hoc signed.", state: .ready),
                ReleaseStep(title: "Developer ID", detail: "Requires Apple Developer certificate and Xcode archive.", state: .blocked),
                ReleaseStep(title: "Notarization", detail: "Requires notarytool credentials and hardened runtime.", state: .blocked),
                ReleaseStep(title: "Sparkle appcast", detail: "Requires Sparkle 2 integration and release signing key.", state: .blocked),
                ReleaseStep(title: "GitHub Release", detail: "Requires signed/notarized archive artifact.", state: .blocked)
            ]
        )
    }
}
