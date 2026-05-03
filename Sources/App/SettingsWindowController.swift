import AppKit
import HopdeckNativeCore

final class SettingsWindowController: NSWindowController {
    private var settings: NativeSettingsDocument
    private let onSave: (NativeSettingsDocument) -> Void

    private let themePopup = NSPopUpButton()
    private let fontSizeStepper = NSStepper()
    private let fontSizeLabel = NSTextField(labelWithString: "")
    private let autoLoginCheckbox = NSButton(checkboxWithTitle: "Auto-login when a credential is available", target: nil, action: nil)
    private let closeOnDisconnectCheckbox = NSButton(checkboxWithTitle: "Close tab on clean disconnect", target: nil, action: nil)
    private let clipboardStepper = NSStepper()
    private let clipboardLabel = NSTextField(labelWithString: "")

    init(settings: NativeSettingsDocument, onSave: @escaping (NativeSettingsDocument) -> Void) {
        self.settings = settings
        self.onSave = onSave

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = content
        window.center()
        super.init(window: window)
        build(in: content)
        syncControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(in content: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        themePopup.addItems(withTitles: NativeThemeMode.allCases.map(\.rawValue.capitalized))
        themePopup.target = self
        themePopup.action = #selector(themeChanged)

        fontSizeStepper.minValue = 10
        fontSizeStepper.maxValue = 24
        fontSizeStepper.increment = 1
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(fontSizeChanged)

        autoLoginCheckbox.target = self
        autoLoginCheckbox.action = #selector(connectionChanged)
        closeOnDisconnectCheckbox.target = self
        closeOnDisconnectCheckbox.action = #selector(connectionChanged)

        clipboardStepper.minValue = 5
        clipboardStepper.maxValue = 120
        clipboardStepper.increment = 5
        clipboardStepper.target = self
        clipboardStepper.action = #selector(clipboardChanged)

        stack.addArrangedSubview(section("General"))
        stack.addArrangedSubview(row("Theme", themePopup))
        stack.addArrangedSubview(section("Terminal"))
        stack.addArrangedSubview(row("Font Size", NSStackView(views: [fontSizeLabel, fontSizeStepper])))
        stack.addArrangedSubview(section("SSH"))
        stack.addArrangedSubview(autoLoginCheckbox)
        stack.addArrangedSubview(closeOnDisconnectCheckbox)
        stack.addArrangedSubview(section("Security"))
        stack.addArrangedSubview(row("Clear Clipboard", NSStackView(views: [clipboardLabel, clipboardStepper])))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(NSButton(title: "Save", target: self, action: #selector(save)))
        buttons.addArrangedSubview(NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults)))
        stack.addArrangedSubview(buttons)

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)
        ])
    }

    private func section(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.font = .systemFont(ofSize: 13, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func row(_ title: String, _ control: NSView) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let row = NSStackView(views: [titleField, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func syncControls() {
        themePopup.selectItem(withTitle: settings.theme.rawValue.capitalized)
        fontSizeStepper.integerValue = settings.terminal.fontSize
        fontSizeLabel.stringValue = "\(settings.terminal.fontSize) pt"
        autoLoginCheckbox.state = settings.connection.autoLogin ? .on : .off
        closeOnDisconnectCheckbox.state = settings.connection.closeTabOnDisconnect ? .on : .off
        clipboardStepper.integerValue = settings.vault.clearClipboardAfterSeconds
        clipboardLabel.stringValue = "\(settings.vault.clearClipboardAfterSeconds) seconds"
    }

    @objc private func themeChanged() {
        let raw = themePopup.titleOfSelectedItem?.lowercased() ?? NativeThemeMode.system.rawValue
        settings.theme = NativeThemeMode(rawValue: raw) ?? .system
    }

    @objc private func fontSizeChanged() {
        settings.terminal.fontSize = fontSizeStepper.integerValue
        fontSizeLabel.stringValue = "\(settings.terminal.fontSize) pt"
    }

    @objc private func connectionChanged() {
        settings.connection.autoLogin = autoLoginCheckbox.state == .on
        settings.connection.closeTabOnDisconnect = closeOnDisconnectCheckbox.state == .on
    }

    @objc private func clipboardChanged() {
        settings.vault.clearClipboardAfterSeconds = clipboardStepper.integerValue
        clipboardLabel.stringValue = "\(settings.vault.clearClipboardAfterSeconds) seconds"
    }

    @objc private func save() {
        onSave(settings)
        window?.close()
    }

    @objc private func resetDefaults() {
        settings = NativeSettingsDocument()
        syncControls()
    }
}

private extension NativeThemeMode {
    static var allCases: [NativeThemeMode] {
        [.system, .light, .dark]
    }
}
