import Foundation

@MainActor
public protocol SessionManagerDelegate: AnyObject {
    func sessionManagerDidUpdateSessions(_ manager: SessionManager)
}

@MainActor
public final class SessionManager {
    public struct ClosePlan: Equatable {
        public let closedSessionID: UUID?
        public let nextActiveSessionID: UUID?
        public let shouldCloseWindow: Bool
    }

    public weak var delegate: SessionManagerDelegate?

    private let commandBuilder = OpenSSHCommandBuilder()
    public private(set) var sessions: [TerminalSession] = []
    public private(set) var activeSessionID: UUID?

    public init() {}

    public func createSession(target: ConnectionTarget) -> TerminalSession {
        let title: String
        let host: SSHHost?

        switch target {
        case .localShell:
            title = "Local"
            host = nil
        case .ssh(let selectedHost):
            title = selectedHost.alias
            host = selectedHost
        }

        let session = TerminalSession(id: UUID(), host: host, title: title, state: .idle)
        sessions.append(session)
        activeSessionID = session.id
        delegate?.sessionManagerDidUpdateSessions(self)
        return session
    }

    public func command(for target: ConnectionTarget) -> (
        executable: String,
        arguments: [String],
        execName: String?,
        currentDirectory: String
    ) {
        commandBuilder.build(target: target)
    }

    public func displayCommand(for target: ConnectionTarget) -> String {
        commandBuilder.displayCommand(for: target)
    }

    public func activate(sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }
        activeSessionID = sessionID
        delegate?.sessionManagerDidUpdateSessions(self)
    }

    public func markRunning(sessionID: UUID) {
        update(sessionID: sessionID) { $0.state = .running }
    }

    public func markExited(sessionID: UUID, exitCode: Int32?) {
        update(sessionID: sessionID) { $0.state = .exited(exitCode) }
    }

    public func closeActiveSession() -> ClosePlan? {
        guard let sessionID = activeSessionID else {
            return ClosePlan(closedSessionID: nil, nextActiveSessionID: nil, shouldCloseWindow: true)
        }

        update(sessionID: sessionID) { $0.state = .closing }
        sessions.removeAll { $0.id == sessionID }
        activeSessionID = sessions.last?.id
        delegate?.sessionManagerDidUpdateSessions(self)
        return ClosePlan(
            closedSessionID: sessionID,
            nextActiveSessionID: activeSessionID,
            shouldCloseWindow: false
        )
    }

    private func update(sessionID: UUID, _ mutate: (inout TerminalSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }
        mutate(&sessions[index])
        delegate?.sessionManagerDidUpdateSessions(self)
    }
}
