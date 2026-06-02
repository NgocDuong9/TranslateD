import Carbon
import Foundation

final class HotKeyManager {
    private enum HotKeyID: UInt32 {
        case screenshot = 1
        case popup = 2
        case pasteTranslate = 3
    }

    private let settings: AppSettings
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    var onScreenshot: (() -> Void)?
    var onShowPopup: (() -> Void)?
    var onPasteTranslate: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        installHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func registerEnabledHotKeys() {
        unregisterAll()

        if settings.screenshotEnabled {
            register(keyCode: UInt32(kVK_ANSI_F), id: .screenshot)
        }

        if settings.popupEnabled {
            register(keyCode: UInt32(kVK_ANSI_D), id: .popup)
        }

        // Do not register Control+C globally: it conflicts with Terminal interrupt.
        // Paste translate remains available from the popover clipboard button.
    }

    private func register(keyCode: UInt32, id: HotKeyID) {
        let hotKeyID = EventHotKeyID(signature: OSType("TrnD".fourCharCode), id: id.rawValue)
        var ref: EventHotKeyRef?
        let modifiers = UInt32(controlKey)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        hotKeyRefs.append(ref)
    }

    private func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKey(rawID: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
    }

    private func handleHotKey(rawID: UInt32) {
        guard let hotKeyID = HotKeyID(rawValue: rawID) else { return }

        DispatchQueue.main.async { [weak self] in
            switch hotKeyID {
            case .screenshot:
                self?.onScreenshot?()
            case .popup:
                self?.onShowPopup?()
            case .pasteTranslate:
                self?.onPasteTranslate?()
            }
        }
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars.prefix(4) {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
