import AppKit
import Quartz

final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isMovable: Bool {
        get { true }
        set { }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = QuickLookManager.shared
        panel.delegate = QuickLookManager.shared
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}
}

final class ClipboardTableView: NSTableView {
    var onReturn: (() -> Void)?
    var onShiftReturn: (() -> Void)?
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:
            if event.modifierFlags.contains(.shift) {
                onShiftReturn?()
            } else {
                onReturn?()
            }
        case 51, 117: onDelete?()       // Backspace / Forward delete
        default: super.keyDown(with: event)
        }
    }
}

final class DraggableImageView: NSImageView, NSDraggingSource {
    var fileURLProvider: (() -> URL?)?

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    override func mouseDragged(with event: NSEvent) {
        guard let url = fileURLProvider?() else {
            super.mouseDragged(with: event)
            return
        }
        let dragItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        dragItem.setDraggingFrame(bounds, contents: self.image)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
}

final class SplitDividerView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private let lineView = NSView()
    private let gripView = NSImageView()
    private var isDragging = false
    private var lastMouseX: CGFloat = 0
    private var trackingArea: NSTrackingArea?
    private var isHighlighted = false {
        didSet { updateAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        lineView.translatesAutoresizingMaskIntoConstraints = false
        lineView.wantsLayer = true
        addSubview(lineView)

        gripView.translatesAutoresizingMaskIntoConstraints = false
        gripView.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        gripView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold)
        gripView.imageScaling = .scaleProportionallyDown
        addSubview(gripView)

        NSLayoutConstraint.activate([
            lineView.topAnchor.constraint(equalTo: topAnchor),
            lineView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineView.centerXAnchor.constraint(equalTo: centerXAnchor),
            lineView.widthAnchor.constraint(equalToConstant: 1),
            gripView.centerXAnchor.constraint(equalTo: centerXAnchor),
            gripView.centerYAnchor.constraint(equalTo: centerYAnchor),
            gripView.widthAnchor.constraint(equalToConstant: 12),
            gripView.heightAnchor.constraint(equalToConstant: 18)
        ])
        updateAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
    }

    override func mouseExited(with event: NSEvent) {
        guard !isDragging else { return }
        isHighlighted = false
    }

    private func updateAppearance() {
        let accent = NSColor.controlAccentColor
        lineView.layer?.backgroundColor = (isHighlighted ? accent : NSColor.separatorColor).cgColor
        gripView.contentTintColor = isHighlighted ? accent : .tertiaryLabelColor
        layer?.backgroundColor = isHighlighted ? accent.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            isDragging = false
            onDoubleClick?()
            return
        }
        isDragging = true
        isHighlighted = true
        lastMouseX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentX = event.locationInWindow.x
        let delta = currentX - lastMouseX
        lastMouseX = currentX
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            isHighlighted = false
            onDragEnded?()
        }
    }
}

/// 覆盖在弹窗最右边缘的可发现缩放热区。
final class PanelRightResizeHandleView: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?

    private let indicator = NSView()
    private var isDragging = false
    private var lastMouseX: CGFloat = 0
    private var trackingArea: NSTrackingArea?
    private var isHighlighted = false { didSet { updateAppearance() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 1
        addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 2),
            indicator.heightAnchor.constraint(equalToConstant: 36)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent) {
        if !isDragging { isHighlighted = false }
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        isHighlighted = true
        lastMouseX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentX = event.locationInWindow.x
        let delta = currentX - lastMouseX
        lastMouseX = currentX
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        isHighlighted = false
        onDragEnded?()
    }

    private func updateAppearance() {
        let accent = NSColor.controlAccentColor
        // 常态保留细提示，悬停才强调，避免右边缘缩放功能难以发现。
        indicator.layer?.backgroundColor = (isHighlighted ? accent : NSColor.separatorColor.withAlphaComponent(0.7)).cgColor
    }
}

final class PreviewTextView: NSTextView {
    /// TextKit 1 lays out `NSTextBlock` / `NSTextTable`. The parameterless `NSTextView()` uses TextKit 2, which collapses those blocks.
    static func makeTextKit1() -> PreviewTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)
        let view = PreviewTextView(frame: .zero, textContainer: container)
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        return view
    }

    var onMarkdownCodeCopy: ((Int) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where (area.userInfo?["mdCopy"] as? Bool) == true {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["mdCopy": true]
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        if markdownCodeCopy(at: event) != nil {
            NSCursor.pointingHand.set()
        } else {
            super.mouseMoved(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.isEmpty, let index = markdownCodeCopy(at: event)?.index {
            onMarkdownCodeCopy?(index)
            return
        }
        super.mouseDown(with: event)
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainTextForCopy(in: range), forType: .string)
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let range = selectedRange()
        guard range.length > 0 else { return false }
        pboard.declareTypes([.string], owner: nil)
        pboard.setString(plainTextForCopy(in: range), forType: .string)
        return true
    }

    func plainTextForCopy(in range: NSRange? = nil) -> String {
        guard let storage = textStorage else { return string }
        let resolved = range ?? NSRange(location: 0, length: storage.length)
        guard resolved.length > 0, NSMaxRange(resolved) <= storage.length else { return "" }
        return storage.attributedSubstring(from: resolved).stringByRemovingMarkdownChrome()
    }

    private func markdownCodeCopy(at event: NSEvent) -> (index: Int, range: NSRange)? {
        guard let storage = textStorage, let layoutManager, let container = textContainer else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let index = layoutManager.characterIndex(for: local, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
        guard index >= 0, index < storage.length else { return nil }
        var range = NSRange(location: 0, length: 0)
        guard (storage.attribute(.markdownChrome, at: index, effectiveRange: &range) as? Bool) == true else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphs.length > 0 else { return nil }
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
        guard glyphRect.insetBy(dx: -6, dy: -2).contains(local) else { return nil }
        let value = storage.attribute(.markdownCodeCopyIndex, at: index, effectiveRange: nil)
        let blockIndex: Int?
        if let index = value as? Int {
            blockIndex = index
        } else if let number = value as? NSNumber {
            blockIndex = number.intValue
        } else {
            blockIndex = nil
        }
        guard let blockIndex else { return nil }
        return (blockIndex, range)
    }
}

final class PanelController: NSObject, NSSearchFieldDelegate, NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSWindowDelegate, NSTextViewDelegate {
    enum Category: Int {
        case all = 0
        case text = 1
        case image = 2
        case file = 3
        case link = 4
        case pinned = 5
    }

    private let store = ClipboardStore.shared
    private var panel: HistoryPanel!
    private var rootVisualEffect: NSVisualEffectView!
    private var glassTintView: GlassTintView!
    private var leftContainer: NSView!
    private var searchField: NSSearchField!
    private var segmentedControl: NSSegmentedControl!
    private var tableView: ClipboardTableView!
    private var emptyLabel: NSTextField!
    private var settingsButton: NSButton!
    private var stayOpenButton: NSButton!
    private var panelStayOpen = false
    private var pastePrimaryButton: NSButton!
    private var bottomHintLabel: NSTextField!
    private var displayItems: [ClipItem] = []
    private var currentSearchTokens: [String] = []
    private var searchHaystackCache: [UUID: String] = [:]
    private var searchReloadWorkItem: DispatchWorkItem?
    private var showsDeleteUndoHint = false
    private var searchFilterGeneration = 0
    private let searchFilterQueue = DispatchQueue(label: "com.williamlao.clipboardmate.searchfilter", qos: .userInitiated)
    private var lastDisplayItemIDs: [UUID] = []

    private static let preservePanelFilterKey = "preservePanelFilterOnOpen"
    private static let appSwitchCloseDelayKey = "panelAppSwitchCloseDelay"
    private static let closeOnOutsideClickKey = "closePanelOnOutsideClick"
    private static let closeOnAppSwitchKey = "closePanelOnAppSwitch"
    private static let panelLastSearchKey = "panelLastSearch"
    private static let panelLastCategoryKey = "panelLastCategory"

    private static var preservePanelFilterOnOpen: Bool {
        UserDefaults.standard.object(forKey: preservePanelFilterKey) as? Bool ?? true
    }

    private static var closePanelOnOutsideClick: Bool {
        UserDefaults.standard.object(forKey: closeOnOutsideClickKey) as? Bool ?? true
    }

    private static var closePanelOnAppSwitch: Bool {
        UserDefaults.standard.object(forKey: closeOnAppSwitchKey) as? Bool ?? true
    }

    static var appSwitchCloseDelay: TimeInterval {
        let val = UserDefaults.standard.double(forKey: appSwitchCloseDelayKey)
        if val == 0, UserDefaults.standard.object(forKey: appSwitchCloseDelayKey) == nil {
            return 0.4
        }
        return val
    }

    private func persistPanelFilterState() {
        UserDefaults.standard.set(searchField.stringValue, forKey: Self.panelLastSearchKey)
        UserDefaults.standard.set(segmentedControl.selectedSegment, forKey: Self.panelLastCategoryKey)
    }

    /// 保留筛选重新打开时，若列表为空但历史仍在，自动恢复「全部」视图，避免误以为重启丢数据。
    private func reconcileEmptyPanelAfterRestore() {
        guard displayItems.isEmpty, !store.items.isEmpty else { return }

        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            searchField.stringValue = ""
            UserDefaults.standard.set("", forKey: Self.panelLastSearchKey)
            segmentedControl.selectedSegment = 0
            currentCategory = .all
            UserDefaults.standard.set(0, forKey: Self.panelLastCategoryKey)
            reload(preferTop: true)
            flashActionHint(L10n.searchResetFlash(store.items.count))
            return
        }

        if currentCategory != .all, baseItemsForCurrentCategory().isEmpty {
            segmentedControl.selectedSegment = 0
            currentCategory = .all
            UserDefaults.standard.set(0, forKey: Self.panelLastCategoryKey)
            reload(preferTop: true)
            flashActionHint(L10n.searchResetFlash(store.items.count))
        }
    }

    private func mergeableText(from item: ClipItem, includeFiles: Bool) -> String? {
        switch item.kind {
        case .text:
            return item.text
        case .image:
            if store.isOCRPending(item) { return nil }
            if let ocr = item.ocrText, !ocr.isEmpty { return ocr }
            let w = item.width ?? 0
            let h = item.height ?? 0
            return L10n.imageMergePlaceholder(w: w, h: h)
        case .file:
            guard includeFiles, item.filePaths != nil else { return nil }
            let existing = item.existingFilePaths
            if existing.isEmpty { return nil }
            return existing.joined(separator: "\n")
        }
    }

    private func flashActionHint(_ message: String) {
        bottomHintLabel.stringValue = message
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.flashStatusMessage(message, duration: 2.5)
        }
    }

    private var bottomHintRestoreWork: DispatchWorkItem?

    private func flashTransientBottomHint(_ message: String) {
        bottomHintRestoreWork?.cancel()
        bottomHintLabel.stringValue = message
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.flashStatusMessage(message, duration: 1.2)
        }
        let work = DispatchWorkItem { [weak self] in
            self?.updateBottomHint()
        }
        bottomHintRestoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
    private var previewBaseAttributedCache: NSAttributedString?
    private var previewBaseCacheItemID: UUID?
    private var previewBaseCacheMarkdownPreviewMode: Bool?

    // 侧边预览组件与分栏
    private var splitDivider: SplitDividerView!
    private var rightResizeHandle: PanelRightResizeHandleView!
    private var previewContainer: NSView!
    private var previewHeader: NSTextField!
    private var previewMetaLabel: NSTextField!
    private var quickLookButton: NSButton!
    private var previewLayoutButton: NSButton!
    private var imageFitButton: NSButton!
    private var previewTextView: PreviewTextView!
    private var previewCodeBlocks: [String] = []
    private var markdownSegmentedControl: NSSegmentedControl!
    private var isMarkdownPreviewMode: Bool = true
    private var previewTextScrollView: NSScrollView!
    private var previewImageView: DraggableImageView!
    private var previewImageBottomToSectionConstraint: NSLayoutConstraint?
    private var previewImageBottomToContainerConstraint: NSLayoutConstraint?
    private var ocrSectionView: NSView!
    private var ocrTextView: NSTextView!
    private var ocrFoldBtn: NSButton!
    private var ocrHeightConstraint: NSLayoutConstraint!
    private var isOCRFolded = false
    private var expandedOCRItemID: UUID?

    // 预览文本控制栏
    private var previewTextBottomBar: NSView!
    private var previewTextMetaLabel: NSTextField!
    private var scrollToTopBtn: NSButton!
    private var copyAllTextBtn: NSButton!

    // 尺寸与分栏状态
    private let splitDividerWidth: CGFloat = 14
    private let rightResizeHandleWidth: CGFloat = 12
    // 仅作为持久化数据的合理上限；实际可用宽度仍由屏幕和窗口最大尺寸决定。
    private let maxPreviewPanelWidth: CGFloat = 1100
    private var leftPanelWidth: CGFloat = 480
    private var previewPanelWidth: CGFloat = 380
    private var currentPanelHeight: CGFloat = 560
    private var isPreviewVisible = false

    // AutoLayout 核心约束
    private var leftWidthConstraint: NSLayoutConstraint!
    private var leftTrailingToRootConstraint: NSLayoutConstraint!
    private var splitDividerLeadingConstraint: NSLayoutConstraint!
    private var splitDividerWidthConstraint: NSLayoutConstraint!
    private var splitDividerTopConstraint: NSLayoutConstraint!
    private var splitDividerBottomConstraint: NSLayoutConstraint!
    private var previewWidthConstraint: NSLayoutConstraint!
    private var previewLeadingConstraint: NSLayoutConstraint!
    private var previewTrailingConstraint: NSLayoutConstraint!
    private var previewTopConstraint: NSLayoutConstraint!
    private var previewBottomConstraint: NSLayoutConstraint!

    // 颜色卡片预览组件
    private var colorCardContainer: NSView!
    private var colorSwatchView: NSView!
    private var colorHexLabel: NSTextField!
    private var colorRgbLabel: NSTextField!
    private var colorHslLabel: NSTextField!
    private var copyHexBtn: NSButton!
    private var copyRgbBtn: NSButton!
    private var copyHslBtn: NSButton!

    // URL 操作条
    private var urlActionBar: NSView!
    private var urlHostLabel: NSTextField!
    private var urlOpenBtn: NSButton!
    private var previewTextTopToDividerConstraint: NSLayoutConstraint?
    private var previewTextTopToURLConstraint: NSLayoutConstraint?

    private var currentCategory: Category = .all
    private var lastShowDate = Date.distantPast
    /// Frontmost app when the panel was shown; used to ignore duplicate activate events right after open.
    private var frontAppBundleIDWhenShown: String?
    private let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    override init() {
        super.init()
        buildUI()
        installEventMonitors()
        store.onChanged = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.invalidateSearchHaystackCache()
            self.invalidatePreviewBaseCache()
            self.reload()
        }
        store.onOCRUpdated = { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.invalidateSearchHaystackCache()
            self.reload()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    // MARK: - UI

    private func buildUI() {
        let savedHeight = UserDefaults.standard.double(forKey: "panelWindowHeight")
        if savedHeight >= 400 && savedHeight <= 1200 {
            currentPanelHeight = CGFloat(savedHeight)
        } else {
            currentPanelHeight = 560
        }

        let savedLeftWidth = UserDefaults.standard.double(forKey: "leftPanelWidth")
        if savedLeftWidth >= 360 && savedLeftWidth <= 900 {
            leftPanelWidth = CGFloat(savedLeftWidth)
        } else {
            leftPanelWidth = 480
            UserDefaults.standard.set(480, forKey: "leftPanelWidth")
        }

        let savedPreviewWidth = UserDefaults.standard.double(forKey: "previewPanelWidth")
        if savedPreviewWidth >= 280 && savedPreviewWidth <= maxPreviewPanelWidth {
            previewPanelWidth = CGFloat(savedPreviewWidth)
        } else {
            previewPanelWidth = 380
            UserDefaults.standard.set(380, forKey: "previewPanelWidth")
        }

        let alwaysShow = UserDefaults.standard.bool(forKey: "alwaysShowPreview")
        let savedVisible = UserDefaults.standard.bool(forKey: "isPreviewVisible")
        isPreviewVisible = alwaysShow || savedVisible
        let initialWidth: CGFloat = isPreviewVisible ? (leftPanelWidth + splitDividerWidth + previewPanelWidth) : leftPanelWidth

        panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: currentPanelHeight),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.minSize = NSSize(width: 400, height: 420)
        panel.maxSize = NSSize(width: 1400, height: 1000)
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true

        rootVisualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: initialWidth, height: currentPanelHeight))
        rootVisualEffect.material = .popover
        rootVisualEffect.blendingMode = .behindWindow
        rootVisualEffect.state = .active
        rootVisualEffect.wantsLayer = true
        rootVisualEffect.layer?.cornerRadius = 14
        rootVisualEffect.layer?.masksToBounds = true
        panel.contentView = rootVisualEffect
        panel.alphaValue = 1

        glassTintView = GlassTintView()
        glassTintView.translatesAutoresizingMaskIntoConstraints = false
        rootVisualEffect.addSubview(glassTintView)
        NSLayoutConstraint.activate([
            glassTintView.leadingAnchor.constraint(equalTo: rootVisualEffect.leadingAnchor),
            glassTintView.trailingAnchor.constraint(equalTo: rootVisualEffect.trailingAnchor),
            glassTintView.topAnchor.constraint(equalTo: rootVisualEffect.topAnchor),
            glassTintView.bottomAnchor.constraint(equalTo: rootVisualEffect.bottomAnchor)
        ])
        applyStoredGlassTransparency()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared
        )

        // --- 左侧主体容器 ---
        leftContainer = NSView()
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        rootVisualEffect.addSubview(leftContainer)

        searchField = NSSearchField()
        searchField.placeholderString = L10n.searchPlaceholder
        searchField.font = .systemFont(ofSize: 13)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        leftContainer.addSubview(searchField)

        settingsButton = NSButton()
        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.imageScaling = .scaleProportionallyDown
        if let gearImg = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L10n.preferences) {
            gearImg.isTemplate = true
            settingsButton.image = gearImg
        } else if let gearImg = NSImage(systemSymbolName: "gear", accessibilityDescription: L10n.preferences) {
            gearImg.isTemplate = true
            settingsButton.image = gearImg
        }
        settingsButton.target = self
        settingsButton.action = #selector(openSettingsMenu(_:))
        settingsButton.toolTip = L10n.preferences
        settingsButton.setAccessibilityLabel(L10n.preferences)
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(settingsButton)

        stayOpenButton = NSButton()
        stayOpenButton.bezelStyle = .regularSquare
        stayOpenButton.isBordered = false
        stayOpenButton.imageScaling = .scaleProportionallyDown
        stayOpenButton.target = self
        stayOpenButton.action = #selector(togglePanelStayOpen)
        stayOpenButton.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(stayOpenButton)
        updateStayOpenButton()

        // 分类切换 SegmentedControl
        segmentedControl = NSSegmentedControl(
            labels: [L10n.catAll, L10n.catText, L10n.catImage, L10n.catFile, L10n.catLink, L10n.catPinned],
            trackingMode: .selectOne,
            target: self,
            action: #selector(categoryChanged(_:))
        )
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentStyle = .roundRect
        segmentedControl.font = .systemFont(ofSize: 11)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(segmentedControl)

        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        leftContainer.addSubview(divider)

        // 底部提示栏
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(bottomBar)

        let bottomDivider = NSView()
        bottomDivider.translatesAutoresizingMaskIntoConstraints = false
        bottomDivider.wantsLayer = true
        bottomDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        bottomBar.addSubview(bottomDivider)

        pastePrimaryButton = NSButton(title: L10n.primaryPaste, target: self, action: #selector(activateSelectedAction))
        pastePrimaryButton.bezelStyle = .texturedRounded
        pastePrimaryButton.font = .systemFont(ofSize: 11, weight: .semibold)
        pastePrimaryButton.contentTintColor = .controlAccentColor
        pastePrimaryButton.toolTip = L10n.pasteSelectedTooltip
        pastePrimaryButton.setAccessibilityLabel(L10n.pasteSelectedTooltip)
        pastePrimaryButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(pastePrimaryButton)

        bottomHintLabel = NSTextField(labelWithString: L10n.bottomHintUpdated)
        bottomHintLabel.font = .systemFont(ofSize: 10, weight: .regular)
        bottomHintLabel.textColor = .secondaryLabelColor
        bottomHintLabel.alignment = .right
        bottomHintLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(bottomHintLabel)

        // 表格
        tableView = ClipboardTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 50
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.doubleAction = #selector(activateSelectedAction)
        tableView.allowsEmptySelection = false
        tableView.allowsMultipleSelection = true
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.focusRingType = .none
        tableView.onReturn = { [weak self] in self?.returnPressed() }
        tableView.onShiftReturn = { [weak self] in self?.shiftReturnPressed() }
        tableView.onDelete = { [weak self] in self?.deletePressed() }

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(scrollView)

        emptyLabel = NSTextField(labelWithString: L10n.emptyHistory)
        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(emptyLabel)

        setupContextMenu(for: tableView)

        // --- 拖拽分栏线 (Split Divider) ---
        splitDivider = SplitDividerView()
        splitDivider.translatesAutoresizingMaskIntoConstraints = false
        splitDivider.toolTip = L10n.previewResizeHint
        splitDivider.isHidden = !isPreviewVisible
        rootVisualEffect.addSubview(splitDivider)

        splitDivider.onDrag = { [weak self] delta in
            guard let self = self, self.isPreviewVisible else { return }
            let minW: CGFloat = 360
            let maxW: CGFloat = 650
            let minPreviewW: CGFloat = 280
            let availableWidth = self.panel.frame.width - self.splitDividerWidth
            let rawTarget = self.leftPanelWidth + delta
            let defaultWidth: CGFloat = 480
            let targetLeft: CGFloat
            // 磁吸吸附：当拖拽接近 480px (±10px 范围) 时自动吸附，并触发轻微触感震动
            if abs(rawTarget - defaultWidth) < 10 {
                targetLeft = defaultWidth
                if self.leftPanelWidth != defaultWidth {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            } else {
                let maxLeft = min(maxW, availableWidth - minPreviewW)
                targetLeft = min(max(rawTarget, minW), maxLeft)
            }

            let actualDelta = targetLeft - self.leftPanelWidth
            guard abs(actualDelta) > 0.5 else { return }
            self.leftPanelWidth = targetLeft
            self.previewPanelWidth = max(minPreviewW, availableWidth - targetLeft)
            self.leftWidthConstraint.constant = self.leftPanelWidth
            self.previewWidthConstraint.constant = self.previewPanelWidth
            self.rootVisualEffect.layoutSubtreeIfNeeded()
        }

        splitDivider.onDragEnded = { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set("manual", forKey: "previewLayoutMode")
            UserDefaults.standard.set(self.leftPanelWidth, forKey: "leftPanelWidth")
            UserDefaults.standard.set(self.previewPanelWidth, forKey: "previewPanelWidth")
            self.updatePreviewLayoutButton()
        }

        splitDivider.onDoubleClick = { [weak self] in
            self?.resetPreviewSplitToSmartDefaults()
        }

        // --- 右侧预览容器 (QuickLook) ---
        previewContainer = NSView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.isHidden = !isPreviewVisible
        rootVisualEffect.addSubview(previewContainer)

        previewHeader = NSTextField(labelWithString: L10n.previewTitle)
        previewHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        previewHeader.textColor = .labelColor
        previewHeader.cell?.lineBreakMode = .byTruncatingTail
        previewHeader.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewHeader.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewHeader)

        previewMetaLabel = NSTextField(labelWithString: "")
        previewMetaLabel.font = .systemFont(ofSize: 11, weight: .regular)
        previewMetaLabel.textColor = .secondaryLabelColor
        previewMetaLabel.cell?.lineBreakMode = .byTruncatingTail
        previewMetaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewMetaLabel)

        quickLookButton = NSButton(title: "🔍 " + L10n.fullSizeQuickLook, target: self, action: #selector(openFullSizeQuickLook))
        quickLookButton.bezelStyle = .inline
        quickLookButton.font = .systemFont(ofSize: 11)
        quickLookButton.translatesAutoresizingMaskIntoConstraints = false
        quickLookButton.isHidden = true
        previewContainer.addSubview(quickLookButton)

        previewLayoutButton = NSButton(title: "", target: self, action: #selector(openPreviewLayoutMenu(_:)))
        previewLayoutButton.bezelStyle = .inline
        previewLayoutButton.font = .systemFont(ofSize: 11, weight: .medium)
        previewLayoutButton.contentTintColor = .secondaryLabelColor
        previewLayoutButton.toolTip = L10n.previewLayout
        previewLayoutButton.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewLayoutButton)

        imageFitButton = NSButton(title: L10n.imageFitPreview, target: self, action: #selector(resetImagePreviewFit))
        imageFitButton.bezelStyle = .inline
        imageFitButton.font = .systemFont(ofSize: 11)
        imageFitButton.toolTip = L10n.imageFitTooltip
        imageFitButton.translatesAutoresizingMaskIntoConstraints = false
        imageFitButton.isHidden = true
        previewContainer.addSubview(imageFitButton)

        let previewSubDivider = NSView()
        previewSubDivider.translatesAutoresizingMaskIntoConstraints = false
        previewSubDivider.wantsLayer = true
        previewSubDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        previewContainer.addSubview(previewSubDivider)

        // URL 操作条
        urlActionBar = NSView()
        urlActionBar.translatesAutoresizingMaskIntoConstraints = false
        urlActionBar.wantsLayer = true
        urlActionBar.layer?.cornerRadius = 6
        urlActionBar.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        urlActionBar.isHidden = true
        previewContainer.addSubview(urlActionBar)

        urlHostLabel = NSTextField(labelWithString: "")
        urlHostLabel.font = .systemFont(ofSize: 12, weight: .medium)
        urlHostLabel.textColor = .secondaryLabelColor
        urlHostLabel.cell?.lineBreakMode = .byTruncatingMiddle
        urlHostLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        urlHostLabel.translatesAutoresizingMaskIntoConstraints = false
        urlActionBar.addSubview(urlHostLabel)

        urlOpenBtn = NSButton(title: L10n.openInBrowser, target: self, action: #selector(openSelectedURL))
        urlOpenBtn.bezelStyle = .inline
        urlOpenBtn.font = .systemFont(ofSize: 11)
        urlOpenBtn.translatesAutoresizingMaskIntoConstraints = false
        urlActionBar.addSubview(urlOpenBtn)

        // 颜色卡片
        colorCardContainer = NSView()
        colorCardContainer.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.wantsLayer = true
        colorCardContainer.layer?.cornerRadius = 10
        colorCardContainer.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.15).cgColor
        colorCardContainer.isHidden = true
        previewContainer.addSubview(colorCardContainer)

        colorSwatchView = NSView()
        colorSwatchView.translatesAutoresizingMaskIntoConstraints = false
        colorSwatchView.wantsLayer = true
        colorSwatchView.layer?.cornerRadius = 8
        colorSwatchView.layer?.borderWidth = 1
        colorSwatchView.layer?.borderColor = NSColor.separatorColor.cgColor
        colorCardContainer.addSubview(colorSwatchView)

        colorHexLabel = NSTextField(labelWithString: "")
        colorHexLabel.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        colorHexLabel.textColor = .labelColor
        colorHexLabel.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(colorHexLabel)

        colorRgbLabel = NSTextField(labelWithString: "")
        colorRgbLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        colorRgbLabel.textColor = .secondaryLabelColor
        colorRgbLabel.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(colorRgbLabel)

        colorHslLabel = NSTextField(labelWithString: "")
        colorHslLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        colorHslLabel.textColor = .secondaryLabelColor
        colorHslLabel.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(colorHslLabel)

        copyHexBtn = NSButton(title: L10n.copyHEX, target: self, action: #selector(copyColorHex))
        copyHexBtn.bezelStyle = .inline
        copyHexBtn.font = .systemFont(ofSize: 10)
        copyHexBtn.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(copyHexBtn)

        copyRgbBtn = NSButton(title: L10n.copyRGB, target: self, action: #selector(copyColorRGB))
        copyRgbBtn.bezelStyle = .inline
        copyRgbBtn.font = .systemFont(ofSize: 10)
        copyRgbBtn.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(copyRgbBtn)

        copyHslBtn = NSButton(title: L10n.copyHSL, target: self, action: #selector(copyColorHSL))
        copyHslBtn.bezelStyle = .inline
        copyHslBtn.font = .systemFont(ofSize: 10)
        copyHslBtn.translatesAutoresizingMaskIntoConstraints = false
        colorCardContainer.addSubview(copyHslBtn)

        // 图片预览
        previewImageView = DraggableImageView()
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyDown
        previewImageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        previewImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previewImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 8
        previewImageView.layer?.masksToBounds = true

        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(openFullSizeQuickLook))
        doubleClick.numberOfClicksRequired = 2
        previewImageView.addGestureRecognizer(doubleClick)
        previewImageView.toolTip = L10n.doubleClickToZoom
        previewContainer.addSubview(previewImageView)

        previewTextView = PreviewTextView.makeTextKit1()
        previewTextView.delegate = self
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.font = .systemFont(ofSize: 13)
        previewTextView.textColor = .labelColor
        previewTextView.isHorizontallyResizable = false
        previewTextView.autoresizingMask = [.width]
        previewTextView.textContainer?.widthTracksTextView = true
        previewTextView.isAutomaticLinkDetectionEnabled = false
        previewTextView.isAutomaticDataDetectionEnabled = false
        previewTextView.isAutomaticTextReplacementEnabled = false
        previewTextView.isAutomaticQuoteSubstitutionEnabled = false
        previewTextView.isAutomaticDashSubstitutionEnabled = false
        previewTextView.isAutomaticSpellingCorrectionEnabled = false
        previewTextView.isRichText = true
        previewTextView.importsGraphics = false
        previewTextView.enabledTextCheckingTypes = 0
        previewTextView.onMarkdownCodeCopy = { [weak self] index in
            self?.copyPreviewCodeBlock(at: index)
        }
        previewTextView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]

        previewTextScrollView = NSScrollView()
        previewTextScrollView.documentView = previewTextView
        previewTextScrollView.hasVerticalScroller = true
        previewTextScrollView.autohidesScrollers = true
        previewTextScrollView.drawsBackground = false
        previewTextScrollView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewTextScrollView)

        // 预览文本底部控制栏
        previewTextBottomBar = NSView()
        previewTextBottomBar.translatesAutoresizingMaskIntoConstraints = false
        previewTextBottomBar.isHidden = true
        previewContainer.addSubview(previewTextBottomBar)

        previewTextMetaLabel = NSTextField(labelWithString: "")
        previewTextMetaLabel.font = .systemFont(ofSize: 10, weight: .regular)
        previewTextMetaLabel.textColor = .secondaryLabelColor
        previewTextMetaLabel.cell?.lineBreakMode = .byTruncatingTail
        previewTextMetaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewTextMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        previewTextBottomBar.addSubview(previewTextMetaLabel)

        markdownSegmentedControl = NSSegmentedControl(labels: [L10n.markdownPreview, L10n.markdownRaw], trackingMode: .selectOne, target: self, action: #selector(markdownModeChanged))
        markdownSegmentedControl.segmentStyle = .texturedRounded
        markdownSegmentedControl.selectedSegment = 0
        markdownSegmentedControl.controlSize = .small
        markdownSegmentedControl.font = .systemFont(ofSize: 10, weight: .medium)
        markdownSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        markdownSegmentedControl.isHidden = true
        previewTextBottomBar.addSubview(markdownSegmentedControl)

        scrollToTopBtn = NSButton(title: L10n.scrollToTop, target: self, action: #selector(scrollPreviewToTop))
        scrollToTopBtn.bezelStyle = .inline
        scrollToTopBtn.font = .systemFont(ofSize: 10)
        scrollToTopBtn.translatesAutoresizingMaskIntoConstraints = false
        previewTextBottomBar.addSubview(scrollToTopBtn)

        copyAllTextBtn = NSButton(title: L10n.copyAll, target: self, action: #selector(copyAllPreviewText))
        copyAllTextBtn.bezelStyle = .inline
        copyAllTextBtn.font = .systemFont(ofSize: 10)
        copyAllTextBtn.translatesAutoresizingMaskIntoConstraints = false
        previewTextBottomBar.addSubview(copyAllTextBtn)

        // OCR 结果面板
        ocrSectionView = NSView()
        ocrSectionView.translatesAutoresizingMaskIntoConstraints = false
        ocrSectionView.isHidden = true
        previewContainer.addSubview(ocrSectionView)

        let ocrDivider = NSView()
        ocrDivider.translatesAutoresizingMaskIntoConstraints = false
        ocrDivider.wantsLayer = true
        ocrDivider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        ocrSectionView.addSubview(ocrDivider)

        let ocrTitleLabel = NSTextField(labelWithString: L10n.ocrTitle)
        ocrTitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        ocrTitleLabel.textColor = .secondaryLabelColor
        ocrTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        ocrSectionView.addSubview(ocrTitleLabel)

        ocrFoldBtn = NSButton(title: L10n.foldOCR, target: self, action: #selector(toggleOCRFold))
        ocrFoldBtn.bezelStyle = .inline
        ocrFoldBtn.font = .systemFont(ofSize: 10)
        ocrFoldBtn.translatesAutoresizingMaskIntoConstraints = false
        ocrSectionView.addSubview(ocrFoldBtn)

        let ocrCopyBtn = NSButton(title: L10n.ocrCopyButton, target: self, action: #selector(copyPreviewOCRText))
        ocrCopyBtn.bezelStyle = .inline
        ocrCopyBtn.font = .systemFont(ofSize: 11)
        ocrCopyBtn.translatesAutoresizingMaskIntoConstraints = false
        ocrSectionView.addSubview(ocrCopyBtn)

        ocrTextView = NSTextView()
        ocrTextView.isEditable = false
        ocrTextView.isSelectable = true
        ocrTextView.drawsBackground = false
        ocrTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        ocrTextView.textColor = .labelColor
        ocrTextView.isHorizontallyResizable = false
        ocrTextView.autoresizingMask = [.width]
        ocrTextView.textContainer?.widthTracksTextView = true

        let ocrScrollView = NSScrollView()
        ocrScrollView.documentView = ocrTextView
        ocrScrollView.hasVerticalScroller = true
        ocrScrollView.autohidesScrollers = true
        ocrScrollView.drawsBackground = false
        ocrScrollView.translatesAutoresizingMaskIntoConstraints = false
        ocrSectionView.addSubview(ocrScrollView)

        // 弹窗最右边缘的缩放热区：无预览时缩放列表，有预览时缩放预览栏。
        rightResizeHandle = PanelRightResizeHandleView()
        rightResizeHandle.translatesAutoresizingMaskIntoConstraints = false
        rightResizeHandle.toolTip = L10n.panelResizeHint
        rightResizeHandle.onDrag = { [weak self] delta in
            self?.resizePanelFromRightEdge(by: delta)
        }
        rightResizeHandle.onDragEnded = { [weak self] in
            self?.persistRightEdgeResize()
        }
        rootVisualEffect.addSubview(rightResizeHandle)

        // --- 核心尺寸与分栏约束 ---
        leftWidthConstraint = leftContainer.widthAnchor.constraint(equalToConstant: leftPanelWidth)
        leftTrailingToRootConstraint = leftContainer.trailingAnchor.constraint(equalTo: rootVisualEffect.trailingAnchor)

        splitDividerLeadingConstraint = splitDivider.leadingAnchor.constraint(equalTo: leftContainer.trailingAnchor)
        splitDividerWidthConstraint = splitDivider.widthAnchor.constraint(equalToConstant: splitDividerWidth)
        splitDividerTopConstraint = splitDivider.topAnchor.constraint(equalTo: rootVisualEffect.topAnchor)
        splitDividerBottomConstraint = splitDivider.bottomAnchor.constraint(equalTo: rootVisualEffect.bottomAnchor)

        previewWidthConstraint = previewContainer.widthAnchor.constraint(equalToConstant: previewPanelWidth)
        previewLeadingConstraint = previewContainer.leadingAnchor.constraint(equalTo: splitDivider.trailingAnchor)
        previewTrailingConstraint = previewContainer.trailingAnchor.constraint(equalTo: rootVisualEffect.trailingAnchor)
        previewTopConstraint = previewContainer.topAnchor.constraint(equalTo: rootVisualEffect.topAnchor)
        previewBottomConstraint = previewContainer.bottomAnchor.constraint(equalTo: rootVisualEffect.bottomAnchor)

        ocrHeightConstraint = ocrSectionView.heightAnchor.constraint(equalToConstant: 140)

        previewImageBottomToContainerConstraint = previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -16)
        previewImageBottomToSectionConstraint = previewImageView.bottomAnchor.constraint(equalTo: ocrSectionView.topAnchor, constant: -10)
        previewImageBottomToContainerConstraint?.isActive = true

        previewTextTopToDividerConstraint = previewTextScrollView.topAnchor.constraint(equalTo: previewSubDivider.bottomAnchor, constant: 10)
        previewTextTopToURLConstraint = previewTextScrollView.topAnchor.constraint(equalTo: urlActionBar.bottomAnchor, constant: 8)
        previewTextTopToDividerConstraint?.isActive = true

        NSLayoutConstraint.activate([
            // 左侧容器
            leftContainer.leadingAnchor.constraint(equalTo: rootVisualEffect.leadingAnchor),
            leftContainer.topAnchor.constraint(equalTo: rootVisualEffect.topAnchor),
            leftContainer.bottomAnchor.constraint(equalTo: rootVisualEffect.bottomAnchor),
            leftWidthConstraint,

            searchField.topAnchor.constraint(equalTo: leftContainer.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: stayOpenButton.leadingAnchor, constant: -6),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            stayOpenButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            stayOpenButton.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -2),
            stayOpenButton.widthAnchor.constraint(equalToConstant: 24),
            stayOpenButton.heightAnchor.constraint(equalToConstant: 24),

            settingsButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: -12),
            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),

            segmentedControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor, constant: 12),
            segmentedControl.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: -12),
            segmentedControl.heightAnchor.constraint(equalToConstant: 24),

            divider.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            bottomBar.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 26),

            bottomDivider.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomDivider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            bottomDivider.heightAnchor.constraint(equalToConstant: 1),

            pastePrimaryButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 10),
            pastePrimaryButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            pastePrimaryButton.heightAnchor.constraint(equalToConstant: 22),

            bottomHintLabel.leadingAnchor.constraint(greaterThanOrEqualTo: pastePrimaryButton.trailingAnchor, constant: 8),
            bottomHintLabel.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -10),
            bottomHintLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor, constant: 1),

            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: leftContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            // 右侧预览容器结构
            previewHeader.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 12),
            previewHeader.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            previewHeader.trailingAnchor.constraint(lessThanOrEqualTo: imageFitButton.leadingAnchor, constant: -8),

            previewMetaLabel.topAnchor.constraint(equalTo: previewHeader.bottomAnchor, constant: 2),
            previewMetaLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            previewMetaLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),

            quickLookButton.centerYAnchor.constraint(equalTo: previewHeader.centerYAnchor),
            quickLookButton.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),

            previewLayoutButton.centerYAnchor.constraint(equalTo: previewHeader.centerYAnchor),
            previewLayoutButton.trailingAnchor.constraint(equalTo: quickLookButton.leadingAnchor, constant: -8),

            imageFitButton.centerYAnchor.constraint(equalTo: previewHeader.centerYAnchor),
            imageFitButton.trailingAnchor.constraint(equalTo: previewLayoutButton.leadingAnchor, constant: -6),

            previewSubDivider.topAnchor.constraint(equalTo: previewMetaLabel.bottomAnchor, constant: 8),
            previewSubDivider.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewSubDivider.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewSubDivider.heightAnchor.constraint(equalToConstant: 1),

            // URL 操作条
            urlActionBar.topAnchor.constraint(equalTo: previewSubDivider.bottomAnchor, constant: 8),
            urlActionBar.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            urlActionBar.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            urlActionBar.heightAnchor.constraint(equalToConstant: 32),

            urlHostLabel.leadingAnchor.constraint(equalTo: urlActionBar.leadingAnchor, constant: 10),
            urlHostLabel.centerYAnchor.constraint(equalTo: urlActionBar.centerYAnchor),
            urlHostLabel.trailingAnchor.constraint(lessThanOrEqualTo: urlOpenBtn.leadingAnchor, constant: -8),

            urlOpenBtn.trailingAnchor.constraint(equalTo: urlActionBar.trailingAnchor, constant: -8),
            urlOpenBtn.centerYAnchor.constraint(equalTo: urlActionBar.centerYAnchor),

            // 颜色卡片
            colorCardContainer.topAnchor.constraint(equalTo: previewSubDivider.bottomAnchor, constant: 12),
            colorCardContainer.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            colorCardContainer.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            colorCardContainer.heightAnchor.constraint(equalToConstant: 130),

            colorSwatchView.leadingAnchor.constraint(equalTo: colorCardContainer.leadingAnchor, constant: 12),
            colorSwatchView.topAnchor.constraint(equalTo: colorCardContainer.topAnchor, constant: 12),
            colorSwatchView.widthAnchor.constraint(equalToConstant: 90),
            colorSwatchView.heightAnchor.constraint(equalToConstant: 68),

            colorHexLabel.topAnchor.constraint(equalTo: colorSwatchView.topAnchor),
            colorHexLabel.leadingAnchor.constraint(equalTo: colorSwatchView.trailingAnchor, constant: 14),
            colorHexLabel.trailingAnchor.constraint(equalTo: colorCardContainer.trailingAnchor, constant: -12),

            colorRgbLabel.topAnchor.constraint(equalTo: colorHexLabel.bottomAnchor, constant: 4),
            colorRgbLabel.leadingAnchor.constraint(equalTo: colorHexLabel.leadingAnchor),
            colorRgbLabel.trailingAnchor.constraint(equalTo: colorCardContainer.trailingAnchor, constant: -12),

            colorHslLabel.topAnchor.constraint(equalTo: colorRgbLabel.bottomAnchor, constant: 4),
            colorHslLabel.leadingAnchor.constraint(equalTo: colorHexLabel.leadingAnchor),
            colorHslLabel.trailingAnchor.constraint(equalTo: colorCardContainer.trailingAnchor, constant: -12),

            copyHexBtn.leadingAnchor.constraint(equalTo: colorSwatchView.leadingAnchor),
            copyHexBtn.topAnchor.constraint(equalTo: colorSwatchView.bottomAnchor, constant: 10),

            copyRgbBtn.leadingAnchor.constraint(equalTo: copyHexBtn.trailingAnchor, constant: 6),
            copyRgbBtn.centerYAnchor.constraint(equalTo: copyHexBtn.centerYAnchor),

            copyHslBtn.leadingAnchor.constraint(equalTo: copyRgbBtn.trailingAnchor, constant: 6),
            copyHslBtn.centerYAnchor.constraint(equalTo: copyHexBtn.centerYAnchor),

            // 图片预览
            previewImageView.topAnchor.constraint(equalTo: previewSubDivider.bottomAnchor, constant: 14),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),

            // OCR 区域
            ocrSectionView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            ocrSectionView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            ocrSectionView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -12),
            ocrHeightConstraint,

            ocrDivider.topAnchor.constraint(equalTo: ocrSectionView.topAnchor),
            ocrDivider.leadingAnchor.constraint(equalTo: ocrSectionView.leadingAnchor),
            ocrDivider.trailingAnchor.constraint(equalTo: ocrSectionView.trailingAnchor),
            ocrDivider.heightAnchor.constraint(equalToConstant: 1),

            ocrTitleLabel.topAnchor.constraint(equalTo: ocrDivider.bottomAnchor, constant: 6),
            ocrTitleLabel.leadingAnchor.constraint(equalTo: ocrSectionView.leadingAnchor),

            ocrFoldBtn.centerYAnchor.constraint(equalTo: ocrTitleLabel.centerYAnchor),
            ocrFoldBtn.leadingAnchor.constraint(equalTo: ocrTitleLabel.trailingAnchor, constant: 6),

            ocrCopyBtn.centerYAnchor.constraint(equalTo: ocrTitleLabel.centerYAnchor),
            ocrCopyBtn.trailingAnchor.constraint(equalTo: ocrSectionView.trailingAnchor),

            ocrScrollView.topAnchor.constraint(equalTo: ocrTitleLabel.bottomAnchor, constant: 6),
            ocrScrollView.leadingAnchor.constraint(equalTo: ocrSectionView.leadingAnchor),
            ocrScrollView.trailingAnchor.constraint(equalTo: ocrSectionView.trailingAnchor),
            ocrScrollView.bottomAnchor.constraint(equalTo: ocrSectionView.bottomAnchor),

            // 文本控制底栏
            previewTextBottomBar.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            previewTextBottomBar.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            previewTextBottomBar.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -8),
            previewTextBottomBar.heightAnchor.constraint(equalToConstant: 22),

            previewTextMetaLabel.leadingAnchor.constraint(equalTo: previewTextBottomBar.leadingAnchor),
            previewTextMetaLabel.centerYAnchor.constraint(equalTo: previewTextBottomBar.centerYAnchor),
            previewTextMetaLabel.trailingAnchor.constraint(lessThanOrEqualTo: markdownSegmentedControl.leadingAnchor, constant: -6),

            copyAllTextBtn.trailingAnchor.constraint(equalTo: previewTextBottomBar.trailingAnchor),
            copyAllTextBtn.centerYAnchor.constraint(equalTo: previewTextBottomBar.centerYAnchor),

            scrollToTopBtn.trailingAnchor.constraint(equalTo: copyAllTextBtn.leadingAnchor, constant: -6),
            scrollToTopBtn.centerYAnchor.constraint(equalTo: previewTextBottomBar.centerYAnchor),

            markdownSegmentedControl.trailingAnchor.constraint(equalTo: scrollToTopBtn.leadingAnchor, constant: -8),
            markdownSegmentedControl.centerYAnchor.constraint(equalTo: previewTextBottomBar.centerYAnchor),

            // 文本滚动区域（底部留给控制栏）
            previewTextScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            previewTextScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            previewTextScrollView.bottomAnchor.constraint(equalTo: previewTextBottomBar.topAnchor, constant: -4),

            // 最右边缘缩放热区始终在顶层，兼容有/无预览的布局。
            rightResizeHandle.topAnchor.constraint(equalTo: rootVisualEffect.topAnchor),
            rightResizeHandle.bottomAnchor.constraint(equalTo: rootVisualEffect.bottomAnchor),
            rightResizeHandle.trailingAnchor.constraint(equalTo: rootVisualEffect.trailingAnchor),
            rightResizeHandle.widthAnchor.constraint(equalToConstant: rightResizeHandleWidth),
        ])

        updateLayoutForPreviewState(animated: false)
    }

    private func updateLayoutForPreviewState(animated: Bool) {
        // 预览打开时保证列表和预览都不会被压缩到不可用的宽度。
        panel.minSize.width = isPreviewVisible ? (360 + splitDividerWidth + 280) : 400

        if isPreviewVisible {
            leftTrailingToRootConstraint.isActive = false
            leftWidthConstraint.constant = leftPanelWidth
            leftWidthConstraint.isActive = true

            splitDividerLeadingConstraint.isActive = true
            splitDividerWidthConstraint.isActive = true
            splitDividerTopConstraint.isActive = true
            splitDividerBottomConstraint.isActive = true

            previewWidthConstraint.constant = previewPanelWidth
            previewWidthConstraint.isActive = true
            previewLeadingConstraint.isActive = true
            previewTrailingConstraint.isActive = true
            previewTopConstraint.isActive = true
            previewBottomConstraint.isActive = true

            splitDivider.isHidden = false
            previewContainer.isHidden = false
        } else {
            previewWidthConstraint.isActive = false
            previewLeadingConstraint.isActive = false
            previewTrailingConstraint.isActive = false
            previewTopConstraint.isActive = false
            previewBottomConstraint.isActive = false

            splitDividerLeadingConstraint.isActive = false
            splitDividerWidthConstraint.isActive = false
            splitDividerTopConstraint.isActive = false
            splitDividerBottomConstraint.isActive = false

            splitDivider.isHidden = true
            previewContainer.isHidden = true

            leftWidthConstraint.constant = leftPanelWidth
            leftWidthConstraint.isActive = true
            leftTrailingToRootConstraint.isActive = true
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.allowsImplicitAnimation = true
                self.rootVisualEffect.layoutSubtreeIfNeeded()
            }
        } else {
            rootVisualEffect.layoutSubtreeIfNeeded()
        }
    }

    @objc private func toggleOCRFold() {
        isOCRFolded.toggle()
        let row = tableView.selectedRow
        if !isOCRFolded, row >= 0, row < displayItems.count {
            expandedOCRItemID = displayItems[row].id
        } else {
            expandedOCRItemID = nil
        }
        applyOCRFoldLayout(animated: true)
    }

    private func applyOCRFoldLayout(animated: Bool) {
        if isOCRFolded {
            ocrHeightConstraint.constant = 28
            ocrTextView.enclosingScrollView?.isHidden = true
            ocrFoldBtn.title = L10n.unfoldOCR
        } else {
            ocrHeightConstraint.constant = 140
            ocrTextView.enclosingScrollView?.isHidden = false
            ocrFoldBtn.title = L10n.foldOCR
        }

        guard animated else {
            previewContainer.layoutSubtreeIfNeeded()
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            self.previewContainer.layoutSubtreeIfNeeded()
        }
    }

    @objc private func scrollPreviewToTop() {
        previewTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        previewTextScrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        previewTextScrollView.reflectScrolledClipView(previewTextScrollView.contentView)
    }

    @objc private func copyAllPreviewText() {
        let str = previewTextView.plainTextForCopy()
        guard !str.isEmpty else { return }
        ClipboardStore.shared.writeStringToPasteboard(str)
    }

    @objc private func markdownModeChanged(_ sender: NSSegmentedControl) {
        isMarkdownPreviewMode = (sender.selectedSegment == 0)
        updatePreview()
    }

    /// 完整替换预览文本属性。直接赋 `string` / `font` 会留下上一份 Markdown 的红色链接和粉色代码色。
    private func applyPreviewPlainText(_ text: String, font: NSFont, searchTokens: [String] = []) {
        let attributed = SyntaxHighlighter.highlightText(
            text,
            tokens: searchTokens,
            baseFont: font,
            baseColor: .labelColor
        )
        applyPreviewAttributedText(attributed)
    }

    private func cacheAndApplyPreviewBase(_ base: NSAttributedString, itemID: UUID) {
        previewBaseCacheItemID = itemID
        previewBaseCacheMarkdownPreviewMode = isMarkdownPreviewMode
        previewBaseAttributedCache = base
        let highlighted = currentSearchTokens.isEmpty
            ? base
            : SyntaxHighlighter.highlightMatches(in: base, tokens: currentSearchTokens)
        applyPreviewAttributedText(highlighted)
    }

    private func applyPreviewPlainTextCached(_ text: String, font: NSFont, itemID: UUID) {
        let base = SyntaxHighlighter.highlightText(
            text,
            tokens: [],
            baseFont: font,
            baseColor: .labelColor
        )
        cacheAndApplyPreviewBase(base, itemID: itemID)
    }

    private func applyPreviewAttributedText(_ attributed: NSAttributedString) {
        guard let storage = previewTextView.textStorage else { return }
        // End the edit before layout. ensureLayout(for:) throws
        // NSInternalInconsistencyException if it runs while the storage is still editing,
        // which is what a deferred endEditing() does when search refreshes an open preview.
        storage.beginEditing()
        storage.setAttributedString(attributed)
        storage.endEditing()

        let font = (attributed.length > 0 ? attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont : nil)
            ?? .systemFont(ofSize: 13)
        previewTextView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        if let container = previewTextView.textContainer {
            previewTextView.layoutManager?.ensureLayout(for: container)
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
            return true
        } else if let str = link as? String, let url = URL(string: str) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }

    private func copyPreviewCodeBlock(at index: Int) {
        guard previewCodeBlocks.indices.contains(index) else { return }
        ClipboardStore.shared.writeStringToPasteboard(previewCodeBlocks[index])
        triggerHaptic()
        flashTransientBottomHint(L10n.codeBlockCopied)
    }

    private func setupContextMenu(for table: NSTableView) {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        table.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let selectedRows = tableView.selectedRowIndexes.sorted()
        let clicked = tableView.clickedRow
        let effectiveRow = clicked >= 0 ? clicked : tableView.selectedRow

        if selectedRows.count > 1 {
            let pasteMerge = NSMenuItem(title: L10n.mergeNewline, action: #selector(mergeWithNewline), keyEquivalent: "")
            pasteMerge.target = self
            menu.addItem(pasteMerge)

            let pasteComma = NSMenuItem(title: L10n.mergeComma, action: #selector(mergeWithComma), keyEquivalent: "")
            pasteComma.target = self
            menu.addItem(pasteComma)

            let mergeOptions = NSMenuItem(title: L10n.mergeSeparatorMenu, action: nil, keyEquivalent: "")
            let subMenu = NSMenu()
            let mSpace = NSMenuItem(title: L10n.mergeSpace, action: #selector(mergeWithSpace), keyEquivalent: "")
            mSpace.target = self
            subMenu.addItem(mSpace)
            let mNone = NSMenuItem(title: L10n.mergeNone, action: #selector(mergeWithNone), keyEquivalent: "")
            mNone.target = self
            subMenu.addItem(mNone)
            mergeOptions.submenu = subMenu
            menu.addItem(mergeOptions)

            let pastePlain = NSMenuItem(title: L10n.pastePlain, action: #selector(pastePlainTextRow), keyEquivalent: "")
            pastePlain.target = self
            menu.addItem(pastePlain)

            let copyMerge = NSMenuItem(title: L10n.mergeCopy, action: #selector(copySelectedOnly), keyEquivalent: "")
            copyMerge.target = self
            menu.addItem(copyMerge)

            menu.addItem(.separator())

            let startQueue = NSMenuItem(title: L10n.startQueue, action: #selector(startQueueWithSelected), keyEquivalent: "")
            startQueue.target = self
            let qSub = NSMenu()
            let qFIFO = NSMenuItem(title: L10n.startQueueFIFO, action: #selector(startQueueFIFO), keyEquivalent: "")
            qFIFO.target = self
            qSub.addItem(qFIFO)
            let qLIFO = NSMenuItem(title: L10n.startQueueLIFO, action: #selector(startQueueLIFO), keyEquivalent: "")
            qLIFO.target = self
            qSub.addItem(qLIFO)
            let qSel = NSMenuItem(title: L10n.startQueueSelection, action: #selector(startQueueSelection), keyEquivalent: "")
            qSel.target = self
            qSub.addItem(qSel)
            startQueue.submenu = qSub
            menu.addItem(startQueue)

            menu.addItem(.separator())

            let delete = NSMenuItem(title: L10n.deleteSelected, action: #selector(deleteRow), keyEquivalent: "")
            delete.target = self
            menu.addItem(delete)
            return
        }

        guard effectiveRow >= 0, effectiveRow < displayItems.count else {
            let clear = NSMenuItem(title: L10n.clearAll, action: #selector(clearAllRows), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
            return
        }

        let item = displayItems[effectiveRow]

        let paste = NSMenuItem(title: L10n.pasteEnter, action: #selector(activateSelectedAction), keyEquivalent: "")
        paste.target = self
        menu.addItem(paste)

        let pastePlain = NSMenuItem(title: L10n.pastePlain, action: #selector(pastePlainTextRow), keyEquivalent: "")
        pastePlain.target = self
        menu.addItem(pastePlain)

        let copyOnly = NSMenuItem(title: L10n.copyOnly, action: #selector(copySelectedOnly), keyEquivalent: "")
        copyOnly.target = self
        copyOnly.toolTip = L10n.copyPanelTooltip
        menu.addItem(copyOnly)

        if item.isURL {
            let openURL = NSMenuItem(title: L10n.openURL, action: #selector(openSelectedURL), keyEquivalent: "")
            openURL.target = self
            menu.addItem(openURL)
        }

        if item.kind == .image {
            let fullSize = NSMenuItem(title: L10n.fullSizeQuickLook, action: #selector(openFullSizeQuickLook), keyEquivalent: "")
            fullSize.target = self
            menu.addItem(fullSize)

            let openApp = NSMenuItem(title: L10n.openInPreviewApp, action: #selector(openInPreviewApp), keyEquivalent: "")
            openApp.target = self
            menu.addItem(openApp)
        }

        if item.kind == .file {
            let fullSize = NSMenuItem(title: L10n.fullSizeQuickLook, action: #selector(openFullSizeQuickLook), keyEquivalent: "")
            fullSize.target = self
            menu.addItem(fullSize)

            let openApp = NSMenuItem(title: L10n.openFileInFinder, action: #selector(openInPreviewApp), keyEquivalent: "")
            openApp.target = self
            menu.addItem(openApp)
        }

        if item.kind == .image, let ocr = item.ocrText, !ocr.isEmpty {
            let copyOCR = NSMenuItem(title: L10n.copyOCR, action: #selector(copyOCRTextRow), keyEquivalent: "")
            copyOCR.target = self
            menu.addItem(copyOCR)
        }

        if item.kind == .text {
            let transformItem = NSMenuItem(title: L10n.transformMenu, action: nil, keyEquivalent: "")
            let sub = NSMenu()

            let jsonBeautify = NSMenuItem(title: L10n.jsonFormat, action: #selector(transformJSONBeautify), keyEquivalent: "")
            jsonBeautify.target = self
            sub.addItem(jsonBeautify)

            let jsonMin = NSMenuItem(title: L10n.jsonMinify, action: #selector(transformJSONMinify), keyEquivalent: "")
            jsonMin.target = self
            sub.addItem(jsonMin)

            sub.addItem(.separator())

            let toCamel = NSMenuItem(title: L10n.toCamelCase, action: #selector(transformToCamelCase), keyEquivalent: "")
            toCamel.target = self
            sub.addItem(toCamel)

            let toSnake = NSMenuItem(title: L10n.toSnakeCase, action: #selector(transformToSnakeCase), keyEquivalent: "")
            toSnake.target = self
            sub.addItem(toSnake)

            let toKebab = NSMenuItem(title: L10n.toKebabCase, action: #selector(transformToKebabCase), keyEquivalent: "")
            toKebab.target = self
            sub.addItem(toKebab)

            let toUpper = NSMenuItem(title: L10n.toUpperCase, action: #selector(transformToUpperCase), keyEquivalent: "")
            toUpper.target = self
            sub.addItem(toUpper)

            let toLower = NSMenuItem(title: L10n.toLowerCase, action: #selector(transformToLowerCase), keyEquivalent: "")
            toLower.target = self
            sub.addItem(toLower)

            sub.addItem(.separator())

            let urlEnc = NSMenuItem(title: L10n.urlEncode, action: #selector(transformURLEncode), keyEquivalent: "")
            urlEnc.target = self
            sub.addItem(urlEnc)

            let urlDec = NSMenuItem(title: L10n.urlDecode, action: #selector(transformURLDecode), keyEquivalent: "")
            urlDec.target = self
            sub.addItem(urlDec)

            let b64Enc = NSMenuItem(title: L10n.base64Encode, action: #selector(transformBase64Encode), keyEquivalent: "")
            b64Enc.target = self
            sub.addItem(b64Enc)

            let b64Dec = NSMenuItem(title: L10n.base64Decode, action: #selector(transformBase64Decode), keyEquivalent: "")
            b64Dec.target = self
            sub.addItem(b64Dec)

            transformItem.submenu = sub
            menu.addItem(transformItem)
        }

        menu.addItem(.separator())

        let queueItem = NSMenuItem(title: L10n.startQueue, action: #selector(startQueueWithSelected), keyEquivalent: "")
        queueItem.target = self
        menu.addItem(queueItem)

        let preview = NSMenuItem(title: L10n.togglePreview, action: #selector(togglePreview), keyEquivalent: "")
        preview.target = self
        menu.addItem(preview)

        let pin = NSMenuItem(title: L10n.pinToggle, action: #selector(togglePinRow), keyEquivalent: "")
        pin.target = self
        menu.addItem(pin)

        if item.kind == .text {
            let editText = NSMenuItem(title: L10n.editTextContent, action: #selector(promptEditText), keyEquivalent: "")
            editText.target = self
            menu.addItem(editText)
        }

        let alias = NSMenuItem(title: L10n.setAlias, action: #selector(promptSetAlias), keyEquivalent: "")
        alias.target = self
        menu.addItem(alias)

        let delete = NSMenuItem(title: L10n.deleteItem, action: #selector(deleteRow), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)

        menu.addItem(.separator())

        if store.isQueueActive {
            let stopQueue = NSMenuItem(title: L10n.clearQueue, action: #selector(stopPasteQueue), keyEquivalent: "")
            stopQueue.target = self
            menu.addItem(stopQueue)
        }

        let clear = NSMenuItem(title: L10n.clearAll, action: #selector(clearAllRows), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }

    private func installEventMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else { return event }

            // Esc 键：
            // 1. 若搜索框有文字，先清空搜索框并恢复完整列表
            // 2. 否则直接关闭剪贴板面板（保留用户的预览展开/收起偏好，不在此改变 isPreviewVisible）
            if event.keyCode == 53 {
                if !self.searchField.stringValue.isEmpty {
                    self.searchField.stringValue = ""
                    self.reload(preferTop: true)
                } else {
                    self.hidePanel()
                }
                return nil
            }

            // Space：搜索框里有内容时用于分词；否则切换侧边预览
            if event.keyCode == 49 {
                if let editor = self.searchField.currentEditor(), !editor.string.isEmpty {
                    return event
                }
                self.togglePreview()
                return nil
            }

            // Delete / Forward Delete：搜索框为空时删除选中条目
            if event.keyCode == 51 || event.keyCode == 117 {
                if let editor = self.searchField.currentEditor(), !editor.string.isEmpty {
                    return event
                }
                self.deletePressed()
                return nil
            }

            // Option + Return：纯文本无格式粘贴
            if event.keyCode == 36 && event.modifierFlags.contains(.option) {
                self.activateSelected(plainTextOnly: true)
                return nil
            }

            // Cmd + C：仅复制到剪贴板，不触发自动粘贴
            if event.keyCode == 8 && event.modifierFlags.contains(.command) {
                if let textView = self.panel.firstResponder as? NSTextView,
                   textView.selectedRange().length > 0 {
                    return event
                }
                self.copySelectedOnly()
                return nil
            }

            // Cmd + O：若是链接则在浏览器中打开
            if event.keyCode == 31 && event.modifierFlags.contains(.command) {
                self.openSelectedURL()
                return nil
            }

            // Cmd + P：置顶 / 取消置顶
            if event.keyCode == 35 && event.modifierFlags.contains(.command) {
                self.togglePinRow()
                return nil
            }

            // Cmd + R：重命名 / 设置别名
            if event.keyCode == 15 && event.modifierFlags.contains(.command) {
                self.promptSetAlias()
                return nil
            }

            // Cmd + S / Shift + Cmd + S：启动填表队列（⌘S 为 FIFO 先复制先贴，⇧⌘S 为 LIFO 后复制先贴）
            if event.keyCode == 1 && event.modifierFlags.contains(.command) {
                if event.modifierFlags.contains(.shift) {
                    self.startQueueLIFO()
                } else {
                    self.startQueueFIFO()
                }
                return nil
            }

            // Cmd + A：全选列表条目（若非在搜索框文字中全选）
            if event.keyCode == 0 && event.modifierFlags.contains(.command) {
                if let editor = self.searchField.currentEditor(), !editor.string.isEmpty {
                    return event
                }
                self.selectAllRows()
                return nil
            }

            // Cmd + Z：撤销删除（搜索框无内容时；不与搜索框内撤销冲突）
            if event.keyCode == 6 && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                if let editor = self.searchField.currentEditor(), !editor.string.isEmpty {
                    return event
                }
                if self.store.undoLastDelete() {
                    self.showsDeleteUndoHint = false
                    self.reload()
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.flashStatusMessage(L10n.deleteUndoSuccess)
                    }
                    return nil
                }
            }

            // Cmd+1..9 快速粘贴前 9 项
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let num = Int(chars), num >= 1 && num <= 9,
               L10n.isQuickPasteEnabled {
                let index = num - 1
                if index < self.displayItems.count {
                    self.activateRow(index)
                    return nil
                }
            }

            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, Self.closePanelOnOutsideClick, !self.panelStayOpen else { return }
            self.hidePanel()
        }
    }

    // MARK: - 显示 / 隐藏

    func toggle() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    func showPanel() {
        lastShowDate = Date()
        frontAppBundleIDWhenShown = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let alwaysShow = UserDefaults.standard.bool(forKey: "alwaysShowPreview")
        let savedVisible = UserDefaults.standard.bool(forKey: "isPreviewVisible")
        isPreviewVisible = alwaysShow || savedVisible
        updateLayoutForPreviewState(animated: false)

        if Self.preservePanelFilterOnOpen {
            searchField.stringValue = UserDefaults.standard.string(forKey: Self.panelLastSearchKey) ?? ""
            let catIndex = UserDefaults.standard.integer(forKey: Self.panelLastCategoryKey)
            if catIndex >= 0, catIndex < segmentedControl.segmentCount {
                segmentedControl.selectedSegment = catIndex
                currentCategory = Category(rawValue: catIndex) ?? .all
            } else {
                segmentedControl.selectedSegment = 0
                currentCategory = .all
            }
            reload(preferTop: searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            reconcileEmptyPanelAfterRestore()
        } else {
            searchField.stringValue = ""
            segmentedControl.selectedSegment = 0
            currentCategory = .all
            reload(preferTop: true)
        }
        if isPreviewVisible, currentPreviewLayoutMode() == "automatic" {
            setPreviewWidth(smartPreviewWidth(), resetLeft: false)
        }
        positionWindow()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func hidePanel() {
        guard panel.isVisible else { return }
        if NSApp.modalWindow != nil { return }
        panelStayOpen = false
        updateStayOpenButton()
        persistPanelFilterState()
        frontAppBundleIDWhenShown = nil
        panel.orderOut(nil)
    }

    @objc private func togglePanelStayOpen() {
        panelStayOpen.toggle()
        updateStayOpenButton()
    }

    private func updateStayOpenButton() {
        guard stayOpenButton != nil else { return }
        let symbol = panelStayOpen ? "pin.fill" : "pin"
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: L10n.panelStayOpen) {
            image.isTemplate = true
            stayOpenButton.image = image
        }
        stayOpenButton.contentTintColor = panelStayOpen ? .controlAccentColor : .secondaryLabelColor
        stayOpenButton.toolTip = panelStayOpen ? L10n.panelStayOpenOn : L10n.panelStayOpen
        stayOpenButton.setAccessibilityLabel(L10n.panelStayOpen)
    }

    @objc private func frontAppChanged(_ notification: Notification) {
        guard !panelStayOpen else { return }
        guard Self.closePanelOnAppSwitch else { return }
        guard panel.isVisible else { return }
        guard NSApp.modalWindow == nil else { return }
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard let bundleID = app?.bundleIdentifier else { return }
        guard bundleID != Bundle.main.bundleIdentifier else { return }

        let withinOpenDebounce = Date().timeIntervalSince(lastShowDate) <= Self.appSwitchCloseDelay
        if withinOpenDebounce, bundleID == frontAppBundleIDWhenShown {
            return
        }
        hidePanel()
    }

    private func positionWindow() {
        let mode = UserDefaults.standard.string(forKey: "windowPositionMode") ?? "center"
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let currentWidth: CGFloat = isPreviewVisible ? (leftPanelWidth + splitDividerWidth + previewPanelWidth) : leftPanelWidth

        var x: CGFloat = 0
        var y: CGFloat = 0

        if mode == "center" {
            x = visible.midX - currentWidth / 2
            y = visible.maxY - currentPanelHeight - 100
        } else {
            x = mouse.x - currentWidth / 2
            y = mouse.y - 60 - currentPanelHeight
        }

        x = min(max(x, visible.minX + 8), visible.maxX - currentWidth - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - currentPanelHeight - 8)
        panel.setFrame(NSRect(x: x, y: y, width: currentWidth, height: currentPanelHeight), display: true, animate: false)
    }

    // MARK: - 偏好设置菜单呼出

    @objc private func openSettingsMenu(_ sender: NSButton) {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.popStatusMenu(from: sender)
    }

    // MARK: - 分类与预览

    @objc private func categoryChanged(_ sender: NSSegmentedControl) {
        currentCategory = Category(rawValue: sender.selectedSegment) ?? .all
        reload(preferTop: true)
    }

    @objc private func openPreviewLayoutMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for (mode, title) in [
            ("compact", L10n.previewLayoutCompact),
            ("automatic", L10n.previewLayoutAutomatic),
            ("wide", L10n.previewLayoutWide)
        ] {
            let item = NSMenuItem(title: title, action: #selector(selectPreviewLayoutFromHeader(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.target = self
            item.state = currentPreviewLayoutMode() == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let reset = NSMenuItem(title: L10n.resetSmartPreview, action: #selector(resetPreviewLayoutFromHeader), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    @objc private func selectPreviewLayoutFromHeader(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        applyPreviewLayoutMode(mode)
    }

    @objc private func resetPreviewLayoutFromHeader() {
        resetPreviewToSmartWidth()
    }

    @objc private func resetImagePreviewFit() {
        resetPreviewToSmartWidth()
    }

    private func cycleCategory(forward: Bool) {
        let total = segmentedControl.segmentCount
        var next = segmentedControl.selectedSegment + (forward ? 1 : -1)
        if next < 0 { next = total - 1 }
        if next >= total { next = 0 }
        segmentedControl.selectedSegment = next
        currentCategory = Category(rawValue: next) ?? .all
        reload(preferTop: true)
    }

    @objc func togglePreview() {
        let alwaysShow = UserDefaults.standard.bool(forKey: "alwaysShowPreview")
        if alwaysShow && isPreviewVisible {
            return
        }
        isPreviewVisible.toggle()
        UserDefaults.standard.set(isPreviewVisible, forKey: "isPreviewVisible")
        if isPreviewVisible, currentPreviewLayoutMode() == "automatic" {
            previewPanelWidth = smartPreviewWidth()
        }
        updateLayoutForPreviewState(animated: false)

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let maximumWidth = min(panel.maxSize.width, visible.width - 16)
        var targetWidth: CGFloat = isPreviewVisible ? (leftPanelWidth + splitDividerWidth + previewPanelWidth) : leftPanelWidth
        targetWidth = min(max(targetWidth, panel.minSize.width), maximumWidth)
        if isPreviewVisible {
            let maxLeftWidth = max(360, targetWidth - splitDividerWidth - 280)
            leftPanelWidth = min(leftPanelWidth, maxLeftWidth)
            previewPanelWidth = targetWidth - leftPanelWidth - splitDividerWidth
            leftWidthConstraint.constant = leftPanelWidth
            previewWidthConstraint.constant = previewPanelWidth
        } else {
            leftPanelWidth = targetWidth
            leftWidthConstraint.constant = leftPanelWidth
        }
        var newFrame = panel.frame
        let oldWidth = newFrame.width
        newFrame.size.width = targetWidth
        newFrame.size.height = currentPanelHeight

        let mode = UserDefaults.standard.string(forKey: "windowPositionMode") ?? "center"

        if mode == "center" {
            let widthDiff = targetWidth - oldWidth
            newFrame.origin.x -= widthDiff / 2
        }

        newFrame.origin.x = min(max(newFrame.origin.x, visible.minX + 8), visible.maxX - targetWidth - 8)
        newFrame.origin.y = min(max(newFrame.origin.y, visible.minY + 8), visible.maxY - newFrame.height - 8)

        panel.setFrame(newFrame, display: true, animate: false)

        if isPreviewVisible {
            updatePreview()
        }
    }

    /// 根据当前条目的内容类型给出一个适合阅读的预览宽度。
    /// 只在用户双击分隔线重置时使用，避免切换历史条目时窗口不停跳动。
    private func smartPreviewWidth() -> CGFloat {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return 380 }
        let item = displayItems[row]

        if item.kind == .image {
            let imageWidth = CGFloat(item.width ?? 0)
            let imageHeight = CGFloat(item.height ?? 0)
            let aspectRatio = imageHeight > 0 ? imageWidth / imageHeight : 1
            var width: CGFloat
            if aspectRatio < 0.85 {
                width = 380
            } else if aspectRatio > 1.6 {
                width = 520
            } else {
                width = 460
            }
            if item.ocrText?.isEmpty == false {
                width = min(width + 40, 540)
            }
            return width
        }
        if item.isURL || item.isColor {
            return 320
        }
        let trimmed = (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeJSON = (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
        if looksLikeJSON, TextTransformer.beautifyJSON(trimmed) != nil {
            return 500
        }
        if item.lineCount > 24 || item.characterCount > 1200 {
            return 500
        }
        if item.lineCount > 8 || item.characterCount > 360 {
            return 440
        }
        return 360
    }

    func currentPreviewLayoutMode() -> String {
        UserDefaults.standard.string(forKey: "previewLayoutMode") ?? "automatic"
    }

    func applyPreviewLayoutMode(_ mode: String) {
        let normalized = ["compact", "automatic", "wide"].contains(mode) ? mode : "automatic"
        UserDefaults.standard.set(normalized, forKey: "previewLayoutMode")

        switch normalized {
        case "compact":
            setPreviewWidth(320, resetLeft: false)
        case "wide":
            setPreviewWidth(520, resetLeft: false)
        default:
            resetPreviewToSmartWidth()
        }
        updatePreviewLayoutButton()
    }

    private func setPreviewWidth(_ width: CGFloat, resetLeft: Bool) {
        if resetLeft {
            leftPanelWidth = 480
        }
        guard isPreviewVisible else {
            previewPanelWidth = min(max(width, 280), maxPreviewPanelWidth)
            UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
            UserDefaults.standard.set(previewPanelWidth, forKey: "previewPanelWidth")
            return
        }

        previewPanelWidth = min(max(width, 280), maxPreviewPanelWidth)
        let targetWidth = leftPanelWidth + splitDividerWidth + previewPanelWidth
        var frame = panel.frame
        let oldWidth = frame.width
        frame.size.width = targetWidth
        let mode = UserDefaults.standard.string(forKey: "windowPositionMode") ?? "center"
        if mode == "center" {
            frame.origin.x -= (targetWidth - oldWidth) / 2
        }
        let visible = NSScreen.screens.first { $0.frame.intersects(panel.frame) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - targetWidth - 8)
        panel.setFrame(frame, display: true, animate: false)
        leftWidthConstraint.constant = leftPanelWidth
        previewWidthConstraint.constant = previewPanelWidth
        rootVisualEffect.layoutSubtreeIfNeeded()

        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
        UserDefaults.standard.set(previewPanelWidth, forKey: "previewPanelWidth")
        updatePreview()
    }

    func resetPreviewToSmartWidth() {
        UserDefaults.standard.set("automatic", forKey: "previewLayoutMode")
        let width = smartPreviewWidth()
        setPreviewWidth(width, resetLeft: true)
        updatePreviewLayoutButton()
    }

    private func updatePreviewLayoutButton() {
        guard previewLayoutButton != nil else { return }
        let title: String
        switch currentPreviewLayoutMode() {
        case "compact": title = L10n.previewLayoutCompact
        case "wide": title = L10n.previewLayoutWide
        case "manual": title = L10n.previewLayoutManual
        default: title = L10n.previewLayoutAutomatic
        }
        previewLayoutButton.title = title + " ▾"
    }

    /// 双击分隔线：恢复左右栏的智能默认值，并把窗口调整到合适宽度。
    private func resetPreviewSplitToSmartDefaults() {
        guard isPreviewVisible else { return }
        resetPreviewToSmartWidth()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    static let panelGlassTransparencyKey = "panelGlassTransparency"

    /// 1 是最初那档 popover 玻璃，不加罩；0 是实色罩。文字不跟着变淡。
    static var storedGlassTransparency: CGFloat {
        let raw = UserDefaults.standard.object(forKey: panelGlassTransparencyKey) as? Double ?? 1
        return CGFloat(min(1, max(0, raw)))
    }

    static var reducesTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    func applyStoredGlassTransparency() {
        panel.alphaValue = 1
        let transparency = Self.reducesTransparency ? 0 : Self.storedGlassTransparency
        glassTintView.cover = 1 - transparency
    }

    @objc private func accessibilityDisplayOptionsChanged() {
        applyStoredGlassTransparency()
    }

    func applyAlwaysShowPreview(_ alwaysShow: Bool) {
        if alwaysShow != isPreviewVisible {
            togglePreview()
        }
    }

    private func resizePanelFromRightEdge(by delta: CGFloat) {
        guard abs(delta) > 0.5 else { return }

        var frame = panel.frame
        let minimumWidth: CGFloat = isPreviewVisible
            ? 360 + splitDividerWidth + 280
            : 400
        let visible = NSScreen.screens.first { $0.frame.intersects(frame) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let maximumWidth = min(panel.maxSize.width, visible.maxX - frame.minX - 8)
        let targetWidth = min(max(frame.width + delta, minimumWidth), maximumWidth)
        guard abs(targetWidth - frame.width) > 0.5 else { return }

        // 保持左边缘不动，让用户明确感觉是在拖“右边”。
        frame.size.width = targetWidth
        panel.setFrame(frame, display: true, animate: false)

        if isPreviewVisible {
            previewPanelWidth = targetWidth - leftPanelWidth - splitDividerWidth
            previewWidthConstraint.constant = previewPanelWidth
        } else {
            leftPanelWidth = targetWidth
            leftWidthConstraint.constant = leftPanelWidth
        }
        rootVisualEffect.layoutSubtreeIfNeeded()
    }

    private func persistRightEdgeResize() {
        if isPreviewVisible {
            UserDefaults.standard.set("manual", forKey: "previewLayoutMode")
            UserDefaults.standard.set(previewPanelWidth, forKey: "previewPanelWidth")
            updatePreviewLayoutButton()
        }
        UserDefaults.standard.set(leftPanelWidth, forKey: "leftPanelWidth")
    }

    func windowDidResize(_ notification: Notification) {
        guard panel.isVisible else { return }
        let size = panel.frame.size
        currentPanelHeight = size.height
        UserDefaults.standard.set(currentPanelHeight, forKey: "panelWindowHeight")

        if isPreviewVisible {
            let remainingWidth = size.width - leftPanelWidth - splitDividerWidth
            let defaultPreviewWidth: CGFloat = 380
            let finalPreviewWidth: CGFloat
            // 磁吸吸附：当拉伸窗口使得预览宽度接近 380px (±12px 范围) 时自动吸附并震动
            if abs(remainingWidth - defaultPreviewWidth) < 12 {
                finalPreviewWidth = defaultPreviewWidth
                if previewPanelWidth != defaultPreviewWidth {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            } else {
                finalPreviewWidth = min(max(remainingWidth, 280), maxPreviewPanelWidth)
            }
            previewPanelWidth = finalPreviewWidth
            previewWidthConstraint?.constant = previewPanelWidth
            UserDefaults.standard.set(previewPanelWidth, forKey: "previewPanelWidth")
        }
    }

    private func updatePreview() {
        guard isPreviewVisible else { return }
        updatePreviewLayoutButton()
        markdownSegmentedControl.isHidden = true
        let selectedRows = tableView.selectedRowIndexes.sorted()

        if selectedRows.count > 1 {
            let selectedItems = selectedRows.compactMap { row -> ClipItem? in
                row < displayItems.count ? displayItems[row] : nil
            }
            let texts = selectedItems.compactMap { mergeableText(from: $0, includeFiles: true) }
            let merged = texts.joined(separator: "\n")
            previewHeader.stringValue = L10n.mergePreviewTitle
            previewMetaLabel.stringValue = L10n.mergePreviewMeta(selectedRows.count)
            applyPreviewPlainText(merged, font: .monospacedSystemFont(ofSize: 12, weight: .regular))
            previewImageView.isHidden = true
            previewTextScrollView.isHidden = false
            quickLookButton.isHidden = true
            imageFitButton.isHidden = true
            ocrSectionView.isHidden = true
            colorCardContainer.isHidden = true
            urlActionBar.isHidden = true
            previewTextBottomBar.isHidden = false
            previewTextMetaLabel.stringValue = L10n.textCountInfo(chars: merged.count, lines: merged.components(separatedBy: "\n").count)
            previewTextTopToURLConstraint?.isActive = false
            previewTextTopToDividerConstraint?.isActive = true
            previewImageBottomToSectionConstraint?.isActive = false
            previewImageBottomToContainerConstraint?.isActive = true
            return
        }

        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else {
            previewHeader.stringValue = L10n.noSelection
            previewMetaLabel.stringValue = ""
            applyPreviewPlainText("", font: .systemFont(ofSize: 13))
            previewImageView.image = nil
            previewImageView.isHidden = true
            previewTextScrollView.isHidden = true
            quickLookButton.isHidden = true
            imageFitButton.isHidden = true
            ocrSectionView.isHidden = true
            colorCardContainer.isHidden = true
            urlActionBar.isHidden = true
            previewTextBottomBar.isHidden = true
            return
        }

        let item = displayItems[row]
        var time = dateFormatter.localizedString(for: item.createdAt, relativeTo: Date())
        if item.createdAt.timeIntervalSinceNow > -60 { time = L10n.justNow }
        let appPart = item.sourceAppName.map { "\(L10n.sourceFrom)\($0) • " } ?? ""

        if item.kind == .image {
            store.requestOCRIfNeeded(for: item)
            let w = item.width ?? 0
            let h = item.height ?? 0
            previewHeader.stringValue = item.displayTitle
            previewMetaLabel.stringValue = "\(appPart)\(time) • \(L10n.previewImageInfo(w: w, h: h))"

            previewImageView.image = store.previewImage(for: item)
            previewImageView.fileURLProvider = { [weak self] in
                guard let self = self else { return nil }
                return self.store.imageFileURL(for: item)
            }
            previewImageView.isHidden = false
            previewTextScrollView.isHidden = true
            colorCardContainer.isHidden = true
            urlActionBar.isHidden = true
            quickLookButton.isHidden = false
            imageFitButton.isHidden = false
            previewTextBottomBar.isHidden = true

            if store.isOCRPending(item) {
                ocrTextView.string = L10n.ocrRecognizing
                ocrSectionView.isHidden = false
                isOCRFolded = false
                applyOCRFoldLayout(animated: false)
                previewImageBottomToContainerConstraint?.isActive = false
                previewImageBottomToSectionConstraint?.isActive = true
            } else if let ocr = item.ocrText, !ocr.isEmpty {
                ocrTextView.string = ocr
                ocrSectionView.isHidden = false
                // 新条目的 OCR 默认折叠；同一条目在用户展开后刷新时保持展开。
                isOCRFolded = (expandedOCRItemID != item.id)
                applyOCRFoldLayout(animated: false)
                previewImageBottomToContainerConstraint?.isActive = false
                previewImageBottomToSectionConstraint?.isActive = true
            } else if item.ocrText != nil {
                ocrTextView.string = L10n.ocrNoText
                ocrSectionView.isHidden = false
                isOCRFolded = false
                applyOCRFoldLayout(animated: false)
                previewImageBottomToContainerConstraint?.isActive = false
                previewImageBottomToSectionConstraint?.isActive = true
            } else {
                expandedOCRItemID = nil
                isOCRFolded = true
                ocrSectionView.isHidden = true
                previewImageBottomToSectionConstraint?.isActive = false
                previewImageBottomToContainerConstraint?.isActive = true
            }
        } else if item.isColor, let color = item.colorValue {
            previewHeader.stringValue = item.displayTitle
            previewMetaLabel.stringValue = "\(appPart)\(time) • \(L10n.typeColorCode)"
            quickLookButton.isHidden = true
            imageFitButton.isHidden = true
            previewImageView.isHidden = true
            ocrSectionView.isHidden = true
            urlActionBar.isHidden = true
            previewTextBottomBar.isHidden = true

            // 配置颜色卡片
            colorSwatchView.layer?.backgroundColor = color.cgColor
            colorHexLabel.stringValue = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            colorRgbLabel.stringValue = "RGB: " + (item.colorRGBString ?? "")
            colorHslLabel.stringValue = "HSL: " + (item.colorHSLString ?? "")
            colorCardContainer.isHidden = false

            previewTextScrollView.isHidden = true
        } else if item.isURL {
            previewHeader.stringValue = item.displayTitle
            previewMetaLabel.stringValue = "\(appPart)\(time) • \(L10n.typeWebLink)"
            quickLookButton.isHidden = true
            imageFitButton.isHidden = true
            previewImageView.isHidden = true
            ocrSectionView.isHidden = true
            colorCardContainer.isHidden = true

            // 配置 URL 动作条
            urlHostLabel.stringValue = "🌐 " + (item.urlHost ?? (item.text ?? ""))
            urlActionBar.isHidden = false

            previewTextTopToDividerConstraint?.isActive = false
            previewTextTopToURLConstraint?.isActive = true
            let urlText = item.text ?? ""
            applyPreviewPlainTextCached(urlText, font: .systemFont(ofSize: 13), itemID: item.id)
            previewTextScrollView.isHidden = false
            previewTextBottomBar.isHidden = false
            previewTextMetaLabel.stringValue = L10n.textCountInfo(chars: urlText.count, lines: 1)
        } else if item.kind == .file {
            previewHeader.stringValue = item.displayTitle
            previewMetaLabel.stringValue = "\(appPart)\(time) • \(L10n.typeFile) • \(fileSubtitle(for: item))"
            quickLookButton.isHidden = false
            imageFitButton.isHidden = true
            previewImageView.isHidden = true
            ocrSectionView.isHidden = true
            colorCardContainer.isHidden = true
            urlActionBar.isHidden = true

            previewTextTopToURLConstraint?.isActive = false
            previewTextTopToDividerConstraint?.isActive = true

            let pathsText = item.filePaths?.joined(separator: "\n") ?? ""
            applyPreviewPlainTextCached(
                pathsText,
                font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                itemID: item.id
            )
            previewTextScrollView.isHidden = false
            previewTextBottomBar.isHidden = false
            previewTextMetaLabel.stringValue = L10n.fileItemsCount(item.fileCount)
        } else {
            // 普通文本或代码/JSON
            quickLookButton.isHidden = true
            imageFitButton.isHidden = true
            previewImageView.isHidden = true
            ocrSectionView.isHidden = true
            colorCardContainer.isHidden = true
            urlActionBar.isHidden = true
            previewTextTopToURLConstraint?.isActive = false
            previewTextTopToDividerConstraint?.isActive = true

            let rawText = item.text ?? ""
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

            // 智能 JSON 美化排版判断
            var isBeautifiedJSON = false
            var displayText = rawText
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")),
               let beautified = TextTransformer.beautifyJSON(rawText) {
                previewHeader.stringValue = item.alias ?? L10n.typeJSON
                displayText = beautified
                isBeautifiedJSON = true
            } else {
                previewHeader.stringValue = item.displayTitle
            }

            let detectedLang = isBeautifiedJSON ? CodeLanguage.json : SyntaxHighlighter.detectLanguage(displayText)

            let isMarkdown = (detectedLang == .markdown)
            markdownSegmentedControl.isHidden = !isMarkdown
            let desiredSegment = isMarkdownPreviewMode ? 0 : 1
            if markdownSegmentedControl.selectedSegment != desiredSegment {
                markdownSegmentedControl.selectedSegment = desiredSegment
            }

            previewCodeBlocks = []
            if isMarkdown && isMarkdownPreviewMode {
                let rendered = MarkdownRenderer.render(displayText, baseFontSize: 13)
                previewCodeBlocks = rendered.codeBlocks
                cacheAndApplyPreviewBase(rendered.text, itemID: item.id)
            } else if isMarkdown {
                // Raw：必须整段替换成无链接、无旧色的纯文本，否则会残留 Preview 里的红色/粉色代码色。
                applyPreviewPlainTextCached(
                    displayText,
                    font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                    itemID: item.id
                )
            } else if let lang = detectedLang {
                let highlighted = SyntaxHighlighter.highlight(code: displayText, language: lang, fontSize: 12)
                cacheAndApplyPreviewBase(highlighted, itemID: item.id)
            } else {
                let font: NSFont = displayText.contains("\n")
                    ? .monospacedSystemFont(ofSize: 12, weight: .regular)
                    : .systemFont(ofSize: 13)
                applyPreviewPlainTextCached(displayText, font: font, itemID: item.id)
            }

            var typeName = detectedLang?.displayName ?? L10n.typePlainText
            if isMarkdown {
                typeName = isMarkdownPreviewMode ? L10n.markdownTypePreview : L10n.markdownTypeRaw
            }
            let cCount = rawText.count
            let lCount = rawText.components(separatedBy: "\n").count
            var meta = "\(appPart)\(time) • \(typeName)"
            if item.richFormatDropped {
                meta += " • " + L10n.richFormatDroppedShort
            }
            previewMetaLabel.stringValue = meta
            previewTextMetaLabel.stringValue = L10n.textCountInfo(chars: cCount, lines: lCount)
            previewTextBottomBar.isHidden = false
            previewTextScrollView.isHidden = false
        }
    }

    // MARK: - 颜色色值拷贝

    @objc private func copyColorHex() {
        guard let row = selectedOrClickedRow, row < displayItems.count else { return }
        let item = displayItems[row]
        guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        copyStringToPasteboard(text)
    }

    @objc private func copyColorRGB() {
        guard let row = selectedOrClickedRow, row < displayItems.count else { return }
        let item = displayItems[row]
        guard let rgb = item.colorRGBString else { return }
        copyStringToPasteboard(rgb)
    }

    @objc private func copyColorHSL() {
        guard let row = selectedOrClickedRow, row < displayItems.count else { return }
        let item = displayItems[row]
        guard let hsl = item.colorHSLString else { return }
        copyStringToPasteboard(hsl)
    }

    private func copyStringToPasteboard(_ str: String) {
        ClipboardStore.shared.writeStringToPasteboard(str)
        triggerHaptic()
    }

    private var selectedOrClickedRow: Int? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        return (row >= 0 && row < displayItems.count) ? row : nil
    }

    // MARK: - 数据检索与列表联动

    private func invalidateSearchHaystackCache() {
        searchHaystackCache.removeAll(keepingCapacity: true)
    }

    private func cachedSearchHaystack(for item: ClipItem) -> String {
        if let cached = searchHaystackCache[item.id] {
            return cached
        }
        let haystack = item.searchHaystack()
        searchHaystackCache[item.id] = haystack
        return haystack
    }

    private func invalidatePreviewBaseCache() {
        previewBaseAttributedCache = nil
        previewBaseCacheItemID = nil
        previewBaseCacheMarkdownPreviewMode = nil
    }

    private func itemMatchesSearch(_ item: ClipItem, tokens: [String]) -> Bool {
        _ = cachedSearchHaystack(for: item)
        return item.matchesSearchTokens(tokens)
    }

    private func baseItemsForCurrentCategory() -> [ClipItem] {
        var baseItems = store.items
        switch currentCategory {
        case .all:
            break
        case .text:
            baseItems = baseItems.filter { $0.kind == .text && !$0.isURL }
        case .image:
            baseItems = baseItems.filter { $0.kind == .image }
        case .file:
            baseItems = baseItems.filter { $0.kind == .file }
        case .link:
            baseItems = baseItems.filter { $0.isURL }
        case .pinned:
            baseItems = baseItems.filter { $0.pinned }
        }
        return baseItems
    }

    private func reloadVisibleTableRows() {
        guard !displayItems.isEmpty else {
            tableView.reloadData()
            return
        }
        let visible = tableView.rows(in: tableView.visibleRect)
        var rows = IndexSet()
        for row in visible.location..<(visible.location + visible.length) {
            if row >= 0, row < displayItems.count {
                rows.insert(row)
            }
        }
        if rows.isEmpty {
            rows.insert(0)
        }
        tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
    }

    private func setSearchFilteringPending(_ pending: Bool) {
        if pending, !searchField.stringValue.isEmpty {
            searchField.toolTip = L10n.searchFiltering
        } else if searchField.toolTip == L10n.searchFiltering {
            searchField.toolTip = nil
        }
    }

    private func refreshPreviewSearchHighlightsOnly() -> Bool {
        guard isPreviewVisible,
              tableView.selectedRowIndexes.count == 1,
              let row = tableView.selectedRowIndexes.first,
              row >= 0, row < displayItems.count,
              let base = previewBaseAttributedCache,
              let cacheItemID = previewBaseCacheItemID,
              previewBaseCacheMarkdownPreviewMode == isMarkdownPreviewMode else {
            return false
        }
        let item = displayItems[row]
        guard item.id == cacheItemID else { return false }

        let highlighted = currentSearchTokens.isEmpty
            ? base
            : SyntaxHighlighter.highlightMatches(in: base, tokens: currentSearchTokens)
        applyPreviewAttributedText(highlighted)
        return true
    }

    private func reload(preferTop: Bool = false, previewHighlightsOnly: Bool = false) {
        searchFilterGeneration += 1
        setSearchFilteringPending(false)
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentSearchTokens = tokens
        let baseItems = baseItemsForCurrentCategory()
        let filtered: [ClipItem]
        if tokens.isEmpty {
            filtered = baseItems
        } else {
            filtered = baseItems.filter { $0.matchesSearchTokens(tokens) }
        }
        applyFilterResults(filtered, query: query, preferTop: preferTop, previewHighlightsOnly: previewHighlightsOnly)
    }

    private func applyFilterResults(
        _ filtered: [ClipItem],
        query: String,
        preferTop: Bool,
        previewHighlightsOnly: Bool
    ) {
        let previousIDs: [UUID] = tableView.selectedRowIndexes.sorted().compactMap { idx in
            (idx >= 0 && idx < displayItems.count) ? displayItems[idx].id : nil
        }
        let oldDisplayIDs = displayItems.map(\.id)
        displayItems = filtered
        lastDisplayItemIDs = filtered.map(\.id)

        let idsUnchanged = oldDisplayIDs == lastDisplayItemIDs
        if previewHighlightsOnly, idsUnchanged {
            reloadVisibleTableRows()
        } else {
            tableView.reloadData()
        }

        var newSelection = IndexSet()
        if !preferTop {
            for (index, item) in displayItems.enumerated() where previousIDs.contains(item.id) {
                newSelection.insert(index)
            }
        }
        if newSelection.isEmpty, !displayItems.isEmpty {
            newSelection.insert(0)
        }
        if !newSelection.isEmpty {
            tableView.selectRowIndexes(newSelection, byExtendingSelection: false)
            let scrollID = previousIDs.first { id in displayItems.contains { $0.id == id } }
            let scrollIndex = scrollID.flatMap { id in displayItems.firstIndex { $0.id == id } } ?? newSelection.min()
            if let scrollIndex {
                tableView.scrollRowToVisible(scrollIndex)
            }
        }

        if displayItems.isEmpty, !store.items.isEmpty, !query.isEmpty {
            emptyLabel.stringValue = L10n.emptyFilteredHint(store.items.count)
        } else {
            emptyLabel.stringValue = query.isEmpty
                ? (currentCategory == .all ? L10n.emptyHistory : L10n.emptyCategory)
                : L10n.emptySearch
        }
        emptyLabel.isHidden = !displayItems.isEmpty
        if previewHighlightsOnly, refreshPreviewSearchHighlightsOnly() {
            updateBottomHint()
            return
        }
        if !previewHighlightsOnly {
            invalidatePreviewBaseCache()
        }
        updatePreview()
        updateBottomHint()
    }

    private func scheduleSearchReload() {
        searchReloadWorkItem?.cancel()
        setSearchFilteringPending(true)
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let baseItems = baseItemsForCurrentCategory()
        let useBackground = store.items.count >= 80 && !tokens.isEmpty

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if useBackground {
                let generation = self.searchFilterGeneration + 1
                self.searchFilterGeneration = generation
                self.searchFilterQueue.async { [weak self] in
                    guard let self else { return }
                    let filtered = baseItems.filter { $0.matchesSearchTokens(tokens) }
                    DispatchQueue.main.async { [weak self] in
                        guard let self, generation == self.searchFilterGeneration else { return }
                        self.currentSearchTokens = tokens
                        self.setSearchFilteringPending(false)
                        self.applyFilterResults(filtered, query: query, preferTop: false, previewHighlightsOnly: true)
                    }
                }
            } else {
                self.reload(previewHighlightsOnly: true)
                self.setSearchFilteringPending(false)
            }
        }
        searchReloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    /// 粘贴 / 回车前强制与搜索框同步，避免防抖导致贴错条目。
    func flushPendingSearchReload() {
        searchReloadWorkItem?.cancel()
        searchReloadWorkItem = nil
        searchFilterGeneration += 1
        setSearchFilteringPending(false)
        reload(previewHighlightsOnly: false)
    }

    private func updateBottomHint() {
        guard bottomHintLabel != nil else { return }
        if showsDeleteUndoHint, store.canUndoDelete {
            bottomHintLabel.stringValue = L10n.bottomHintDeleteUndo
            pastePrimaryButton.title = L10n.primaryPaste
            return
        }
        showsDeleteUndoHint = false
        let count = tableView.selectedRowIndexes.count
        if count > 1 {
            bottomHintLabel.stringValue = L10n.bottomHintMultiSelected(count)
            pastePrimaryButton.title = L10n.isChinese ? "↵ 合并粘贴" : "↵ Merge Paste"
        } else {
            bottomHintLabel.stringValue = L10n.bottomHintUpdated
            pastePrimaryButton.title = L10n.primaryPaste
        }
    }

    func reloadVisibleRows() {
        tableView.reloadData()
        updateBottomHint()
    }

    func handleUndoDeleteDidRestore() {
        guard panel.isVisible else { return }
        showsDeleteUndoHint = false
        invalidateSearchHaystackCache()
        reload()
    }

    func controlTextDidChange(_ obj: Notification) {
        scheduleSearchReload()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            selectNextRow()
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            selectPreviousRow()
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                shiftReturnPressed()
            } else {
                returnPressed()
            }
            return true
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            cycleCategory(forward: true)
            return true
        } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            cycleCategory(forward: false)
            return true
        }
        return false
    }

    private func selectNextRow() {
        guard !displayItems.isEmpty else { return }
        let current = tableView.selectedRow
        let next = (current + 1 < displayItems.count) ? current + 1 : 0
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func selectPreviousRow() {
        guard !displayItems.isEmpty else { return }
        let current = tableView.selectedRow
        let prev = (current > 0) ? current - 1 : displayItems.count - 1
        tableView.selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
        tableView.scrollRowToVisible(prev)
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayItems.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        invalidatePreviewBaseCache()
        updatePreview()
        updateBottomHint()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = displayItems[row]
        let cell = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("row"), owner: nil) as? NSTableCellView) ?? makeRowCell()

        if let icon = cell.viewWithTag(100) as? NSImageView,
           let main = cell.viewWithTag(101) as? NSTextField,
           let sub = cell.viewWithTag(102) as? NSTextField,
           let badge = cell.viewWithTag(103) as? NSTextField {

            cell.toolTip = nil

            var time = dateFormatter.localizedString(for: item.createdAt, relativeTo: Date())
            if item.createdAt.timeIntervalSinceNow > -60 { time = L10n.justNow }
            let pinPrefix = item.pinned ? "📌  " : ""
            let appSuffix = item.sourceAppName.map { " • \($0)" } ?? ""

            if let alias = item.alias, !alias.isEmpty {
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(alias, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13, weight: .semibold), baseColor: .labelColor)
                } else {
                    main.stringValue = alias
                    main.font = .systemFont(ofSize: 13, weight: .semibold)
                }
                if item.kind == .image {
                    icon.image = store.image(for: item)
                    icon.contentTintColor = nil
                    sub.stringValue = pinPrefix + "\(L10n.imageLabel) \(item.width ?? 0)×\(item.height ?? 0) • " + time + appSuffix
                } else {
                    icon.image = NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: L10n.snippet)?
                        .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
                    icon.contentTintColor = .systemOrange
                    sub.stringValue = pinPrefix + item.previewText + " • " + time + appSuffix
                }
            } else if item.kind == .image {
                icon.image = store.image(for: item)
                icon.contentTintColor = nil
                let imgTitle = "\(L10n.imageLabel) \(item.width ?? 0)×\(item.height ?? 0)"
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(imgTitle, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13), baseColor: .labelColor)
                } else {
                    main.stringValue = imgTitle
                    main.font = .systemFont(ofSize: 13, weight: .regular)
                }
                if store.isOCRPending(item) {
                    sub.stringValue = pinPrefix + L10n.ocrRecognizing + " • " + time + appSuffix
                    cell.toolTip = nil
                } else if let ocr = item.ocrText, !ocr.isEmpty {
                    sub.stringValue = pinPrefix + "OCR • " + time + appSuffix
                    cell.toolTip = ocr
                } else if item.ocrText != nil {
                    sub.stringValue = pinPrefix + L10n.ocrNoText + " • " + time + appSuffix
                    cell.toolTip = nil
                } else {
                    sub.stringValue = pinPrefix + "\(L10n.typeImage) • " + time + appSuffix
                    cell.toolTip = nil
                }
            } else if item.isColor, let color = item.colorValue {
                icon.image = createColorSwatch(color: color, size: CGSize(width: 24, height: 24))
                icon.contentTintColor = nil
                let colTitle = item.text ?? ""
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(colTitle, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13), baseColor: .labelColor)
                } else {
                    main.stringValue = colTitle
                    main.font = .systemFont(ofSize: 13, weight: .regular)
                }
                sub.stringValue = pinPrefix + "\(L10n.typeColor) • " + time + appSuffix
            } else if item.isURL {
                if let appIcon = store.appIcon(for: item.sourceAppBundleId) {
                    icon.image = appIcon
                    icon.contentTintColor = nil
                } else {
                    icon.image = NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: L10n.catLink)?
                        .withSymbolConfiguration(.init(pointSize: 17, weight: .medium))
                    icon.contentTintColor = .systemBlue
                }
                let rawTitle = item.previewText
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(rawTitle, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13), baseColor: .labelColor)
                } else {
                    main.stringValue = rawTitle
                    main.font = .systemFont(ofSize: 13, weight: .regular)
                }
                sub.stringValue = pinPrefix + "\(L10n.typeLinkHint) • " + time + appSuffix
            } else if item.kind == .file {
                if let path = item.firstFilePath {
                    icon.image = NSWorkspace.shared.icon(forFile: path)
                    icon.contentTintColor = nil
                } else {
                    icon.image = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: L10n.catFile)?
                        .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
                    icon.contentTintColor = .systemBlue
                }
                let rawTitle = item.displayTitle
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(rawTitle, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13), baseColor: .labelColor)
                } else {
                    main.stringValue = rawTitle
                    main.font = .systemFont(ofSize: 13, weight: .regular)
                }
                sub.stringValue = pinPrefix + fileSubtitle(for: item) + " • " + time + appSuffix
                cell.toolTip = item.filePaths?.joined(separator: "\n")
            } else {
                if let appIcon = store.appIcon(for: item.sourceAppBundleId) {
                    icon.image = appIcon
                    icon.contentTintColor = nil
                } else {
                    icon.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: L10n.catText)?
                        .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
                    icon.contentTintColor = .secondaryLabelColor
                }
                let rawTitle = item.previewText
                if !currentSearchTokens.isEmpty {
                    main.attributedStringValue = SyntaxHighlighter.highlightText(rawTitle, tokens: currentSearchTokens, baseFont: .systemFont(ofSize: 13), baseColor: .labelColor)
                } else {
                    main.stringValue = rawTitle
                    main.font = .systemFont(ofSize: 13, weight: .regular)
                }
                var subLine = pinPrefix + time + appSuffix
                if item.richFormatDropped {
                    subLine += " • " + L10n.richFormatDroppedShort
                }
                sub.stringValue = subLine
                cell.toolTip = nil
            }

            if row < 9, L10n.isQuickPasteEnabled {
                badge.stringValue = "⌘\(row + 1)"
                badge.isHidden = false
            } else {
                badge.stringValue = ""
                badge.isHidden = true
            }

            applyRowAccessibility(cell, item: item, row: row, title: main.stringValue.isEmpty ? item.displayTitle : main.stringValue)
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard row >= 0, row < displayItems.count else { return nil }
        let item = displayItems[row]
        if item.kind == .text, let text = item.text {
            return text as NSString
        } else if item.kind == .image, let fileURL = store.imageFileURL(for: item) {
            return fileURL as NSURL
        } else if item.kind == .file, let first = item.existingFilePaths.first {
            return URL(fileURLWithPath: first) as NSURL
        }
        return nil
    }

    private func makeRowCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = NSUserInterfaceItemIdentifier("row")

        let icon = NSImageView()
        icon.tag = 100
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 6
        icon.layer?.masksToBounds = true

        let main = NSTextField(labelWithString: "")
        main.tag = 101
        main.font = .systemFont(ofSize: 13)
        main.maximumNumberOfLines = 1
        main.cell?.usesSingleLineMode = true
        main.cell?.lineBreakMode = .byTruncatingTail
        main.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        main.translatesAutoresizingMaskIntoConstraints = false

        let sub = NSTextField(labelWithString: "")
        sub.tag = 102
        sub.font = .systemFont(ofSize: 11)
        sub.textColor = .secondaryLabelColor
        sub.maximumNumberOfLines = 1
        sub.cell?.usesSingleLineMode = true
        sub.cell?.lineBreakMode = .byTruncatingTail
        sub.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sub.translatesAutoresizingMaskIntoConstraints = false

        let shortcutBadge = NSTextField(labelWithString: "")
        shortcutBadge.tag = 103
        shortcutBadge.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        shortcutBadge.textColor = .tertiaryLabelColor
        shortcutBadge.alignment = .right
        shortcutBadge.maximumNumberOfLines = 1
        shortcutBadge.cell?.usesSingleLineMode = true
        shortcutBadge.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(icon)
        cell.addSubview(main)
        cell.addSubview(sub)
        cell.addSubview(shortcutBadge)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),

            shortcutBadge.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            shortcutBadge.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            shortcutBadge.widthAnchor.constraint(equalToConstant: 30),

            main.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            main.trailingAnchor.constraint(equalTo: shortcutBadge.leadingAnchor, constant: -6),
            main.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
            main.heightAnchor.constraint(equalToConstant: 18),

            sub.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            sub.trailingAnchor.constraint(equalTo: shortcutBadge.leadingAnchor, constant: -6),
            sub.topAnchor.constraint(equalTo: main.bottomAnchor, constant: 2),
            sub.heightAnchor.constraint(equalToConstant: 16),
        ])

        icon.setAccessibilityElement(false)
        main.setAccessibilityElement(false)
        sub.setAccessibilityElement(false)
        shortcutBadge.setAccessibilityElement(false)
        return cell
    }

    private func applyRowAccessibility(_ cell: NSView, item: ClipItem, row: Int, title: String) {
        var kind = L10n.rowKindText
        if item.kind == .image {
            kind = L10n.rowKindImage
        } else if item.kind == .file {
            kind = L10n.rowKindFile
        } else if item.isURL {
            kind = L10n.rowKindLink
        } else if item.isColor {
            kind = L10n.rowKindColor
        }

        var parts = [kind]
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        } else if item.kind == .image {
            parts.append("\(item.width ?? 0)×\(item.height ?? 0)")
        }
        if item.pinned {
            parts.append(L10n.pinned)
        }
        if row < 9, L10n.isQuickPasteEnabled {
            parts.append(L10n.quickPasteHint(row + 1))
        }

        cell.setAccessibilityElement(true)
        cell.setAccessibilityRole(.group)
        cell.setAccessibilityLabel(parts.joined(separator: ", "))
    }

    private func createColorSwatch(color: NSColor, size: CGSize) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            color.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        return img
    }

    private func fileSubtitle(for item: ClipItem) -> String {
        if item.allFilesMissing {
            return L10n.fileMissing
        }
        if item.hasMissingFiles {
            let size = item.fileTotalSizeFormatted
            return size.isEmpty ? L10n.filePartiallyMissing : "\(L10n.filePartiallyMissing) • \(size)"
        }
        return item.fileTotalSizeFormatted
    }

    private func triggerHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    // MARK: - 动作

    @objc private func rowClicked() {
        // 单击只选中
    }

    func activateRow(_ row: Int, plainTextOnly: Bool = false) {
        flushPendingSearchReload()
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        hidePanel()
        triggerHaptic()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard ClipboardStore.shared.writeToPasteboard(item, plainTextOnly: plainTextOnly) else {
                NSSound.beep()
                return
            }
            ClipboardStore.shared.performPasteIfEnabled()
        }
    }

    @objc private func activateSelectedAction() {
        activateSelected(plainTextOnly: false, separator: "\n")
    }

    @objc private func mergeWithNewline() {
        activateSelected(plainTextOnly: false, separator: "\n")
    }

    @objc private func mergeWithComma() {
        activateSelected(plainTextOnly: false, separator: ", ")
    }

    @objc private func mergeWithSpace() {
        activateSelected(plainTextOnly: false, separator: " ")
    }

    @objc private func mergeWithNone() {
        activateSelected(plainTextOnly: false, separator: "")
    }

    func shiftReturnPressed() {
        activateSelected(plainTextOnly: false, separator: ", ")
    }

    @objc private func activateSelected(plainTextOnly: Bool = false, separator: String = "\n") {
        flushPendingSearchReload()
        let selectedRows = tableView.selectedRowIndexes.sorted()
        if selectedRows.count > 1 {
            // 合并多选粘贴
            let selectedItems = selectedRows.compactMap { row -> ClipItem? in
                row < displayItems.count ? displayItems[row] : nil
            }
            let texts = selectedItems.compactMap { mergeableText(from: $0, includeFiles: true) }
            guard !texts.isEmpty else {
                NSSound.beep()
                flashActionHint(L10n.mergeNoPasteableContent)
                return
            }
            let merged = texts.joined(separator: separator)
            hidePanel()
            triggerHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                ClipboardStore.shared.writeStringToPasteboard(merged)
                ClipboardStore.shared.performPasteIfEnabled()
            }
            return
        }

        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        activateRow(row, plainTextOnly: plainTextOnly)
    }

    @objc private func pastePlainTextRow() {
        activateSelected(plainTextOnly: true, separator: "\n")
    }

    @objc func copySelectedOnly() {
        let selectedRows = tableView.selectedRowIndexes.sorted()
        if selectedRows.count > 1 {
            let selectedItems = selectedRows.compactMap { row -> ClipItem? in
                row < displayItems.count ? displayItems[row] : nil
            }
            let texts = selectedItems.compactMap { mergeableText(from: $0, includeFiles: true) }
            if !texts.isEmpty {
                let merged = texts.joined(separator: "\n")
                ClipboardStore.shared.writeStringToPasteboard(merged)
                triggerHaptic()
                hidePanel()
            } else {
                NSSound.beep()
                flashActionHint(L10n.copyNoPasteableContent)
            }
            return
        }

        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        guard store.writeToPasteboard(item) else {
            NSSound.beep()
            flashActionHint(L10n.copyNoPasteableContent)
            return
        }
        triggerHaptic()
        hidePanel()
    }

    @objc func openSelectedURL() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        if item.isURL, let str = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: str) {
            NSWorkspace.shared.open(url)
            triggerHaptic()
            hidePanel()
        } else if item.kind == .file {
            let path = item.existingFilePaths.first ?? item.firstFilePath
            guard let path else {
                NSSound.beep()
                return
            }
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            triggerHaptic()
            hidePanel()
        }
    }

    func returnPressed() {
        activateSelected(plainTextOnly: false)
    }

    func deletePressed() {
        flushPendingSearchReload()
        let selectedRows = tableView.selectedRowIndexes.sorted()
        guard !selectedRows.isEmpty else { return }
        let nextIndex = selectedRows.first ?? 0
        let toRemove = selectedRows.compactMap { row -> ClipItem? in
            row < displayItems.count ? displayItems[row] : nil
        }
        let removedCount = store.removeItemsForUndo(toRemove)
        guard removedCount > 0 else { return }
        showsDeleteUndoHint = true
        reload()
        if !displayItems.isEmpty {
            let idx = min(nextIndex, displayItems.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
        updateBottomHint()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.flashStatusMessage(L10n.deleteUndoFlash(removedCount), duration: 3.0)
        }
    }

    @objc private func togglePinRow() {
        let selectedRows = tableView.selectedRowIndexes.sorted()
        if selectedRows.count > 1 {
            for row in selectedRows {
                if row < displayItems.count {
                    store.togglePin(displayItems[row])
                }
            }
        } else {
            let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard row >= 0, row < displayItems.count else { return }
            store.togglePin(displayItems[row])
        }
        reload()
    }

    @objc private func deleteRow() {
        deletePressed()
    }

    @objc private func clearAllRows() {
        let alert = NSAlert()
        alert.messageText = L10n.clearHistoryConfirmTitle
        alert.informativeText = L10n.clearHistoryConfirmMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.clearHistoryConfirmAction)
        alert.addButton(withTitle: L10n.cancel)
        panel.makeKeyAndOrderFront(nil)
        if alert.runModal() == .alertFirstButtonReturn {
            let count = store.clearForUndo(preservePinned: true)
            showsDeleteUndoHint = true
            reload()
            updateBottomHint()
            if count > 0, let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.flashStatusMessage(L10n.clearUndoFlash(count), duration: 3.0)
            }
        }
    }

    @objc private func promptEditText() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        guard item.kind == .text else { return }

        let alert = NSAlert()
        alert.messageText = L10n.editTextTitle
        alert.alertStyle = .informational

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: scroll.contentView.bounds)
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = item.text ?? ""
        textView.autoresizingMask = [.width, .height]
        scroll.documentView = textView
        alert.accessoryView = scroll

        alert.addButton(withTitle: L10n.save)
        alert.addButton(withTitle: L10n.cancel)
        panel.makeKeyAndOrderFront(nil)
        if alert.runModal() == .alertFirstButtonReturn {
            store.updateText(textView.string, for: item)
            invalidateSearchHaystackCache()
            reload()
        }
    }

    // MARK: - 粘贴队列 (Sequential Paste Queue)

    @objc func startQueueFIFO() {
        startQueue(withOrder: .fifo)
    }

    @objc func startQueueLIFO() {
        startQueue(withOrder: .lifo)
    }

    @objc func startQueueSelection() {
        startQueue(withOrder: .selection)
    }

    @objc private func startQueueWithSelected() {
        startQueue(withOrder: store.queueOrder)
    }

    private func startQueue(withOrder order: ClipboardStore.QueueOrder) {
        let selectedRows = tableView.selectedRowIndexes.sorted()
        let itemsToQueue: [ClipItem]
        if selectedRows.count > 1 {
            itemsToQueue = selectedRows.compactMap { row in
                row < displayItems.count ? displayItems[row] : nil
            }
        } else {
            let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard row >= 0, row < displayItems.count else { return }
            itemsToQueue = [displayItems[row]]
        }
        guard !itemsToQueue.isEmpty else { return }
        store.startQueue(with: itemsToQueue, order: order)
        hidePanel()
    }

    func selectAllRows() {
        guard !displayItems.isEmpty else { return }
        let all = IndexSet(integersIn: 0..<displayItems.count)
        tableView.selectRowIndexes(all, byExtendingSelection: false)
    }

    @objc private func stopPasteQueue() {
        store.clearQueue()
    }

    // MARK: - 别名与代码片段命名 (Snippets / Alias)

    @objc private func promptSetAlias() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]

        let alert = NSAlert()
        alert.messageText = L10n.setAliasTitle
        alert.informativeText = L10n.setAliasPrompt
        alert.alertStyle = .informational

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = item.alias ?? ""
        alert.accessoryView = input

        alert.addButton(withTitle: L10n.save)
        alert.addButton(withTitle: L10n.cancel)
        if item.alias != nil {
            alert.addButton(withTitle: L10n.clearAlias)
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            store.setAlias(text.isEmpty ? nil : text, for: item)
            reload()
        } else if response == .alertThirdButtonReturn {
            store.setAlias(nil, for: item)
            reload()
        }
    }

    // MARK: - OCR 复制

    @objc private func copyOCRTextRow() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        guard let ocr = item.ocrText, !ocr.isEmpty else { return }
        ClipboardStore.shared.writeStringToPasteboard(ocr)
        triggerHaptic()
        hidePanel()
    }

    @objc private func copyPreviewOCRText() {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        guard let ocr = item.ocrText, !ocr.isEmpty else { return }
        ClipboardStore.shared.writeStringToPasteboard(ocr)
        triggerHaptic()
    }

    // MARK: - 文本格式转换 (Text Transformations)

    @objc private func transformJSONBeautify() {
        guard let text = getTargetText(), let result = TextTransformer.beautifyJSON(text) else {
            NSSound.beep()
            return
        }
        applyTransformedText(result)
    }

    @objc private func transformJSONMinify() {
        guard let text = getTargetText(), let result = TextTransformer.minifyJSON(text) else {
            NSSound.beep()
            return
        }
        applyTransformedText(result)
    }

    @objc private func transformToCamelCase() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.toCamelCase(text))
    }

    @objc private func transformToSnakeCase() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.toSnakeCase(text))
    }

    @objc private func transformToKebabCase() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.toKebabCase(text))
    }

    @objc private func transformToUpperCase() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.toUpperCase(text))
    }

    @objc private func transformToLowerCase() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.toLowerCase(text))
    }

    @objc private func transformURLEncode() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.urlEncode(text))
    }

    @objc private func transformURLDecode() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.urlDecode(text))
    }

    @objc private func transformBase64Encode() {
        guard let text = getTargetText() else { return }
        applyTransformedText(TextTransformer.base64Encode(text))
    }

    @objc private func transformBase64Decode() {
        guard let text = getTargetText(), let result = TextTransformer.base64Decode(text) else {
            NSSound.beep()
            return
        }
        applyTransformedText(result)
    }

    private func getTargetText() -> String? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return nil }
        let item = displayItems[row]
        if item.kind == .text { return item.text }
        if let ocr = item.ocrText, !ocr.isEmpty { return ocr }
        return nil
    }

    private func applyTransformedText(_ newText: String) {
        store.addTextEntry(newText)
        if let first = store.items.first {
            store.writeToPasteboard(first)
        }
        triggerHaptic()
        reload()
    }

    // MARK: - 原生 Quick Look 全尺寸大图与文件预览

    @objc func openFullSizeQuickLook() {
        let row = tableView.selectedRow >= 0 ? tableView.selectedRow : tableView.clickedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        if item.kind == .image, let url = store.imageFileURL(for: item) {
            QuickLookManager.shared.preview(url: url, title: item.displayTitle)
        } else if item.kind == .file, let first = item.existingFilePaths.first {
            QuickLookManager.shared.preview(url: URL(fileURLWithPath: first), title: item.displayTitle)
        }
    }

    @objc private func openInPreviewApp() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        let item = displayItems[row]
        if item.kind == .image, let url = store.imageFileURL(for: item) {
            QuickLookManager.shared.openInDefaultApp(url: url)
        } else if item.kind == .file, let first = item.existingFilePaths.first {
            NSWorkspace.shared.selectFile(first, inFileViewerRootedAtPath: "")
        }
    }
}
