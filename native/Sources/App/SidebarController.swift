import AppKit
import HopdeckNativeCore

final class SidebarController: NSViewController {
    var hosts: [SSHHost] = [] {
        didSet {
            outlineView.reloadData()
            SidebarSection.allCases.forEach { section in
                outlineView.expandItem(AppSidebarItem.section(section))
            }
        }
    }

    var onSelectHost: ((SSHHost) -> Void)?
    var onConnectHost: ((SSHHost) -> Void)?

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private var smartViews: [AppSidebarItem] {
        [
            .smartView(title: "All Hosts", subtitle: "Every saved endpoint", symbolName: "tray.full", count: hosts.count),
            .smartView(title: "Recent", subtitle: "Last connected", symbolName: "clock", count: min(hosts.count, 3)),
            .smartView(title: "Favorites", subtitle: "Pinned hosts", symbolName: "star", count: 0),
            .smartView(title: "Needs Attention", subtitle: "Warnings and stale keys", symbolName: "exclamationmark.triangle", count: 0)
        ]
    }
    private var folders: [AppSidebarItem] {
        [
            .folder(title: "Production", subtitle: "Critical systems", symbolName: "shippingbox", count: 0),
            .folder(title: "Staging", subtitle: "Pre-release environments", symbolName: "hammer", count: 0),
            .folder(title: "Personal", subtitle: "Local and private hosts", symbolName: "person.crop.circle", count: 0)
        ]
    }

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
        outlineView.floatsGroupRows = false
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
        guard row >= 0, case .host(let host) = outlineView.item(atRow: row) as? AppSidebarItem else {
            return
        }
        onConnectHost?(host)
    }

    private func children(for section: SidebarSection) -> [AppSidebarItem] {
        switch section {
        case .smartViews:
            smartViews
        case .folders:
            folders
        case .hosts:
            hosts.map { .host($0) }
        }
    }
}

extension SidebarController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item as? AppSidebarItem else {
            return SidebarSection.allCases.count
        }

        switch item {
        case .section(let section):
            return children(for: section).count
        case .smartView, .folder, .host:
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? AppSidebarItem else {
            return AppSidebarItem.section(SidebarSection.allCases[index])
        }

        switch item {
        case .section(let section):
            return children(for: section)[index]
        case .smartView, .folder, .host:
            return item
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard case .section = item as? AppSidebarItem else {
            return false
        }
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let item = item as? AppSidebarItem else {
            return false
        }
        return item.isGroup
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        guard let item = item as? AppSidebarItem else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier(item.isGroup ? "SectionCell" : "SidebarCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        let textField = cell.textField ?? NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        textField.font = item.isGroup ? .systemFont(ofSize: 11, weight: .semibold) : .systemFont(ofSize: 13, weight: .regular)
        textField.textColor = item.isGroup ? .secondaryLabelColor : .labelColor

        if item.isGroup {
            textField.stringValue = item.title.uppercased()
        } else if let count = item.count {
            textField.stringValue = "\(item.title)  \(count)"
        } else {
            textField.stringValue = "\(item.title)  \(item.subtitle)"
        }

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
        guard row >= 0, case .host(let host) = outlineView.item(atRow: row) as? AppSidebarItem else {
            return
        }
        onSelectHost?(host)
    }
}
