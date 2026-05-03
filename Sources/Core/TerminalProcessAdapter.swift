import Foundation
import SwiftTerm

public struct TerminalProcessCommand: Equatable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String]?
    public let execName: String?
    public let currentDirectory: String

    public init(
        executable: String,
        arguments: [String],
        environment: [String]? = nil,
        execName: String?,
        currentDirectory: String
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.execName = execName
        self.currentDirectory = currentDirectory
    }
}

public struct TerminalProcessSize: Equatable {
    public var columns: Int
    public var rows: Int
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(columns: Int, rows: Int, pixelWidth: Int = 0, pixelHeight: Int = 0) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
        self.pixelWidth = max(pixelWidth, 0)
        self.pixelHeight = max(pixelHeight, 0)
    }
}

public protocol TerminalProcessAdapterDelegate: AnyObject {
    func terminalProcessAdapter(_ adapter: TerminalProcessAdapter, didReceive bytes: ArraySlice<UInt8>)
    func terminalProcessAdapter(_ adapter: TerminalProcessAdapter, didExitWith exitCode: Int32?)
}

public final class TerminalProcessAdapter {
    public let sessionID: UUID
    public weak var delegate: TerminalProcessAdapterDelegate?

    private var process: LocalProcess?
    private var currentSize: TerminalProcessSize

    public init(sessionID: UUID, initialSize: TerminalProcessSize = TerminalProcessSize(columns: 100, rows: 30)) {
        self.sessionID = sessionID
        self.currentSize = initialSize
    }

    public var isRunning: Bool {
        process?.running == true
    }

    public func start(command: TerminalProcessCommand) {
        guard process == nil else {
            return
        }

        let localProcess = LocalProcess(delegate: self)
        process = localProcess
        localProcess.startProcess(
            executable: command.executable,
            args: command.arguments,
            environment: command.environment,
            execName: command.execName,
            currentDirectory: command.currentDirectory
        )
        resize(to: currentSize)
    }

    public func send(_ bytes: ArraySlice<UInt8>) {
        process?.send(data: bytes)
    }

    public func resize(to size: TerminalProcessSize) {
        currentSize = size
        guard let process, process.running, process.childfd >= 0 else {
            return
        }
        var windowSize = getWindowSize()
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &windowSize)
    }

    public func terminate() {
        process?.terminate()
    }
}

extension TerminalProcessAdapter: LocalProcessDelegate {
    public func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        delegate?.terminalProcessAdapter(self, didExitWith: exitCode)
    }

    public func dataReceived(slice: ArraySlice<UInt8>) {
        delegate?.terminalProcessAdapter(self, didReceive: slice)
    }

    public func getWindowSize() -> winsize {
        winsize(
            ws_row: UInt16(currentSize.rows),
            ws_col: UInt16(currentSize.columns),
            ws_xpixel: UInt16(currentSize.pixelWidth),
            ws_ypixel: UInt16(currentSize.pixelHeight)
        )
    }
}
