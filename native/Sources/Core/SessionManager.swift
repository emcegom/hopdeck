import Foundation

@MainActor
public protocol SessionManagerDelegate: AnyObject {
    func sessionManagerDidUpdateSessions(_ manager: SessionManager)
    func sessionManager(_ manager: SessionManager, didReceive bytes: ArraySlice<UInt8>, for sessionID: UUID)
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
    private var processes: [UUID: TerminalProcessAdapter] = [:]

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

    public func processCommand(for target: ConnectionTarget) -> TerminalProcessCommand {
        commandBuilder.processCommand(for: target)
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
            return ClosePlan(closedSessionID: nil, nextActiveSessionID: nil, shouldCloseWindow: false)
        }

        update(sessionID: sessionID) { $0.state = .closing }
        processes.removeValue(forKey: sessionID)?.terminate()
        sessions.removeAll { $0.id == sessionID }
        activeSessionID = sessions.last?.id
        delegate?.sessionManagerDidUpdateSessions(self)
        return ClosePlan(
            closedSessionID: sessionID,
            nextActiveSessionID: activeSessionID,
            shouldCloseWindow: false
        )
    }

    public func startProcess(sessionID: UUID, command: TerminalProcessCommand, initialSize: TerminalProcessSize) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }
        let adapter = TerminalProcessAdapter(sessionID: sessionID, initialSize: initialSize)
        adapter.delegate = self
        processes[sessionID] = adapter
        adapter.start(command: command)
        markRunning(sessionID: sessionID)
    }

    public func send(_ bytes: ArraySlice<UInt8>, to sessionID: UUID) {
        processes[sessionID]?.send(bytes)
    }

    public func resize(sessionID: UUID, to size: TerminalProcessSize) {
        processes[sessionID]?.resize(to: size)
    }

    private func update(sessionID: UUID, _ mutate: (inout TerminalSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }
        mutate(&sessions[index])
        delegate?.sessionManagerDidUpdateSessions(self)
    }
}

extension SessionManager: TerminalProcessAdapterDelegate {
    public nonisolated func terminalProcessAdapter(_ adapter: TerminalProcessAdapter, didReceive bytes: ArraySlice<UInt8>) {
        let sessionID = adapter.sessionID
        let copiedBytes = Array(bytes)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            self.delegate?.sessionManager(self, didReceive: copiedBytes[...], for: sessionID)
        }
    }

    public nonisolated func terminalProcessAdapter(_ adapter: TerminalProcessAdapter, didExitWith exitCode: Int32?) {
        let sessionID = adapter.sessionID
        Task { @MainActor [weak self] in
            self?.processes[sessionID] = nil
            self?.markExited(sessionID: sessionID, exitCode: exitCode)
        }
    }
}
