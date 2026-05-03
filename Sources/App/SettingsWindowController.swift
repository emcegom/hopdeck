import AppKit

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTabViewItem(Self.tab(title: "General", view: SettingsPanelView(rows: [
            ("Launch", "Open Hopdeck Native at login", .checkbox),
            ("Sidebar", "Show smart views and folders", .checkbox),
            ("Confirmations", "Ask before closing active sessions", .checkbox)
        ])))
        tabView.addTabViewItem(Self.tab(title: "Terminal", view: SettingsPanelView(rows: [
            ("Font", "SF Mono 13", .popup),
            ("Theme", "System", .popup),
            ("Option Key", "Use Option as Meta", .checkbox)
        ])))
        tabView.addTabViewItem(Self.tab(title: "SSH", view: SettingsPanelView(rows: [
            ("Known Hosts", "Strict host key checking", .popup),
            ("Agent", "Use SSH agent", .checkbox),
            ("Keep Alive", "30 seconds", .popup)
        ])))
        tabView.addTabViewItem(Self.tab(title: "Security", view: SettingsPanelView(rows: [
            ("Credentials", "Store secrets in Keychain", .checkbox),
            ("Clipboard", "Clear copied passwords after 30 seconds", .checkbox),
            ("Audit", "Record connection metadata only", .checkbox)
        ])))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = tabView
        window.center()
        self.init(window: window)
    }

    private static func tab(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }
}

private final class SettingsPanelView: NSView {
    enum ControlKind {
        case checkbox
        case popup
    }

    init(rows: [(String, String, ControlKind)]) {
        super.init(frame: .zero)
        build(rows: rows)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(rows: [(String, String, ControlKind)]) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for row in rows {
            stack.addArrangedSubview(settingRow(title: row.0, value: row.1, kind: row.2))
        }

        let note = NSTextField(labelWithString: "Settings UI skeleton only. Controls do not persist values yet.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(note)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    private func settingRow(title: String, value: String, kind: ControlKind) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let control: NSView
        switch kind {
        case .checkbox:
            let checkbox = NSButton(checkboxWithTitle: value, target: nil, action: nil)
            checkbox.state = .on
            checkbox.isEnabled = false
            control = checkbox
        case .popup:
            let popup = NSPopUpButton()
            popup.addItems(withTitles: [value])
            popup.isEnabled = false
            control = popup
        }

        let row = NSStackView(views: [titleField, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }
}
