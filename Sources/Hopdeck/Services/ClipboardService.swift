import AppKit
import Foundation

struct ClipboardService {
    func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    func clearIfStill(_ value: String, after seconds: Int) {
        guard seconds > 0 else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
            let pasteboard = NSPasteboard.general
            if pasteboard.string(forType: .string) == value {
                pasteboard.clearContents()
            }
        }
    }
}
