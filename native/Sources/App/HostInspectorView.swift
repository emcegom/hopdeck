import AppKit
import HopdeckNativeCore

final class HostInspectorView: NSView {
    private let onConnect: () -> Void

    init(host: SSHHost, command: String, onConnect: @escaping () -> Void) {
        self.onConnect = onConnect
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        build(host: host, command: command)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(host: SSHHost, command: String) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 34, left: 36, bottom: 34, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: host.alias)
        title.font = .systemFont(ofSize: 30, weight: .bold)

        let address = NSTextField(labelWithString: host.displayAddress)
        address.font = .systemFont(ofSize: 15, weight: .medium)
        address.textColor = .secondaryLabelColor

        let commandLabel = NSTextField(labelWithString: command)
        commandLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        commandLabel.textColor = .tertiaryLabelColor
        commandLabel.lineBreakMode = .byTruncatingMiddle

        let connect = NSButton(title: "Connect", target: self, action: #selector(connect))
        connect.bezelStyle = .rounded
        connect.keyEquivalent = "\r"

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(address)
        stack.addArrangedSubview(commandLabel)
        stack.addArrangedSubview(connect)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    @objc private func connect() {
        onConnect()
    }
}
