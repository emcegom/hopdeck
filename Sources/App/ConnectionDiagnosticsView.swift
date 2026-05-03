import AppKit
import HopdeckNativeCore

final class ConnectionDiagnosticsView: NSView {
    private let host: SSHHost
    private let command: String
    private let rowsStack = NSStackView()

    init(host: SSHHost, command: String) {
        self.host = host
        self.command = command
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build(report: ConnectionDiagnosticsService().staticReport(for: host), command: command)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(report: ConnectionDiagnosticsReport, command: String) {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Connection Diagnostics")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 10
        render(report: report, command: command)

        let run = NSButton(title: "Run Diagnostics", target: self, action: #selector(runDiagnostics))
        run.bezelStyle = .rounded

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(rowsStack)
        stack.addArrangedSubview(run)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func render(report: ConnectionDiagnosticsReport, command: String) {
        rowsStack.arrangedSubviews.forEach { view in
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        report.diagnostics.map { diagnostic in
            diagnosticRow(
                symbol: symbol(for: diagnostic.title),
                title: diagnostic.title,
                detail: diagnostic.title == "Command" ? command : diagnostic.detail,
                state: diagnostic.state.rawValue
            )
        }.forEach { rowsStack.addArrangedSubview($0) }
    }

    private func diagnosticRow(symbol: String, title: String, detail: String, state: String) -> NSView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        image.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        image.contentTintColor = .secondaryLabelColor
        image.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 12, weight: .medium)
        let detailField = NSTextField(labelWithString: detail)
        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingMiddle

        let text = NSStackView(views: [titleField, detailField])
        text.orientation = .vertical
        text.spacing = 2

        let badge = NSTextField(labelWithString: state)
        badge.font = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor = .tertiaryLabelColor

        let row = NSStackView(views: [image, text, badge])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 18),
            image.heightAnchor.constraint(equalToConstant: 18)
        ])

        return row
    }

    @objc private func runDiagnostics() {
        render(report: ConnectionDiagnosticsService().runLocalReport(for: host), command: command)
    }

    private func symbol(for title: String) -> String {
        switch title {
        case "Target":
            return "network"
        case "Credential":
            return "key.horizontal"
        case "Jump Chain":
            return "point.3.connected.trianglepath.dotted"
        case "Command":
            return "terminal"
        default:
            return "checkmark.circle"
        }
    }
}
