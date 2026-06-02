import AppKit

struct RegionSelection {
    let rect: CGRect
    let screen: NSScreen
}

final class RegionSelectionWindowController {
    private let screens: [NSScreen]
    private let onComplete: (RegionSelection?) -> Void
    private var windows: [RegionSelectionWindow] = []
    private var didComplete = false

    init(screens: [NSScreen] = NSScreen.screens, onComplete: @escaping (RegionSelection?) -> Void) {
        self.screens = screens
        self.onComplete = onComplete
        self.windows = screens.map { screen in
            let window = RegionSelectionWindow(screen: screen)
            window.selectionView.onComplete = { [weak self, weak screen] rect in
                guard let self else { return }
                guard let rect, let screen else {
                    self.complete(with: nil)
                    return
                }
                self.complete(with: RegionSelection(rect: rect, screen: screen))
            }
            return window
        }
    }

    func showWindows() {
        for window in windows {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }

        if let keyWindow = windows.first(where: { $0.targetScreen == NSScreen.main }) ?? windows.first {
            keyWindow.makeKey()
            keyWindow.makeFirstResponder(keyWindow.selectionView)
        }
    }

    func cancel() {
        complete(with: nil)
    }

    private func complete(with selection: RegionSelection?) {
        guard !didComplete else { return }
        didComplete = true
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onComplete(selection)
    }
}

private final class RegionSelectionWindow: NSWindow {
    let targetScreen: NSScreen
    let selectionView: RegionSelectionView

    init(screen: NSScreen) {
        self.targetScreen = screen
        self.selectionView = RegionSelectionView()

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        contentView = selectionView
        setFrame(screen.frame, display: true)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class RegionSelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var didComplete = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        addCursorRect(bounds, cursor: .crosshair)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dimPath = NSBezierPath(rect: bounds)

        if let selectionRect {
            dimPath.append(NSBezierPath(rect: selectionRect))
            dimPath.windingRule = .evenOdd
        }

        NSColor.black.withAlphaComponent(0.35).setFill()
        dimPath.fill()

        guard let selectionRect else { return }

        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()

        NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        selectionRect.fill()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        let selectedFrame = selectionRect

        guard let selectedFrame, selectedFrame.width >= 8, selectedFrame.height >= 8 else {
            complete(with: nil)
            return
        }

        let screenRect = convert(selectedFrame, to: nil)
        let globalOrigin = window?.convertPoint(toScreen: screenRect.origin) ?? screenRect.origin
        complete(with: CGRect(origin: globalOrigin, size: screenRect.size))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelSelection()
        } else {
            super.keyDown(with: event)
        }
    }

    func cancelSelection() {
        complete(with: nil)
    }

    private func complete(with rect: CGRect?) {
        guard !didComplete else { return }
        didComplete = true
        onComplete?(rect)
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }
}
