import AppKit
import HopdeckNativeCore
import SwiftTerm

final class WorkspaceController: NSViewController {
    var onStartLocalShell: (() -> Void)?
    var onSelectSession: ((UUID) -> Void)?
    var onSendInput: ((UUID, ArraySlice<UInt8>) -> Void)?
    var onResizeSession: ((UUID, TerminalProcessSize) -> Void)?

    private let container = NSView()
    private let tabControl = NSSegmentedControl()
    private let content = NSView()
    private var terminalViews: [UUID: TerminalView] = [:]
    private var sessions: [TerminalSession] = []
    private var activeSessionID: UUID?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        configureLayout()
    }

    func showWelcome() {
        clearContent()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Hopdeck Native")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        let note = NSTextField(labelWithString: "Swift/AppKit + SwiftTerm spike. Start a local shell or select a host.")
        note.textColor = .secondaryLabelColor
        let button = NSButton(title: "Open Local Shell", target: self, action: #selector(startLocalShell))
        button.bezelStyle = .rounded

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(note)
        stack.addArrangedSubview(button)
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])
    }

    func showHostInspector(
        host: SSHHost,
        command: String,
        onConnect: @escaping () -> Void,
        onSave: @escaping (SSHHost) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        clearContent()
        let inspector = HostInspectorView(
            host: host,
            command: command,
            onConnect: onConnect,
            onSave: onSave,
            onDelete: onDelete
        )
        inspector.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(inspector)

        NSLayoutConstraint.activate([
            inspector.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            inspector.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            inspector.topAnchor.constraint(equalTo: content.topAnchor),
            inspector.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    func startSession(session: TerminalSession) {
        clearContent()

        let terminalView = TerminalView(frame: content.bounds)
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.terminalDelegate = self
        terminalView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.nativeForegroundColor = .textColor
        terminalView.nativeBackgroundColor = .textBackgroundColor
        terminalView.caretColor = .controlAccentColor
        terminalView.allowMouseReporting = true
        terminalView.optionAsMetaKey = true
        terminalView.identifier = NSUserInterfaceItemIdentifier(session.id.uuidString)

        content.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: content.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        terminalViews[session.id] = terminalView
        activeSessionID = session.id
        _ = terminalView.becomeFirstResponder()
    }

    func updateSessions(_ sessions: [TerminalSession], activeSessionID: UUID?) {
        self.sessions = sessions
        self.activeSessionID = activeSessionID
        tabControl.segmentCount = sessions.count
        for (index, session) in sessions.enumerated() {
            tabControl.setLabel(session.title, forSegment: index)
            tabControl.setWidth(120, forSegment: index)
            if session.id == activeSessionID {
                tabControl.selectedSegment = index
            }
        }
        tabControl.isHidden = sessions.isEmpty
    }

    func detachSession(sessionID: UUID) {
        terminalViews[sessionID]?.removeFromSuperview()
        terminalViews[sessionID] = nil
        self.activeSessionID = nil
        clearContent()
    }

    func feed(_ bytes: ArraySlice<UInt8>, to sessionID: UUID) {
        terminalViews[sessionID]?.feed(byteArray: bytes)
    }

    func terminalSize(for sessionID: UUID) -> TerminalProcessSize {
        guard let terminalView = terminalViews[sessionID] else {
            return TerminalProcessSize(columns: 100, rows: 30)
        }
        return TerminalProcessSize(
            columns: terminalView.getTerminal().cols,
            rows: terminalView.getTerminal().rows,
            pixelWidth: Int(terminalView.frame.width),
            pixelHeight: Int(terminalView.frame.height)
        )
    }

    func showSession(sessionID: UUID) {
        guard let terminalView = terminalViews[sessionID] else {
            return
        }
        clearContent()
        content.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: content.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        activeSessionID = sessionID
        _ = terminalView.becomeFirstResponder()
    }

    private func configureLayout() {
        container.translatesAutoresizingMaskIntoConstraints = false
        tabControl.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        tabControl.target = self
        tabControl.action = #selector(selectTab)

        view.addSubview(container)
        container.addSubview(tabControl)
        container.addSubview(content)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tabControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            tabControl.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
            tabControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            tabControl.heightAnchor.constraint(equalToConstant: 28),

            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func clearContent() {
        content.subviews.forEach { $0.removeFromSuperview() }
    }

    @objc private func startLocalShell() {
        onStartLocalShell?()
    }

    @objc private func selectTab() {
        let index = tabControl.selectedSegment
        guard sessions.indices.contains(index) else {
            return
        }
        let session = sessions[index]
        guard let terminalView = terminalViews[session.id] else {
            return
        }
        clearContent()
        content.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: content.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        activeSessionID = session.id
        onSelectSession?(session.id)
        _ = terminalView.becomeFirstResponder()
    }
}

extension WorkspaceController: @preconcurrency TerminalViewDelegate {
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        guard let idString = source.identifier?.rawValue, let sessionID = UUID(uuidString: idString) else {
            return
        }
        onSendInput?(sessionID, data)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard let idString = source.identifier?.rawValue, let sessionID = UUID(uuidString: idString) else {
            return
        }
        let size = TerminalProcessSize(
            columns: newCols,
            rows: newRows,
            pixelWidth: Int(source.frame.width),
            pixelHeight: Int(source.frame.height)
        )
        onResizeSession?(sessionID, size)
    }

    func setTerminalTitle(source: TerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func scrolled(source: TerminalView, position: Double) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        guard let url = URL(string: link) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func bell(source: TerminalView) {
        NSSound.beep()
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        guard let string = String(data: content, encoding: .utf8) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}
