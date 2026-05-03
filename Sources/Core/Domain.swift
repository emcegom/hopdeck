import Foundation

public struct SSHHost: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var alias: String
    public var address: String
    public var user: String
    public var port: Int
    public var jumpChain: [UUID]
    public var tags: [String]

    public var credential: CredentialRef

    public init(
        id: UUID,
        alias: String,
        address: String,
        user: String,
        port: Int,
        jumpChain: [UUID],
        tags: [String],
        credential: CredentialRef = CredentialRef(kind: .ask)
    ) {
        self.id = id
        self.alias = alias
        self.address = address
        self.user = user
        self.port = port
        self.jumpChain = jumpChain
        self.tags = tags
        self.credential = credential
    }

    public var displayAddress: String {
        "\(user)@\(address):\(port)"
    }
}

public struct TerminalSession: Identifiable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case running
        case closing
        case exited(Int32?)
    }

    public let id: UUID
    public let host: SSHHost?
    public let title: String
    public var state: State

    public init(id: UUID, host: SSHHost?, title: String, state: State) {
        self.id = id
        self.host = host
        self.title = title
        self.state = state
    }
}

public enum ConnectionTarget: Equatable, Sendable {
    case localShell
    case ssh(SSHHost)
}

public enum NativeThemeMode: String, Codable, Equatable, Hashable, Sendable {
    case system
    case light
    case dark
}

public struct NativeTerminalColors: Codable, Equatable, Hashable, Sendable {
    public var background: String
    public var foreground: String
    public var cursor: String
    public var selection: String
    public var ansi: [String]

    public init(
        background: String = "#0F1720",
        foreground: String = "#DBE7F3",
        cursor: String = "#41B6C8",
        selection: String = "#24384A",
        ansi: [String] = NativeTerminalColors.defaultANSI
    ) {
        self.background = background
        self.foreground = foreground
        self.cursor = cursor
        self.selection = selection
        self.ansi = ansi
    }

    public static let defaultANSI = [
        "#172331", "#EF8A80", "#7FD19B", "#E5C15D", "#69A7E8", "#B99CFF", "#41B6C8", "#DBE7F3",
        "#8EA0B4", "#FFB8B0", "#A6E3B6", "#F4D675", "#9BC7FF", "#CFB8FF", "#75D7E4", "#F3F7FB"
    ]
}

public struct NativeTerminalSettings: Codable, Equatable, Hashable, Sendable {
    public var fontFamily: String
    public var fontSize: Int
    public var fontWeight: String
    public var fontWeightBold: String
    public var lineHeight: Double
    public var letterSpacing: Double
    public var minimumContrastRatio: Double
    public var drawBoldTextInBrightColors: Bool
    public var cursorStyle: String
    public var backgroundBlur: Int
    public var backgroundOpacity: Int
    public var autoCopySelection: Bool
    public var colors: NativeTerminalColors

    public init(
        fontFamily: String = "\"SFMono-Regular\", \"JetBrains Mono\", \"MesloLGS NF\", \"Hack Nerd Font\", Menlo, Monaco, Consolas, monospace",
        fontSize: Int = 13,
        fontWeight: String = "400",
        fontWeightBold: String = "700",
        lineHeight: Double = 1.15,
        letterSpacing: Double = 0.0,
        minimumContrastRatio: Double = 4.5,
        drawBoldTextInBrightColors: Bool = true,
        cursorStyle: String = "block",
        backgroundBlur: Int = 0,
        backgroundOpacity: Int = 100,
        autoCopySelection: Bool = true,
        colors: NativeTerminalColors = NativeTerminalColors()
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontWeightBold = fontWeightBold
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.minimumContrastRatio = minimumContrastRatio
        self.drawBoldTextInBrightColors = drawBoldTextInBrightColors
        self.cursorStyle = cursorStyle
        self.backgroundBlur = backgroundBlur
        self.backgroundOpacity = backgroundOpacity
        self.autoCopySelection = autoCopySelection
        self.colors = colors
    }
}

public struct NativeVaultSettings: Codable, Equatable, Hashable, Sendable {
    public var mode: String
    public var clearClipboardAfterSeconds: Int

    public init(mode: String = "plain", clearClipboardAfterSeconds: Int = 20) {
        self.mode = mode
        self.clearClipboardAfterSeconds = clearClipboardAfterSeconds
    }
}

public struct NativeConnectionSettings: Codable, Equatable, Hashable, Sendable {
    public var defaultOpenMode: String
    public var autoLogin: Bool
    public var closeTabOnDisconnect: Bool

    public init(defaultOpenMode: String = "tab", autoLogin: Bool = true, closeTabOnDisconnect: Bool = false) {
        self.defaultOpenMode = defaultOpenMode
        self.autoLogin = autoLogin
        self.closeTabOnDisconnect = closeTabOnDisconnect
    }
}

public struct NativeSettingsDocument: Codable, Equatable, Hashable, Sendable {
    public var version: Int
    public var theme: NativeThemeMode
    public var terminal: NativeTerminalSettings
    public var vault: NativeVaultSettings
    public var connection: NativeConnectionSettings

    public init(
        version: Int = 1,
        theme: NativeThemeMode = .system,
        terminal: NativeTerminalSettings = NativeTerminalSettings(),
        vault: NativeVaultSettings = NativeVaultSettings(),
        connection: NativeConnectionSettings = NativeConnectionSettings()
    ) {
        self.version = version
        self.theme = theme
        self.terminal = terminal
        self.vault = vault
        self.connection = connection
    }
}

public struct WorkspaceLayout: Codable, Equatable, Hashable, Sendable {
    public var sidebarWidth: Double
    public var inspectorWidth: Double
    public var selectedWorkspaceID: UUID?
    public var selectedHostID: UUID?
    public var openSessionIDs: [UUID]

    public init(
        sidebarWidth: Double = 260,
        inspectorWidth: Double = 320,
        selectedWorkspaceID: UUID? = nil,
        selectedHostID: UUID? = nil,
        openSessionIDs: [UUID] = []
    ) {
        self.sidebarWidth = sidebarWidth
        self.inspectorWidth = inspectorWidth
        self.selectedWorkspaceID = selectedWorkspaceID
        self.selectedHostID = selectedHostID
        self.openSessionIDs = openSessionIDs
    }
}

public struct WorkspaceFolder: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var hostIDs: [UUID]
    public var childFolderIDs: [UUID]
    public var expanded: Bool

    public init(id: UUID, name: String, hostIDs: [UUID] = [], childFolderIDs: [UUID] = [], expanded: Bool = true) {
        self.id = id
        self.name = name
        self.hostIDs = hostIDs
        self.childFolderIDs = childFolderIDs
        self.expanded = expanded
    }
}

public enum SmartViewPredicate: String, Codable, Equatable, Hashable, Sendable {
    case favorites
    case recent
    case tag
    case jumpHosts
}

public struct SmartView: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var predicate: SmartViewPredicate
    public var value: String?

    public init(id: UUID, name: String, predicate: SmartViewPredicate, value: String? = nil) {
        self.id = id
        self.name = name
        self.predicate = predicate
        self.value = value
    }
}

public struct ConnectionProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var defaultUser: String?
    public var defaultPort: Int
    public var connectTimeoutSeconds: Int
    public var strictHostKeyChecking: String
    public var extraSSHOptions: [String: String]

    public init(
        id: UUID,
        name: String,
        defaultUser: String? = nil,
        defaultPort: Int = 22,
        connectTimeoutSeconds: Int = 10,
        strictHostKeyChecking: String = "accept-new",
        extraSSHOptions: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.defaultUser = defaultUser
        self.defaultPort = defaultPort
        self.connectTimeoutSeconds = connectTimeoutSeconds
        self.strictHostKeyChecking = strictHostKeyChecking
        self.extraSSHOptions = extraSSHOptions
    }
}

public struct NativeWorkspaceDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var layout: WorkspaceLayout
    public var folders: [WorkspaceFolder]
    public var smartViews: [SmartView]
    public var connectionProfiles: [ConnectionProfile]

    public init(
        version: Int = 1,
        layout: WorkspaceLayout = WorkspaceLayout(),
        folders: [WorkspaceFolder] = [],
        smartViews: [SmartView] = [],
        connectionProfiles: [ConnectionProfile] = []
    ) {
        self.version = version
        self.layout = layout
        self.folders = folders
        self.smartViews = smartViews
        self.connectionProfiles = connectionProfiles
    }
}
