import AppKit
import HopdeckNativeCore

final class HostInspectorView: NSView {
    private let host: SSHHost
    private let onConnect: () -> Void
    private let onSave: (SSHHost) -> Void
    private let onDelete: (UUID) -> Void
    private let onOpenSettings: () -> Void

    init(
        host: SSHHost,
        command: String,
        onConnect: @escaping () -> Void,
        onSave: @escaping (SSHHost) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.host = host
        self.onConnect = onConnect
        self.onSave = onSave
        self.onDelete = onDelete
        self.onOpenSettings = onOpenSettings
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        build(host: host, command: command)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(host: SSHHost, command: String) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 30, left: 34, bottom: 30, right: 34)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .top
        header.spacing = 18
        header.translatesAutoresizingMaskIntoConstraints = false

        let identity = NSStackView()
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 8

        let title = NSTextField(labelWithString: host.alias)
        title.font = .systemFont(ofSize: 30, weight: .bold)

        let address = NSTextField(labelWithString: host.displayAddress)
        address.font = .systemFont(ofSize: 15, weight: .medium)
        address.textColor = .secondaryLabelColor

        let tags = NSTextField(labelWithString: host.tags.isEmpty ? "No tags" : host.tags.joined(separator: "  "))
        tags.font = .systemFont(ofSize: 12, weight: .medium)
        tags.textColor = .tertiaryLabelColor

        let commandLabel = NSTextField(labelWithString: command)
        commandLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        commandLabel.textColor = .tertiaryLabelColor
        commandLabel.lineBreakMode = .byTruncatingMiddle

        identity.addArrangedSubview(title)
        identity.addArrangedSubview(address)
        identity.addArrangedSubview(tags)
        identity.addArrangedSubview(commandLabel)

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8

        let connect = NSButton(title: "Connect", target: self, action: #selector(connect))
        connect.bezelStyle = .rounded
        connect.keyEquivalent = "\r"

        let settings = NSButton(title: "Settings", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded
        let favorite = NSButton(
            title: host.tags.contains("favorite") ? "Unfavorite" : "Favorite",
            target: self,
            action: #selector(toggleFavorite)
        )
        favorite.bezelStyle = .rounded

        actions.addArrangedSubview(connect)
        actions.addArrangedSubview(favorite)
        actions.addArrangedSubview(settings)
        header.addArrangedSubview(identity)
        header.addArrangedSubview(actions)
        identity.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let panels = NSStackView()
        panels.orientation = .horizontal
        panels.alignment = .top
        panels.spacing = 16
        panels.translatesAutoresizingMaskIntoConstraints = false
        panels.addArrangedSubview(HostEditorPanelView(host: host, onSave: onSave, onDelete: onDelete))
        panels.addArrangedSubview(ConnectionDiagnosticsView(host: host, command: command))

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(panels)
        documentView.addSubview(stack)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),

            header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -68),
            panels.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -68),
            panels.arrangedSubviews[0].widthAnchor.constraint(equalTo: panels.arrangedSubviews[1].widthAnchor)
        ])
    }

    @objc private func connect() {
        onConnect()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func toggleFavorite() {
        var updated = host
        if updated.tags.contains("favorite") {
            updated.tags.removeAll { $0 == "favorite" }
        } else {
            updated.tags.append("favorite")
        }
        onSave(updated)
    }
}
