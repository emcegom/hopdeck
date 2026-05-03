import AppKit
import HopdeckNativeCore

final class HostEditorPanelView: NSView {
    private let modeControl = NSSegmentedControl(labels: ["Add", "Edit", "Clone", "Delete"], trackingMode: .selectOne, target: nil, action: nil)
    private let host: SSHHost
    private let onSave: (SSHHost) -> Void
    private let onDelete: (UUID) -> Void
    private let aliasField = NSTextField()
    private let addressField = NSTextField()
    private let userField = NSTextField()
    private let portField = NSTextField()
    private let tagsField = NSTextField()

    init(host: SSHHost, onSave: @escaping (SSHHost) -> Void, onDelete: @escaping (UUID) -> Void) {
        self.host = host
        self.onSave = onSave
        self.onDelete = onDelete
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build(host: host)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(host: SSHHost) {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Host CRUD")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        modeControl.selectedSegment = 1
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        let grid = NSGridView(views: [
            [label("Alias"), configuredField(aliasField, value: host.alias)],
            [label("Address"), configuredField(addressField, value: host.address)],
            [label("User"), configuredField(userField, value: host.user)],
            [label("Port"), configuredField(portField, value: String(host.port))],
            [label("Tags"), configuredField(tagsField, value: host.tags.joined(separator: ", "))]
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 260
        grid.rowSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false

        let note = NSTextField(labelWithString: "Changes are saved to Hopdeck's native hosts.json document.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 11)
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 2

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(button("Save", action: #selector(saveHost), enabled: true))
        buttons.addArrangedSubview(button("Clone", action: #selector(cloneHost), enabled: true))
        buttons.addArrangedSubview(button("Delete", action: #selector(deleteHost), enabled: true))

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(modeControl)
        stack.addArrangedSubview(grid)
        stack.addArrangedSubview(note)
        stack.addArrangedSubview(buttons)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    private func label(_ value: String) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func configuredField(_ field: NSTextField, value: String) -> NSTextField {
        field.stringValue = value
        field.isEditable = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        return field
    }

    private func button(_ title: String, action: Selector, enabled: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.isEnabled = enabled
        return button
    }

    private func draft(id: UUID) -> SSHHost {
        SSHHost(
            id: id,
            alias: aliasField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Host" : aliasField.stringValue,
            address: addressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            user: userField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSUserName() : userField.stringValue,
            port: Int(portField.stringValue) ?? 22,
            jumpChain: host.jumpChain,
            tags: tagsField.stringValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            credential: host.credential
        )
    }

    @objc private func saveHost() {
        onSave(draft(id: host.id))
    }

    @objc private func cloneHost() {
        var cloned = draft(id: UUID())
        cloned.alias = "\(cloned.alias) Copy"
        onSave(cloned)
    }

    @objc private func deleteHost() {
        onDelete(host.id)
    }
}
