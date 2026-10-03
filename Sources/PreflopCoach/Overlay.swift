import AppKit

/// A small always-on-top box that floats over the table, including over full-screen games
/// where the menu bar is hidden. Drag it anywhere; the position is remembered.
@MainActor
final class Overlay {
    private let panel: NSPanel
    private let headline = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private static let size = NSSize(width: 320, height: 96)

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Overlay.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false

        let box = NSView(frame: NSRect(origin: .zero, size: Overlay.size))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        box.layer?.cornerRadius = 14
        panel.contentView = box

        headline.font = .systemFont(ofSize: 26, weight: .bold)
        headline.textColor = .white
        headline.lineBreakMode = .byTruncatingTail
        headline.frame = NSRect(x: 16, y: 46, width: Overlay.size.width - 32, height: 36)
        box.addSubview(headline)

        detail.font = .systemFont(ofSize: 13, weight: .medium)
        detail.textColor = NSColor.white.withAlphaComponent(0.75)
        detail.maximumNumberOfLines = 2
        detail.lineBreakMode = .byTruncatingTail
        detail.frame = NSRect(x: 16, y: 10, width: Overlay.size.width - 32, height: 36)
        box.addSubview(detail)

        // Remembered position, as long as it is still on a connected screen; otherwise top right.
        let remembered = panel.setFrameUsingName("Overlay")
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        if !remembered || !onScreen, let screen = NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.maxX - Overlay.size.width - 16, y: area.maxY - Overlay.size.height - 16))
        }
        panel.setFrameAutosaveName("Overlay")
    }

    var isShown: Bool { panel.isVisible }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }

    func update(headline text: String, color: NSColor?, detail lines: [String]) {
        headline.stringValue = text
        headline.textColor = color ?? .white
        detail.stringValue = lines.joined(separator: "\n")
    }
}
