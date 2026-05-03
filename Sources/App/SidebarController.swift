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
    private let searchField = NSSearchField()
    private var query = ""
    private var activeSmartView: String?
    private var activeFolderTag: String?

    private var visibleHosts: [SSHHost] {
        hosts.filter { host in
            let matchesSmartView: Bool
            switch activeSmartView {
            case "Favorites":
                matchesSmartView = host.tags.contains("favorite")
            case "Needs Attention":
                matchesSmartView = host.address.isEmpty || host.credential.kind == .none
            case "Recent":
                matchesSmartView = recentHosts.map(\.id).contains(host.id)
            default:
                matchesSmartView = true
            }

            let matchesFolder = activeFolderTag.map { host.tags.contains($0) } ?? true
            let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = normalizedQuery.isEmpty || [
                host.alias,
                host.address,
                host.user,
                host.displayAddress,
                host.tags.joined(separator: " ")
            ].contains { $0.lowercased().contains(normalizedQuery) }

            return matchesSmartView && matchesFolder && matchesSearch
        }
    }

    private var recentHosts: [SSHHost] {
        Array(hosts.prefix(3))
    }

    private var favoriteHosts: [SSHHost] {
        hosts.filter { $0.tags.contains("favorite") }
    }

    private var smartViews: [AppSidebarItem] {
        [
            .smartView(title: "All Hosts", subtitle: "Every saved endpoint", symbolName: "tray.full", count: hosts.count),
            .smartView(title: "Recent", subtitle: "Last connected", symbolName: "clock", count: recentHosts.count),
            .smartView(title: "Favorites", subtitle: "Pinned hosts", symbolName: "star", count: favoriteHosts.count),
            .smartView(
                title: "Needs Attention",
                subtitle: "Warnings and stale keys",
                symbolName: "exclamationmark.triangle",
                count: hosts.filter { $0.address.isEmpty || $0.credential.kind == .none }.count
            )
        ]
    }
    private var folders: [AppSidebarItem] {
        let tags = Set(hosts.flatMap(\.tags).filter { $0 != "favorite" }).sorted()
        return tags.map { tag in
            .folder(
                title: tag.capitalized,
                subtitle: "Tagged hosts",
                symbolName: "folder",
                count: hosts.filter { $0.tags.contains(tag) }.count,
                tag: tag
            )
        }
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
        searchField.placeholderString = "Search hosts"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 0, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(searchField)
        stack.addArrangedSubview(scrollView)
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 28)
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
            visibleHosts.map { .host($0) }
        }
    }

    @objc private func searchChanged() {
        query = searchField.stringValue
        outlineView.reloadData()
        outlineView.expandItem(AppSidebarItem.section(.hosts))
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
        guard row >= 0, let item = outlineView.item(atRow: row) as? AppSidebarItem else {
            return
        }

        switch item {
        case .smartView(let title, _, _, _):
            activeSmartView = title == "All Hosts" ? nil : title
            activeFolderTag = nil
            outlineView.reloadData()
            SidebarSection.allCases.forEach { section in
                outlineView.expandItem(AppSidebarItem.section(section))
            }
        case .folder(_, _, _, _, let tag):
            activeFolderTag = tag
            activeSmartView = nil
            outlineView.reloadData()
            SidebarSection.allCases.forEach { section in
                outlineView.expandItem(AppSidebarItem.section(section))
            }
        case .host(let host):
            onSelectHost?(host)
        case .section:
            return
        }
    }
}
