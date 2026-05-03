import AppKit
import HopdeckNativeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = buildMainMenu()
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    @objc private func closeSession(_ sender: Any?) {
        windowController?.closeActiveSession()
    }

    private func showMainWindow() {
        if windowController == nil {
            windowController = MainWindowController()
            windowController?.window?.isReleasedWhenClosed = false
        }

        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
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
