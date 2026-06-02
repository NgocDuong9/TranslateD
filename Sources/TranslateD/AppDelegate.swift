import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let translator = GoogleTranslateService()
    private let settings = AppSettings.shared
    private var statusController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureAppIcon()
        installMainMenu()

        let statusController = StatusBarController(
            translator: translator,
            settings: settings,
            onOpenSettings: { [weak self] in self?.showSettings() }
        )
        self.statusController = statusController

        let hotKeyManager = HotKeyManager(settings: settings)
        hotKeyManager.onShowPopup = { [weak statusController] in
            statusController?.showPopover()
        }
        hotKeyManager.onPasteTranslate = { [weak statusController] in
            statusController?.translateClipboard()
        }
        hotKeyManager.onScreenshot = { [weak statusController] in
            statusController?.translateScreenshot()
        }
        hotKeyManager.registerEnabledHotKeys()
        self.hotKeyManager = hotKeyManager
    }

    private func configureAppIcon() {
        guard
            let iconURL = AppResource.url(forResource: "iconApp", withExtension: "png"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
                self?.hotKeyManager?.registerEnabledHotKeys()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        settingsWindowController?.window?.orderFrontRegardless()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let editMenuItem = NSMenuItem()

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(editMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit TranslateD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
