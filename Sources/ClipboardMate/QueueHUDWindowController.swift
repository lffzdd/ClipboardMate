import AppKit

/// 队列悬浮窗自定义 Panel（保证非激活、不抢焦点）
final class QueueHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 填表队列微型屏幕悬浮 HUD 窗口控制器 (Floating Queue Pill / HUD)
final class QueueHUDWindowController: NSObject {
    static let shared = QueueHUDWindowController()

    private var panel: QueueHUDPanel!
    private var visualEffect: NSVisualEffectView!

    // UI 组件
    private var headerIconLabel: NSTextField!
    private var modeTitleLabel: NSTextField!
    private var counterBadgeLabel: NSTextField!
    private var counterBadgeView: NSView!
    private var closeButton: NSButton!

    private var activeCardView: NSView!
    private var activeIconView: NSImageView!
    private var activeMainLabel: NSTextField!
    private var activeTagLabel: NSTextField!

    private var upcomingContainerView: NSView!
    private var upcomingStackView: NSStackView!

    private var bottomHintLabel: NSTextField!

    private var dragStartLocation: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero

    private var autoDismissWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let defaultWidth: CGFloat = 380
        let defaultHeight: CGFloat = 136

        panel = QueueHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false

        // 毛玻璃背景
        visualEffect = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.25).cgColor
        visualEffect.layer?.borderWidth = 0.8
        visualEffect.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(visualEffect)

        setupSubviews()
        positionPanel()
        setupDragHandling()
    }

    private func setupSubviews() {
        // --- 顶部状态栏 ---
        let headerRow = NSView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(headerRow)

        headerIconLabel = NSTextField(labelWithString: "📋")
        headerIconLabel.font = .systemFont(ofSize: 13)
        headerIconLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(headerIconLabel)

        modeTitleLabel = NSTextField(labelWithString: L10n.queueHUDTitle)
        modeTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        modeTitleLabel.textColor = .labelColor
        modeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(modeTitleLabel)

        counterBadgeView = NSView()
        counterBadgeView.translatesAutoresizingMaskIntoConstraints = false
        counterBadgeView.wantsLayer = true
        counterBadgeView.layer?.cornerRadius = 9
        counterBadgeView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        headerRow.addSubview(counterBadgeView)

        counterBadgeLabel = NSTextField(labelWithString: "0 / 0")
        counterBadgeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        counterBadgeLabel.textColor = .controlAccentColor
        counterBadgeLabel.alignment = .center
        counterBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        counterBadgeView.addSubview(counterBadgeLabel)

        closeButton = NSButton(title: "✕", target: self, action: #selector(handleCloseClicked))
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 11, weight: .medium)
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.toolTip = L10n.clearQueue
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(closeButton)

        // --- 当前待粘贴项核心卡片 ---
        activeCardView = NSView()
        activeCardView.translatesAutoresizingMaskIntoConstraints = false
        activeCardView.wantsLayer = true
        activeCardView.layer?.cornerRadius = 8
        activeCardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
        activeCardView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.28).cgColor
        activeCardView.layer?.borderWidth = 1.0
        visualEffect.addSubview(activeCardView)

        activeIconView = NSImageView()
        activeIconView.imageScaling = .scaleProportionallyUpOrDown
        activeIconView.translatesAutoresizingMaskIntoConstraints = false
        activeCardView.addSubview(activeIconView)

        activeMainLabel = NSTextField(labelWithString: "")
        activeMainLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        activeMainLabel.textColor = .labelColor
        activeMainLabel.maximumNumberOfLines = 1
        activeMainLabel.cell?.lineBreakMode = .byTruncatingTail
        activeMainLabel.cell?.usesSingleLineMode = true
        activeMainLabel.translatesAutoresizingMaskIntoConstraints = false
        activeCardView.addSubview(activeMainLabel)

        activeTagLabel = NSTextField(labelWithString: L10n.queueHUDNextItem)
        activeTagLabel.font = .systemFont(ofSize: 10, weight: .bold)
        activeTagLabel.textColor = .controlAccentColor
        activeTagLabel.alignment = .right
        activeTagLabel.translatesAutoresizingMaskIntoConstraints = false
        activeCardView.addSubview(activeTagLabel)

        // --- 后续队列排队标签 ---
        upcomingContainerView = NSView()
        upcomingContainerView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(upcomingContainerView)

        let upcomingTitle = NSTextField(labelWithString: "➔ " + L10n.queueHUDUpcoming + ":")
        upcomingTitle.font = .systemFont(ofSize: 10, weight: .medium)
        upcomingTitle.textColor = .tertiaryLabelColor
        upcomingTitle.translatesAutoresizingMaskIntoConstraints = false
        upcomingContainerView.addSubview(upcomingTitle)

        upcomingStackView = NSStackView()
        upcomingStackView.orientation = .horizontal
        upcomingStackView.spacing = 6
        upcomingStackView.alignment = .centerY
        upcomingStackView.translatesAutoresizingMaskIntoConstraints = false
        upcomingContainerView.addSubview(upcomingStackView)

        // --- 底部快捷操作提示栏 ---
        bottomHintLabel = NSTextField(labelWithString: L10n.queueHUDShortcutHint)
        bottomHintLabel.font = .systemFont(ofSize: 10, weight: .regular)
        bottomHintLabel.textColor = .secondaryLabelColor
        bottomHintLabel.alignment = .center
        bottomHintLabel.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(bottomHintLabel)

        // --- 自动布局约束 ---
        NSLayoutConstraint.activate([
            // Header Row
            headerRow.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 10),
            headerRow.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            headerRow.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            headerRow.heightAnchor.constraint(equalToConstant: 20),

            headerIconLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            headerIconLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),

            modeTitleLabel.leadingAnchor.constraint(equalTo: headerIconLabel.trailingAnchor, constant: 5),
            modeTitleLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),

            counterBadgeView.leadingAnchor.constraint(equalTo: modeTitleLabel.trailingAnchor, constant: 8),
            counterBadgeView.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            counterBadgeView.heightAnchor.constraint(equalToConstant: 18),

            counterBadgeLabel.leadingAnchor.constraint(equalTo: counterBadgeView.leadingAnchor, constant: 7),
            counterBadgeLabel.trailingAnchor.constraint(equalTo: counterBadgeView.trailingAnchor, constant: -7),
            counterBadgeLabel.centerYAnchor.constraint(equalTo: counterBadgeView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            // Active Card
            activeCardView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
            activeCardView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            activeCardView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            activeCardView.heightAnchor.constraint(equalToConstant: 36),

            activeIconView.leadingAnchor.constraint(equalTo: activeCardView.leadingAnchor, constant: 8),
            activeIconView.centerYAnchor.constraint(equalTo: activeCardView.centerYAnchor),
            activeIconView.widthAnchor.constraint(equalToConstant: 18),
            activeIconView.heightAnchor.constraint(equalToConstant: 18),

            activeMainLabel.leadingAnchor.constraint(equalTo: activeIconView.trailingAnchor, constant: 8),
            activeMainLabel.centerYAnchor.constraint(equalTo: activeCardView.centerYAnchor),
            activeMainLabel.trailingAnchor.constraint(equalTo: activeTagLabel.leadingAnchor, constant: -8),

            activeTagLabel.trailingAnchor.constraint(equalTo: activeCardView.trailingAnchor, constant: -8),
            activeTagLabel.centerYAnchor.constraint(equalTo: activeCardView.centerYAnchor),
            activeTagLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            // Upcoming Container
            upcomingContainerView.topAnchor.constraint(equalTo: activeCardView.bottomAnchor, constant: 6),
            upcomingContainerView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            upcomingContainerView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            upcomingContainerView.heightAnchor.constraint(equalToConstant: 20),

            upcomingTitle.leadingAnchor.constraint(equalTo: upcomingContainerView.leadingAnchor),
            upcomingTitle.centerYAnchor.constraint(equalTo: upcomingContainerView.centerYAnchor),

            upcomingStackView.leadingAnchor.constraint(equalTo: upcomingTitle.trailingAnchor, constant: 6),
            upcomingStackView.trailingAnchor.constraint(lessThanOrEqualTo: upcomingContainerView.trailingAnchor),
            upcomingStackView.centerYAnchor.constraint(equalTo: upcomingContainerView.centerYAnchor),

            // Bottom Hint
            bottomHintLabel.topAnchor.constraint(equalTo: upcomingContainerView.bottomAnchor, constant: 6),
            bottomHintLabel.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            bottomHintLabel.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            bottomHintLabel.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -8),
        ])
    }

    private func setupDragHandling() {
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        visualEffect.addGestureRecognizer(panGesture)
    }

    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard let window = panel else { return }
        switch gesture.state {
        case .began:
            dragStartLocation = gesture.location(in: nil)
            windowStartOrigin = window.frame.origin
        case .changed:
            let current = gesture.location(in: nil)
            let deltaX = current.x - dragStartLocation.x
            let deltaY = current.y - dragStartLocation.y
            let newOrigin = NSPoint(x: windowStartOrigin.x + deltaX, y: windowStartOrigin.y + deltaY)
            window.setFrameOrigin(newOrigin)
        case .ended:
            UserDefaults.standard.set(Double(window.frame.origin.x), forKey: "queueHUDOriginX")
            UserDefaults.standard.set(Double(window.frame.origin.y), forKey: "queueHUDOriginY")
        default:
            break
        }
    }

    private func positionPanel() {
        if let savedX = UserDefaults.standard.object(forKey: "queueHUDOriginX") as? Double,
           let savedY = UserDefaults.standard.object(forKey: "queueHUDOriginY") as? Double {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - (panel.frame.width / 2)
        let y = visibleFrame.minY + 90
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func handleCloseClicked() {
        ClipboardStore.shared.clearQueue()
    }

    // MARK: - 刷新与显示更新

    func update() {
        let store = ClipboardStore.shared
        guard store.showQueueHUD else {
            hide(animated: true)
            return
        }

        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil

        let queue = store.pasteQueue
        let isCollect = store.isCollectModeActive
        let poppedCount = store.poppedHistory.count
        let totalCount = queue.count + poppedCount

        if queue.isEmpty && !isCollect {
            if poppedCount > 0 {
                showFinishedState()
            } else {
                hide(animated: true)
            }
            return
        }

        // 呈现 HUD
        show(animated: true)

        if isCollect {
            headerIconLabel.stringValue = "📥"
            modeTitleLabel.stringValue = L10n.queueHUDCollectTitle
            modeTitleLabel.textColor = .systemOrange
            counterBadgeLabel.stringValue = "\(queue.count) \(L10n.isChinese ? "项" : "items")"
            counterBadgeLabel.textColor = .systemOrange
            counterBadgeView.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.18).cgColor
            bottomHintLabel.stringValue = L10n.queueHUDCollectHint
        } else {
            headerIconLabel.stringValue = "📋"
            modeTitleLabel.stringValue = L10n.queueHUDTitle
            modeTitleLabel.textColor = .labelColor
            let currentIdx = poppedCount + (queue.isEmpty ? 0 : 1)
            counterBadgeLabel.stringValue = "\(currentIdx) / \(max(totalCount, 1))"
            counterBadgeLabel.textColor = .controlAccentColor
            counterBadgeView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            let hint = store.interceptCmdVDuringQueue ? L10n.queueHUDShortcutHintDirect : L10n.queueHUDShortcutHint
            bottomHintLabel.stringValue = hint
        }

        // 渲染待粘贴项
        if let nextItem = queue.first {
            activeCardView.isHidden = false
            activeTagLabel.stringValue = isCollect ? "#\(queue.count)" : L10n.queueHUDNextItem

            let displayTxt = formatPreview(for: nextItem)
            activeMainLabel.stringValue = displayTxt

            switch nextItem.kind {
            case .text:
                if nextItem.isURL {
                    activeIconView.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
                    activeIconView.contentTintColor = .systemBlue
                } else if let color = nextItem.colorValue {
                    activeIconView.image = makeColorCircle(color)
                    activeIconView.contentTintColor = nil
                } else {
                    activeIconView.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
                    activeIconView.contentTintColor = .labelColor
                }
            case .image:
                activeIconView.image = store.image(for: nextItem) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                activeIconView.contentTintColor = nil
            case .file:
                activeIconView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                activeIconView.contentTintColor = .systemBlue
            }
        } else {
            // 队列为空但在收集模式中
            activeCardView.isHidden = false
            activeIconView.image = NSImage(systemSymbolName: "plus.circle.dashed", accessibilityDescription: nil)
            activeIconView.contentTintColor = .systemOrange
            activeMainLabel.stringValue = L10n.isChinese ? "等待复制...（按 ⌘C 自动入队）" : "Waiting for copy (⌘C)..."
            activeTagLabel.stringValue = ""
        }

        // 渲染后续排队序列
        upcomingStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let upcomingItems = queue.dropFirst()
        if !upcomingItems.isEmpty {
            upcomingContainerView.isHidden = false
            let maxShow = 3
            for item in upcomingItems.prefix(maxShow) {
                let pill = makeUpcomingPill(for: item)
                upcomingStackView.addArrangedSubview(pill)
            }
            if upcomingItems.count > maxShow {
                let morePill = makeUpcomingPill(text: "+\(upcomingItems.count - maxShow)")
                upcomingStackView.addArrangedSubview(morePill)
            }
        } else {
            upcomingContainerView.isHidden = true
        }
    }

    private func makeUpcomingPill(for item: ClipItem) -> NSView {
        let text = formatPreview(for: item, maxLen: 12)
        return makeUpcomingPill(text: text)
    }

    private func makeUpcomingPill(text: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 5
        container.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12).cgColor

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }

    private func showFinishedState() {
        show(animated: true)
        headerIconLabel.stringValue = "✓"
        modeTitleLabel.stringValue = L10n.queueFinished
        modeTitleLabel.textColor = .systemGreen
        counterBadgeLabel.stringValue = "✓"
        counterBadgeLabel.textColor = .systemGreen
        counterBadgeView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.18).cgColor

        activeMainLabel.stringValue = L10n.queueFinished
        activeIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        activeIconView.contentTintColor = .systemGreen
        activeTagLabel.stringValue = ""
        upcomingContainerView.isHidden = true
        bottomHintLabel.stringValue = L10n.isChinese ? "所有内容已全部填完" : "All items pasted"

        let work = DispatchWorkItem { [weak self] in
            self?.hide(animated: true)
        }
        autoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func show(animated: Bool = true) {
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFront(nil)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.alphaValue = 1.0
        }
    }

    func hide(animated: Bool = true) {
        guard panel.isVisible else { return }
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                self?.panel.orderOut(nil)
            })
        } else {
            panel.alphaValue = 0.0
            panel.orderOut(nil)
        }
    }

    private func formatPreview(for item: ClipItem, maxLen: Int = 30) -> String {
        if let alias = item.alias, !alias.isEmpty {
            return "📌 " + alias
        }
        switch item.kind {
        case .text:
            let clean = item.previewText.replacingOccurrences(of: "\n", with: " ")
            if clean.count > maxLen {
                return String(clean.prefix(maxLen)) + "…"
            }
            return clean.isEmpty ? "(Empty text)" : clean
        case .image:
            if let ocr = item.ocrText, !ocr.isEmpty {
                let clean = ocr.replacingOccurrences(of: "\n", with: " ")
                return "🖼 [OCR] " + String(clean.prefix(maxLen))
            }
            return "🖼 \(L10n.imageLabel) (\(item.width ?? 0)×\(item.height ?? 0))"
        case .file:
            if let paths = item.filePaths, let first = paths.first {
                let name = (first as NSString).lastPathComponent
                return "📁 " + name + (paths.count > 1 ? " (+\(paths.count - 1))" : "")
            }
            return "📁 \(L10n.fileLabel)"
        }
    }

    private func makeColorCircle(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let img = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            path.fill()
            NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        return img
    }
}
