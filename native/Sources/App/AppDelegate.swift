import AppKit
import HopdeckNativeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = buildMainMenu()
        let controller = MainWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        windowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    @objc private func closeSession(_ sender: Any?) {
        windowController?.closeActiveSession()
    }

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Hopdeck Native", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let closeSession = NSMenuItem(title: "Close Session", action: #selector(closeSession(_:)), keyEquivalent: "w")
        closeSession.target = self
        fileMenu.addItem(closeSession)
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        return mainMenu
    }
}
