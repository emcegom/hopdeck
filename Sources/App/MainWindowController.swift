import AppKit
import HopdeckNativeCore
final class MainWindowController: NSWindowController {
    private let inventory = HostInventoryService()
    private let sessionManager = SessionManager()
    private let splitView = NSSplitView()
    private let sidebarController = SidebarController()
    private let workspaceController = WorkspaceController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Hopdeck Native"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.center()
        self.init(window: window)
        configureWindow()
    }

    private func configureWindow() {
        sessionManager.delegate = self
        configureToolbar()
        configureSplitView()
        reloadHosts()
        sidebarController.onSelectHost = { [weak self] host in
            self?.showHost(host)
        }
        sidebarController.onConnectHost = { [weak self] host in
            self?.connect(to: .ssh(host))
        }
        workspaceController.onStartLocalShell = { [weak self] in
            self?.connect(to: .localShell)
        }
        workspaceController.onSelectSession = { [weak self] sessionID in
            self?.sessionManager.activate(sessionID: sessionID)
        }
        workspaceController.onSendInput = { [weak self] sessionID, data in
            self?.sessionManager.send(data, to: sessionID)
        }
        workspaceController.onResizeSession = { [weak self] sessionID, size in
            self?.sessionManager.resize(sessionID: sessionID, to: size)
        }
        workspaceController.showWelcome()
    }

    private func configureSplitView() {
        guard let contentView = window?.contentView else {
            return
        }
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        splitView.addArrangedSubview(sidebarController.view)
        splitView.addArrangedSubview(workspaceController.view)
        sidebarController.view.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: "HopdeckNativeToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        window?.toolbar = toolbar
    }

    private func reloadHosts() {
        sidebarController.hosts = inventory.hosts
    }

    private func showHost(_ host: SSHHost) {
        workspaceController.showHostInspector(
            host: host,
            command: sessionManager.displayCommand(for: .ssh(host)),
            onConnect: { [weak self] in
                self?.connect(to: .ssh(host))
            },
            onSave: { [weak self] updatedHost in
                self?.save(host: updatedHost)
            },
            onDelete: { [weak self] hostID in
                self?.deleteHost(hostID: hostID)
            }
        )
    }

    private func save(host: SSHHost) {
        do {
            try inventory.upsert(host)
            reloadHosts()
            showHost(host)
        } catch {
            present(error: error)
        }
    }

    private func deleteHost(hostID: UUID) {
        do {
            try inventory.delete(hostID: hostID)
            reloadHosts()
            workspaceController.showWelcome()
        } catch {
            present(error: error)
        }
    }

    private func present(error: Error) {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window ?? NSWindow())
    }

    private func connect(to target: ConnectionTarget) {
        let session = sessionManager.createSession(target: target)
        workspaceController.startSession(session: session)
        sessionManager.startProcess(
            sessionID: session.id,
            command: sessionManager.processCommand(for: target),
            initialSize: workspaceController.terminalSize(for: session.id)
        )
    }

    func closeActiveSession() {
        guard let closePlan = sessionManager.closeActiveSession() else {
            window?.performClose(nil)
            return
        }

        if let closedSessionID = closePlan.closedSessionID {
            workspaceController.detachSession(sessionID: closedSessionID)
        }

        if let nextActiveSessionID = closePlan.nextActiveSessionID {
            workspaceController.showSession(sessionID: nextActiveSessionID)
        } else if closePlan.shouldCloseWindow {
            workspaceController.showWelcome()
            window?.performClose(nil)
        } else {
            workspaceController.showWelcome()
        }
    }
}

@MainActor
extension MainWindowController: SessionManagerDelegate {
    func sessionManagerDidUpdateSessions(_ manager: SessionManager) {
        workspaceController.updateSessions(manager.sessions, activeSessionID: manager.activeSessionID)
    }

    func sessionManager(_ manager: SessionManager, didReceive bytes: ArraySlice<UInt8>, for sessionID: UUID) {
        workspaceController.feed(bytes, to: sessionID)
    }
}

extension MainWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .init("NewHost"), .flexibleSpace, .init("NewLocalShell")]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .init("NewHost"), .flexibleSpace, .init("NewLocalShell")]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .init("NewHost") {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Host"
            item.paletteLabel = "New Host"
            item.toolTip = "Create a new SSH host"
            item.image = NSImage(systemSymbolName: "plus.rectangle.on.rectangle", accessibilityDescription: "New Host")
            item.target = self
            item.action = #selector(newHost)
            return item
        }

        if itemIdentifier == .init("NewLocalShell") {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Local"
            item.paletteLabel = "Open Local Shell"
            item.toolTip = "Open a local shell session"
            item.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Open Local Shell")
            item.target = self
            item.action = #selector(openLocalShell)
            return item
        }
        return nil
    }

    @objc private func openLocalShell() {
        connect(to: .localShell)
    }

    @objc private func newHost() {
        let host = SSHHost(
            id: UUID(),
            alias: "New Host",
            address: "",
            user: NSUserName(),
            port: 22,
            jumpChain: [],
            tags: []
        )
        showHost(host)
    }
}
