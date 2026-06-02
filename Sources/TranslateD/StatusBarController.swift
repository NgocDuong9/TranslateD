import AppKit

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let translator: GoogleTranslateService
    private let settings: AppSettings
    private let onOpenSettings: () -> Void
    private let translationViewController: TranslationViewController
    private let ocrService = OCRService()
    private var regionSelectionWindowController: RegionSelectionWindowController?

    init(translator: GoogleTranslateService, settings: AppSettings, onOpenSettings: @escaping () -> Void) {
        self.translator = translator
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.translationViewController = TranslationViewController(translator: translator, settings: settings)
        super.init()

        configureStatusItem()
        configurePopover()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            translationViewController.focusInput()
        }
    }

    func translateClipboard() {
        showPopover()
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        translationViewController.setInputAndTranslate(text)
    }

    func translateScreenshot() {
        translateSelectedRegion()
    }

    func translateSelectedRegion() {
        if let regionSelectionWindowController {
            regionSelectionWindowController.cancel()
            self.regionSelectionWindowController = nil
            return
        }

        popover.performClose(nil)

        guard let screen = NSScreen.main else { return }
        let controller = RegionSelectionWindowController(screen: screen) { [weak self] rect in
            guard let self else { return }
            self.regionSelectionWindowController = nil

            guard let rect else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                Task { @MainActor in
                    do {
                        let text = try await self.ocrService.recognizeScreenText(
                            in: rect,
                            screen: screen,
                            language: self.settings.ocrLanguage
                        )
                        self.showPopover()
                        self.translationViewController.setInputAndTranslate(text)
                    } catch {
                        if case OCRService.OCRError.screenRecordingPermissionRequired = error {
                            self.showScreenRecordingPermissionAlert()
                            return
                        }

                        self.showPopover()
                        self.translationViewController.showStatus(error.localizedDescription)
                    }
                }
            }
        }

        regionSelectionWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = menuIcon()
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func menuIcon() -> NSImage? {
        guard
            let iconURL = AppResource.url(forResource: "icon", withExtension: "svg"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "TranslateD")
        }

        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        icon.accessibilityDescription = "TranslateD"
        return icon
    }

    private func configurePopover() {
        translationViewController.onOpenSettings = { [weak self] in
            self?.popover.performClose(nil)
            self?.onOpenSettings()
        }

        popover.contentSize = NSSize(width: 600, height: 230)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = translationViewController
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            showPopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TranslateD", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showScreenRecordingPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Needed"
        alert.informativeText = """
        TranslateD needs Screen & System Audio Recording permission to capture the selected screen area for OCR.

        Enable permission for the app you use to run TranslateD, such as Terminal, Antigravity IDE, or TranslateD, then quit and reopen the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    private func openScreenRecordingSettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording"
        ]

        for urlString in urlStrings {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
