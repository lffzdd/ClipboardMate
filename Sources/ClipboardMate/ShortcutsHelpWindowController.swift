import AppKit

final class ShortcutsHelpWindowController: NSWindowController {
    static let shared = ShortcutsHelpWindowController()

    private init() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 440, height: 520))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.string = L10n.shortcutsCheatsheetBody
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.shortcutsHelpTitle
        window.contentView = scrollView
        window.center()
        window.setFrameAutosaveName("ClipboardMateShortcutsHelp")
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showHelp() {
        guard let window else { return }
        if let tv = (window.contentView as? NSScrollView)?.documentView as? NSTextView {
            tv.string = L10n.shortcutsCheatsheetBody
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
