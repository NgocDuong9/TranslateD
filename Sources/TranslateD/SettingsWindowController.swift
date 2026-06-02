import AppKit

final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings, onSettingsChanged: @escaping () -> Void) {
        let viewController = SettingsViewController(settings: settings, onSettingsChanged: onSettingsChanged)
        let window = NSWindow(contentViewController: viewController)
        window.title = "Setting"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 460))
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class SettingsViewController: NSViewController {
    private let settings: AppSettings
    private let onSettingsChanged: () -> Void
    private let ocrPopup = NSPopUpButton()
    private let geminiAPIKeyField = NSSecureTextField()

    init(settings: AppSettings, onSettingsChanged: @escaping () -> Void) {
        self.settings = settings
        self.onSettingsChanged = onSettingsChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 380))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildInterface()
    }

    private func buildInterface() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(checkBox(title: "Startup On Boot", value: settings.startupOnBoot, action: #selector(toggleStartup(_:))))
        stack.addArrangedSubview(checkBox(title: "Screenshot Area   Control (⌃)+F", value: settings.screenshotEnabled, action: #selector(toggleScreenshot(_:))))
        stack.addArrangedSubview(checkBox(title: "Popup window   Control (⌃)+D", value: settings.popupEnabled, action: #selector(togglePopup(_:))))

        let pasteContainer = NSStackView()
        pasteContainer.orientation = .vertical
        pasteContainer.alignment = .leading
        pasteContainer.spacing = 2
        pasteContainer.addArrangedSubview(checkBox(title: "Paste Translate", value: settings.pasteTranslateEnabled, action: #selector(togglePasteTranslate(_:))))
        let pasteHint = hint("Available from the popup clipboard button")
        pasteContainer.addArrangedSubview(pasteHint)
        pasteHint.translatesAutoresizingMaskIntoConstraints = false
        pasteHint.leadingAnchor.constraint(equalTo: pasteContainer.leadingAnchor, constant: 22).isActive = true
        stack.addArrangedSubview(pasteContainer)

        stack.addArrangedSubview(checkBox(title: "Automatic Chinese-English Translation", value: settings.automaticChineseEnglish, action: #selector(toggleAutomaticChineseEnglish(_:))))

        let ocrLabel = NSTextField(labelWithString: "OCR Languages (Image to Text)")
        ocrLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(ocrLabel)

        ocrPopup.addItems(withTitles: OCRLanguage.allCases.map(\.title))
        ocrPopup.selectItem(withTitle: settings.ocrLanguage.title)
        ocrPopup.target = self
        ocrPopup.action = #selector(changeOCRLanguage)
        ocrPopup.widthAnchor.constraint(equalToConstant: 306).isActive = true
        stack.addArrangedSubview(ocrPopup)

        let geminiLabel = NSTextField(labelWithString: "Gemini API Key")
        geminiLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(geminiLabel)

        let geminiStack = NSStackView()
        geminiStack.orientation = .horizontal
        geminiStack.alignment = .centerY
        geminiStack.spacing = 8

        geminiAPIKeyField.stringValue = settings.geminiAPIKey
        geminiAPIKeyField.placeholderString = "AIza..."
        geminiAPIKeyField.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let saveGeminiButton = NSButton(title: "Save", target: self, action: #selector(saveGeminiAPIKey))
        saveGeminiButton.bezelStyle = .rounded

        geminiStack.addArrangedSubview(geminiAPIKeyField)
        geminiStack.addArrangedSubview(saveGeminiButton)
        stack.addArrangedSubview(geminiStack)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 84),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 34)
        ])
    }

    private func checkBox(title: String, value: Bool, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.state = value ? .on : .off
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        return button
    }

    private func hint(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        return field
    }

    @objc private func toggleStartup(_ sender: NSButton) {
        settings.startupOnBoot = sender.state == .on
        onSettingsChanged()
    }

    @objc private func toggleScreenshot(_ sender: NSButton) {
        settings.screenshotEnabled = sender.state == .on
        onSettingsChanged()
    }

    @objc private func togglePopup(_ sender: NSButton) {
        settings.popupEnabled = sender.state == .on
        onSettingsChanged()
    }

    @objc private func togglePasteTranslate(_ sender: NSButton) {
        settings.pasteTranslateEnabled = sender.state == .on
        onSettingsChanged()
    }

    @objc private func toggleAutomaticChineseEnglish(_ sender: NSButton) {
        settings.automaticChineseEnglish = sender.state == .on
        onSettingsChanged()
    }

    @objc private func changeOCRLanguage() {
        let selectedTitle = ocrPopup.titleOfSelectedItem ?? OCRLanguage.automatic.title
        settings.ocrLanguage = OCRLanguage.allCases.first { $0.title == selectedTitle } ?? .automatic
        onSettingsChanged()
    }

    @objc private func saveGeminiAPIKey() {
        settings.geminiAPIKey = geminiAPIKeyField.stringValue
        onSettingsChanged()
    }
}
