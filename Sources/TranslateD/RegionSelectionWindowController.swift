import AppKit

final class RegionSelectionWindowController: NSWindowController {
    private let selectionView: RegionSelectionView

    init(screen: NSScreen, onComplete: @escaping (CGRect?) -> Void) {
        selectionView = RegionSelectionView(onComplete: onComplete)
        let window = RegionSelectionWindow(contentRect: screen.frame)
        window.contentView = selectionView
        window.setFrame(screen.frame, display: true)
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(selectionView)
        window?.orderFrontRegardless()
    }

    func cancel() {
        selectionView.cancelSelection()
    }
}

private final class RegionSelectionWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

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
    private let onComplete: (CGRect?) -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var didComplete = false

    init(onComplete: @escaping (CGRect?) -> Void) {
        self.onComplete = onComplete
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
        window?.orderOut(nil)
        onComplete(rect)
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
