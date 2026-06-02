import AppKit

final class TranslationViewController: NSViewController, NSTextViewDelegate {
    private let translator: GoogleTranslateService
    private let geminiTranslator = GeminiTranslateService()
    private let settings: AppSettings
    private let inputTextView = NSTextView()
    private let outputTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let targetLanguagePopup = NSPopUpButton()
    private let translateButton = NSButton(title: "Google", target: nil, action: nil)
    private let aiTranslateButton = NSButton(title: "AI", target: nil, action: nil)
    private var autoTranslateWorkItem: DispatchWorkItem?
    private var lastAutoTranslatedText = ""
    private var googleTranslateSequence = 0

    var onOpenSettings: (() -> Void)?

    init(translator: GoogleTranslateService, settings: AppSettings) {
        self.translator = translator
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 230))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildInterface()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateWrapping(for: inputTextView)
        updateWrapping(for: outputTextView)
    }

    func focusInput() {
        view.window?.makeFirstResponder(inputTextView)
    }

    func setInputAndTranslate(_ text: String) {
        autoTranslateWorkItem?.cancel()
        inputTextView.string = text
        performTranslate()
    }

    func showStatus(_ message: String) {
        statusLabel.stringValue = message
    }

    private func buildInterface() {
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Translate by D")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .secondaryLabelColor

        let leadingSpacer = NSView()
        let trailingSpacer = NSView()
        let quitButton = NSButton(image: NSImage(systemSymbolName: "power", accessibilityDescription: "Quit App")!, target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .regularSquare
        quitButton.isBordered = false
        quitButton.toolTip = "Quit App"

        let settingsButton = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!, target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.toolTip = "Settings"

        header.addArrangedSubview(leadingSpacer)
        header.addArrangedSubview(title)
        header.addArrangedSubview(trailingSpacer)
        header.addArrangedSubview(quitButton)
        header.addArrangedSubview(settingsButton)

        let textStack = NSStackView()
        textStack.orientation = .horizontal
        textStack.spacing = 12
        textStack.distribution = .fillEqually
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let inputScroll = configuredScrollView(textView: inputTextView, placeholder: "Write & Press Enter ^_^")
        let outputScroll = configuredScrollView(textView: outputTextView, placeholder: "")
        outputTextView.isEditable = false
        textStack.addArrangedSubview(inputScroll)
        textStack.addArrangedSubview(outputScroll)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        footer.translatesAutoresizingMaskIntoConstraints = false

        let pasteButton = NSButton(image: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste")!, target: self, action: #selector(pasteAndTranslate))
        pasteButton.bezelStyle = .inline
        pasteButton.isBordered = false

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyOutput))
        copyButton.bezelStyle = .inline

        translateButton.target = self
        translateButton.action = #selector(performTranslate)
        translateButton.bezelStyle = .rounded

        aiTranslateButton.target = self
        aiTranslateButton.action = #selector(performGeminiTranslate)
        aiTranslateButton.bezelStyle = .rounded
        aiTranslateButton.toolTip = "Translate with Gemini AI"

        targetLanguagePopup.addItems(withTitles: ["Vietnamese", "English", "Chinese", "Japanese", "Korean"])
        targetLanguagePopup.selectItem(withTitle: "Vietnamese")

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        footer.addArrangedSubview(pasteButton)
        footer.addArrangedSubview(translateButton)
        footer.addArrangedSubview(aiTranslateButton)
        footer.addArrangedSubview(statusLabel)
        footer.addArrangedSubview(NSView())
        footer.addArrangedSubview(targetLanguagePopup)
        footer.addArrangedSubview(copyButton)

        view.addSubview(header)
        view.addSubview(textStack)
        view.addSubview(footer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 24),

            textStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            textStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            textStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            textStack.heightAnchor.constraint(equalToConstant: 132),

            footer.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14)
        ])
    }

    private func configuredScrollView(textView: NSTextView, placeholder: String) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.75)
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.delegate = self
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.string = ""
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 260, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.frame = NSRect(origin: .zero, size: NSSize(width: 260, height: 132))
        textView.setAccessibilityPlaceholderValue(placeholder)
        scrollView.documentView = textView
        return scrollView
    }

    private func updateWrapping(for textView: NSTextView) {
        guard let scrollView = textView.enclosingScrollView else { return }
        let contentWidth = max(scrollView.contentSize.width, 1)
        textView.frame.size.width = contentWidth
        textView.textContainer?.containerSize = NSSize(
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            autoTranslateWorkItem?.cancel()
            performTranslate()
            return true
        }
        return false
    }

    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === inputTextView else { return }
        scheduleAutoGoogleTranslate()
    }

    @objc private func pasteAndTranslate() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        setInputAndTranslate(text)
    }

    @objc private func performTranslate() {
        autoTranslateWorkItem?.cancel()
        performGoogleTranslate()
    }

    private func scheduleAutoGoogleTranslate() {
        autoTranslateWorkItem?.cancel()

        let text = inputTextView.string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lastAutoTranslatedText = ""
            statusLabel.stringValue = ""
            outputTextView.string = ""
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let currentText = self.inputTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentText.isEmpty, currentText != self.lastAutoTranslatedText else { return }
            self.lastAutoTranslatedText = currentText
            self.performGoogleTranslate()
        }

        autoTranslateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func performGoogleTranslate() {
        let text = inputTextView.string
        let targetLanguage = selectedTargetLanguageCode()
        googleTranslateSequence += 1
        let sequence = googleTranslateSequence

        statusLabel.stringValue = "Google translating..."
        outputTextView.string = ""

        Task { @MainActor in
            do {
                let result = try await translator.translate(text, targetLanguage: targetLanguage)
                guard sequence == googleTranslateSequence else { return }
                outputTextView.string = result.translatedText
                statusLabel.stringValue = result.detectedLanguage.map { "Detected: \($0)" } ?? "Done"
            } catch {
                guard sequence == googleTranslateSequence else { return }
                statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func performGeminiTranslate() {
        autoTranslateWorkItem?.cancel()
        let text = inputTextView.string
        let targetLanguageName = selectedTargetLanguageName()
        statusLabel.stringValue = "Gemini translating..."
        outputTextView.string = ""

        Task { @MainActor in
            do {
                outputTextView.string = try await geminiTranslator.translate(
                    text,
                    targetLanguageName: targetLanguageName,
                    apiKey: settings.geminiAPIKey
                )
                statusLabel.stringValue = "AI done"
            } catch {
                statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputTextView.string, forType: .string)
        statusLabel.stringValue = "Copied"
    }

    @objc private func openSettings() {
        DispatchQueue.main.async { [weak self] in
            self?.onOpenSettings?()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func selectedTargetLanguageCode() -> String {
        switch targetLanguagePopup.titleOfSelectedItem {
        case "English":
            return "en"
        case "Chinese":
            return "zh-CN"
        case "Japanese":
            return "ja"
        case "Korean":
            return "ko"
        default:
            return "vi"
        }
    }

    private func selectedTargetLanguageName() -> String {
        switch targetLanguagePopup.titleOfSelectedItem {
        case "English":
            return "English"
        case "Chinese":
            return "Simplified Chinese"
        case "Japanese":
            return "Japanese"
        case "Korean":
            return "Korean"
        default:
            return "Vietnamese"
        }
    }
}
