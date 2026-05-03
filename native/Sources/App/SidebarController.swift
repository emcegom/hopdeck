import AppKit
import HopdeckNativeCore

final class SidebarController: NSViewController {
    var hosts: [SSHHost] = [] {
        didSet {
            outlineView.reloadData()
        }
    }

    var onSelectHost: ((SSHHost) -> Void)?
    var onConnectHost: ((SSHHost) -> Void)?

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        configureOutline()
    }

    private func configureOutline() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Hosts"))
        column.title = "Hosts"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.rowSizeStyle = .medium
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClickHost)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doubleClickHost() {
        let row = outlineView.clickedRow
        guard row >= 0, let host = outlineView.item(atRow: row) as? SSHHost else {
            return
        }
        onConnectHost?(host)
    }
}

extension SidebarController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? hosts.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        hosts[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let host = item as? SSHHost else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("HostCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        let textField = cell.textField ?? NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.stringValue = "\(host.alias)  \(host.displayAddress)"

        if cell.textField == nil {
            cell.textField = textField
            cell.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let host = outlineView.item(atRow: row) as? SSHHost else {
            return
        }
        onSelectHost?(host)
    }
}
