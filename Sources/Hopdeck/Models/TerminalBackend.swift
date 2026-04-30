import Foundation

enum TerminalBackend: String, CaseIterable, Identifiable, Codable {
    case terminalApp
    case iTerm2
    case wezTerm
    case ghostty
    case alacritty
    case kitty
    case custom

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .terminalApp:
            return "Terminal.app"
        case .iTerm2:
            return "iTerm2"
        case .wezTerm:
            return "WezTerm"
        case .ghostty:
            return "Ghostty"
        case .alacritty:
            return "Alacritty"
        case .kitty:
            return "kitty"
        case .custom:
            return "Custom"
        }
    }
}
