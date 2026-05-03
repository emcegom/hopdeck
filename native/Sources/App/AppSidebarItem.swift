import AppKit
import HopdeckNativeCore

enum AppSidebarItem: Hashable {
    case section(SidebarSection)
    case smartView(title: String, subtitle: String, symbolName: String, count: Int)
    case folder(title: String, subtitle: String, symbolName: String, count: Int)
    case host(SSHHost)

    var title: String {
        switch self {
        case .section(let section):
            section.title
        case .smartView(let title, _, _, _), .folder(let title, _, _, _):
            title
        case .host(let host):
            host.alias
        }
    }

    var subtitle: String {
        switch self {
        case .section:
            ""
        case .smartView(_, let subtitle, _, _), .folder(_, let subtitle, _, _):
            subtitle
        case .host(let host):
            host.displayAddress
        }
    }

    var symbolName: String {
        switch self {
        case .section:
            "chevron.down"
        case .smartView(_, _, let symbolName, _), .folder(_, _, let symbolName, _):
            symbolName
        case .host:
            "server.rack"
        }
    }

    var count: Int? {
        switch self {
        case .section, .host:
            nil
        case .smartView(_, _, _, let count), .folder(_, _, _, let count):
            count
        }
    }

    var isGroup: Bool {
        if case .section = self {
            return true
        }
        return false
    }
}

enum SidebarSection: CaseIterable, Hashable {
    case smartViews
    case folders
    case hosts

    var title: String {
        switch self {
        case .smartViews:
            "Smart Views"
        case .folders:
            "Folders"
        case .hosts:
            "Hosts"
        }
    }
}
