import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var hotKey: HotKey!
    private var queueHotKey: HotKey!
    private var queueUndoHotKey: HotKey!
    private var queueCollectHotKey: HotKey!
    private var queueGlobalKeyMonitor: Any?
    private var launchAtLoginItem: NSMenuItem?
    private var previewLayoutMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        ClipboardStore.shared.startMonitoring()
        panelController = PanelController()

        // 注册全局唤出快捷键（读取预设）
        let preset = currentHotkeyPreset
        hotKey = HotKey(id: 1, keyCode: preset.keyConfig.keyCode, modifiers: preset.keyConfig.modifiers) { [weak self] in
            self?.panelController.toggle()
        }

        // 全局快捷键 Option+Cmd+V 顺序填表队列粘贴（后备手动触发）
        queueHotKey = HotKey(id: 2, keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.handleQueuePaste()
        }

        // 全局快捷键 Option+Cmd+Z 队列回退上一项
        queueUndoHotKey = HotKey(id: 3, keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.handleQueueUndo()
        }

        // 全局快捷键 Option+Cmd+C 开启/结束连续收集模式
        queueCollectHotKey = HotKey(id: 4, keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
            self?.handleToggleCollectMode()
        }

        ClipboardStore.shared.onQueueChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.syncDynamicQueueMonitoring()
                self?.updateStatusItemBadge()
                QueueHUDWindowController.shared.update()
            }
        }
        ClipboardStore.shared.onCollectModeChanged = { [weak self] isActive in
            DispatchQueue.main.async {
                if isActive {
                    self?.flashStatusMessage(L10n.queueCollectStarted)
                } else {
                    self?.flashStatusMessage(L10n.queueCollectStopped)
                }
            }
        }
        ClipboardStore.shared.onQueueFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.syncDynamicQueueMonitoring()
                self?.flashStatusMessage(L10n.queueFinished)
            }
        }

        setupStatusItem()
        if hotKey?.isRegistered != true {
            showHotkeyConflictAlert(preset)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: L10n.statusIconDescription) {
                img.isTemplate = true
                button.image = img
            } else if let img = NSImage(systemSymbolName: "paperclip", accessibilityDescription: L10n.statusIconDescription) {
                img.isTemplate = true
                button.image = img
            } else {
                let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                    NSColor.labelColor.setStroke()
                    let path = NSBezierPath(roundedRect: NSRect(x: 3, y: 1, width: 12, height: 14), xRadius: 2, yRadius: 2)
                    path.lineWidth = 1.5
                    path.stroke()
                    let clip = NSBezierPath(roundedRect: NSRect(x: 6, y: 13, width: 6, height: 3), xRadius: 1, yRadius: 1)
                    clip.lineWidth = 1.5
                    clip.stroke()
                    return true
                }
                img.isTemplate = true
                button.image = img
            }
            button.target = self
            button.action = #selector(statusItemActivated)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem.button?.toolTip = L10n.statusIconTooltip
        statusMenu = createMenu()
    }

    @objc private func statusItemActivated() {
        guard let event = NSApp.currentEvent else {
            panelController.toggle()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            if let button = statusItem.button {
                popStatusMenu(from: button)
            }
            return
        }
        panelController.toggle()
    }

    private var hotkeyMenu: NSMenu?
    private var blacklistMenu: NSMenu?
    private var storageMenu: NSMenu?
    private var statusMenu: NSMenu!

    private var statusFlashWork: DispatchWorkItem?

    func popStatusMenu(from sender: NSView) {
        let popPoint = NSPoint(x: 0, y: sender.isFlipped ? sender.bounds.height + 2 : -2)
        statusMenu.popUp(positioning: nil, at: popPoint, in: sender)
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let show = NSMenuItem(title: L10n.showHistory(shortcut: currentHotkeyPreset.shortcutGlyph), action: #selector(togglePanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())

        // 唤出快捷键设置
        let hotkeyItem = NSMenuItem(title: L10n.hotkeySettings, action: nil, keyEquivalent: "")
        let hkMenu = NSMenu()
        let activePreset = currentHotkeyPreset
        for p in HotkeyPreset.allCases {
            let item = NSMenuItem(title: p.title, action: #selector(selectHotkeyPreset(_:)), keyEquivalent: "")
            item.representedObject = p.rawValue
            item.target = self
            item.state = (p == activePreset) ? .on : .off
            hkMenu.addItem(item)
        }
        hkMenu.addItem(.separator())
        let quickPasteItem = NSMenuItem(title: L10n.quickPasteToggle, action: #selector(toggleQuickPaste(_:)), keyEquivalent: "")
        quickPasteItem.target = self
        quickPasteItem.state = isQuickPasteEnabled ? .on : .off
        hkMenu.addItem(quickPasteItem)
        hotkeyItem.submenu = hkMenu
        self.hotkeyMenu = hkMenu
        menu.addItem(hotkeyItem)

        // 开机自启动
        let launchItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        self.launchAtLoginItem = launchItem
        menu.addItem(launchItem)

        // 呼出位置设置
        let posItem = NSMenuItem(title: L10n.windowPosition, action: nil, keyEquivalent: "")
        let posMenu = NSMenu()
        let currentMode = UserDefaults.standard.string(forKey: "windowPositionMode") ?? "center"

        let centerItem = NSMenuItem(title: L10n.posScreenCenter, action: #selector(selectPositionMode(_:)), keyEquivalent: "")
        centerItem.representedObject = "center"
        centerItem.target = self
        centerItem.state = (currentMode == "center") ? .on : .off
        posMenu.addItem(centerItem)

        let mouseItem = NSMenuItem(title: L10n.posNearMouse, action: #selector(selectPositionMode(_:)), keyEquivalent: "")
        mouseItem.representedObject = "mouse"
        mouseItem.target = self
        mouseItem.state = (currentMode == "mouse") ? .on : .off
        posMenu.addItem(mouseItem)

        posItem.submenu = posMenu
        menu.addItem(posItem)

        menu.addItem(.separator())

        // 历史容量设置
        let limitItem = NSMenuItem(title: L10n.historyCapacity, action: nil, keyEquivalent: "")
        let limitMenu = NSMenu()
        let currentMax = ClipboardStore.shared.maxItems
        for count in [50, 100, 200, 500] {
            let item = NSMenuItem(title: L10n.itemsCount(count), action: #selector(selectMaxItems(_:)), keyEquivalent: "")
            item.tag = count
            item.target = self
            item.state = (count == currentMax) ? .on : .off
            limitMenu.addItem(item)
        }
        limitItem.submenu = limitMenu
        menu.addItem(limitItem)

        // 存储与缓存管理
        let storageItem = NSMenuItem(title: L10n.storageMenu, action: nil, keyEquivalent: "")
        let stMenu = NSMenu()
        storageItem.submenu = stMenu
        self.storageMenu = stMenu
        menu.addItem(storageItem)

        menu.addItem(.separator())

        // 敏感数据过滤
        let privacyItem = NSMenuItem(title: L10n.ignorePasswords, action: #selector(togglePrivacyFilter(_:)), keyEquivalent: "")
        privacyItem.target = self
        privacyItem.state = ClipboardStore.shared.ignoreSensitiveData ? .on : .off
        menu.addItem(privacyItem)

        // 排除应用黑名单
        let blacklistItem = NSMenuItem(title: L10n.blacklistMenu, action: nil, keyEquivalent: "")
        let blMenu = NSMenu()
        blacklistItem.submenu = blMenu
        self.blacklistMenu = blMenu
        menu.addItem(blacklistItem)

        menu.addItem(.separator())

        // 始终常驻右侧预览
        let previewPrefItem = NSMenuItem(title: L10n.alwaysShowPreview, action: #selector(toggleAlwaysShowPreview(_:)), keyEquivalent: "")
        previewPrefItem.target = self
        previewPrefItem.state = UserDefaults.standard.bool(forKey: "alwaysShowPreview") ? .on : .off
        menu.addItem(previewPrefItem)

        // 预览布局
        let layoutItem = NSMenuItem(title: L10n.previewLayout, action: nil, keyEquivalent: "")
        let layoutMenu = NSMenu()
        let compact = NSMenuItem(title: L10n.previewLayoutCompact, action: #selector(selectPreviewLayout(_:)), keyEquivalent: "")
        compact.representedObject = "compact"
        compact.target = self
        layoutMenu.addItem(compact)

        let automatic = NSMenuItem(title: L10n.previewLayoutAutomatic, action: #selector(selectPreviewLayout(_:)), keyEquivalent: "")
        automatic.representedObject = "automatic"
        automatic.target = self
        layoutMenu.addItem(automatic)

        let wide = NSMenuItem(title: L10n.previewLayoutWide, action: #selector(selectPreviewLayout(_:)), keyEquivalent: "")
        wide.representedObject = "wide"
        wide.target = self
        layoutMenu.addItem(wide)

        layoutMenu.addItem(.separator())
        let resetSmart = NSMenuItem(title: L10n.resetSmartPreview, action: #selector(resetSmartPreview(_:)), keyEquivalent: "")
        resetSmart.target = self
        layoutMenu.addItem(resetSmart)

        layoutItem.submenu = layoutMenu
        previewLayoutMenu = layoutMenu
        updatePreviewLayoutMenuState()
        menu.addItem(layoutItem)

        // 填表队列设置
        let queuePrefItem = NSMenuItem(title: L10n.queueSettingsMenu, action: nil, keyEquivalent: "")
        let qMenu = NSMenu()

        let orderMenu = NSMenu()
        let currentOrder = ClipboardStore.shared.queueOrder
        for order in ClipboardStore.QueueOrder.allCases {
            let item = NSMenuItem(title: order.title, action: #selector(selectQueueOrder(_:)), keyEquivalent: "")
            item.representedObject = order.rawValue
            item.target = self
            item.state = (order == currentOrder) ? .on : .off
            orderMenu.addItem(item)
        }
        let orderItem = NSMenuItem(title: L10n.queueOrderMenu, action: nil, keyEquivalent: "")
        orderItem.submenu = orderMenu
        qMenu.addItem(orderItem)

        let hudToggleItem = NSMenuItem(title: L10n.queueHUDToggle, action: #selector(toggleQueueHUD(_:)), keyEquivalent: "")
        hudToggleItem.target = self
        hudToggleItem.state = ClipboardStore.shared.showQueueHUD ? .on : .off
        qMenu.addItem(hudToggleItem)

        let interceptCmdVItem = NSMenuItem(title: L10n.queueInterceptCmdVToggle, action: #selector(toggleInterceptCmdV(_:)), keyEquivalent: "")
        interceptCmdVItem.target = self
        interceptCmdVItem.state = ClipboardStore.shared.interceptCmdVDuringQueue ? .on : .off
        qMenu.addItem(interceptCmdVItem)

        qMenu.addItem(.separator())

        let collectToggleItem = NSMenuItem(title: L10n.queueCollectToggle, action: #selector(toggleCollectModeMenuItem(_:)), keyEquivalent: "")
        collectToggleItem.target = self
        collectToggleItem.state = ClipboardStore.shared.isCollectModeActive ? .on : .off
        qMenu.addItem(collectToggleItem)

        let undoItem = NSMenuItem(title: L10n.queueUndoAction, action: #selector(undoQueueMenuItem(_:)), keyEquivalent: "")
        undoItem.target = self
        qMenu.addItem(undoItem)

        queuePrefItem.submenu = qMenu
        menu.addItem(queuePrefItem)

        menu.addItem(.separator())

        // 回车自动粘贴（辅助功能）
        let autoPasteItem = NSMenuItem(title: L10n.autoPasteItem, action: #selector(handleAutoPasteToggle), keyEquivalent: "")
        autoPasteItem.target = self
        updateAutoPasteMenuItem(autoPasteItem)
        menu.addItem(autoPasteItem)

        menu.addItem(.separator())

        let clear = NSMenuItem(title: L10n.clearHistory, action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let about = NSMenuItem(title: L10n.aboutApp, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: L10n.quitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem?.state = isLaunchAtLoginEnabled ? .on : .off
        if let show = menu.items.first(where: { $0.action == #selector(togglePanel) }) {
            show.title = L10n.showHistory(shortcut: currentHotkeyPreset.shortcutGlyph)
        }
        for item in menu.items {
            if item.action == #selector(toggleAlwaysShowPreview(_:)) {
                item.state = UserDefaults.standard.bool(forKey: "alwaysShowPreview") ? .on : .off
            }
            if item.action == #selector(togglePrivacyFilter(_:)) {
                item.state = ClipboardStore.shared.ignoreSensitiveData ? .on : .off
            }
            if item.action == #selector(handleAutoPasteToggle) {
                updateAutoPasteMenuItem(item)
            }
        }
        updateHotkeyMenuState()
        updateBlacklistMenu()
        updateStorageMenu()
        updatePreviewLayoutMenuState()
        updateQueueMenuItem(in: menu)
        updateAccessibilityWarning(in: menu)
    }

    // MARK: - 快捷键管理

    private var currentHotkeyPreset: HotkeyPreset {
        get {
            let val = UserDefaults.standard.string(forKey: "hotkeyPreset") ?? HotkeyPreset.cmdShiftV.rawValue
            return HotkeyPreset(rawValue: val) ?? .cmdShiftV
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "hotkeyPreset")
            applyHotkeyPreset(newValue)
        }
    }

    private var isQuickPasteEnabled: Bool {
        UserDefaults.standard.object(forKey: "quickPasteEnabled") as? Bool ?? true
    }

    private func applyHotkeyPreset(_ preset: HotkeyPreset) {
        let config = preset.keyConfig
        let ok = hotKey?.register(keyCode: config.keyCode, modifiers: config.modifiers) ?? false
        if !ok {
            showHotkeyConflictAlert(preset)
        }
    }

    private func showHotkeyConflictAlert(_ preset: HotkeyPreset) {
        let alert = NSAlert()
        alert.messageText = L10n.hotkeyConflictTitle
        alert.informativeText = L10n.hotkeyConflictMessage(preset.shortcutGlyph)
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func updateHotkeyMenuState() {
        let active = currentHotkeyPreset
        hotkeyMenu?.items.forEach { item in
            if item.action == #selector(toggleQuickPaste(_:)) {
                item.state = isQuickPasteEnabled ? .on : .off
                return
            }
            guard let raw = item.representedObject as? String else { return }
            item.state = (raw == active.rawValue) ? .on : .off
        }
    }

    @objc private func selectHotkeyPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = HotkeyPreset(rawValue: raw) else { return }
        currentHotkeyPreset = preset
        updateHotkeyMenuState()
    }

    @objc private func toggleQuickPaste(_ sender: NSMenuItem) {
        let newValue = !isQuickPasteEnabled
        UserDefaults.standard.set(newValue, forKey: "quickPasteEnabled")
        sender.state = newValue ? .on : .off
        panelController.reloadVisibleRows()
    }

    // MARK: - 排除应用黑名单

    private func updateBlacklistMenu() {
        guard let menu = blacklistMenu else { return }
        menu.removeAllItems()

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontName = frontApp?.localizedName ?? ""
        let frontBundleId = frontApp?.bundleIdentifier

        if let bundleId = frontBundleId, !bundleId.isEmpty, bundleId != Bundle.main.bundleIdentifier {
            let isCurrentBlacklisted = ClipboardStore.shared.isBlacklisted(bundleId: bundleId)
            let actionTitle = isCurrentBlacklisted ? L10n.blacklistExcluded(frontName) : "\(L10n.excludeCurrentApp)\(frontName)"
            let item = NSMenuItem(title: actionTitle, action: #selector(toggleCurrentFrontAppBlacklist(_:)), keyEquivalent: "")
            item.representedObject = bundleId
            item.target = self
            if let icon = ClipboardStore.shared.appIcon(for: bundleId) {
                item.image = icon
            }
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let blacklisted = Array(ClipboardStore.shared.blacklistedBundleIds).sorted()
        if blacklisted.isEmpty {
            let empty = NSMenuItem(title: L10n.blacklistEmpty, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for bId in blacklisted {
                let appName = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId)?.deletingPathExtension().lastPathComponent ?? bId
                let item = NSMenuItem(title: appName, action: #selector(toggleBlacklistAppItem(_:)), keyEquivalent: "")
                item.representedObject = bId
                item.target = self
                item.state = .on
                if let icon = ClipboardStore.shared.appIcon(for: bId) {
                    item.image = icon
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let clearItem = NSMenuItem(title: L10n.clearBlacklist, action: #selector(clearAllBlacklist), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }
    }

    @objc private func toggleCurrentFrontAppBlacklist(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        ClipboardStore.shared.toggleBlacklist(bundleId: bundleId)
    }

    @objc private func toggleBlacklistAppItem(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        ClipboardStore.shared.toggleBlacklist(bundleId: bundleId)
    }

    @objc private func clearAllBlacklist() {
        ClipboardStore.shared.clearBlacklist()
    }

    // MARK: - 存储与缓存管理

    private func updateStorageMenu() {
        guard let menu = storageMenu else { return }
        menu.removeAllItems()

        let sizeStr = ClipboardStore.shared.calculateImageCacheSize()
        let sizeItem = NSMenuItem(title: L10n.imageCacheSize(sizeStr), action: nil, keyEquivalent: "")
        sizeItem.isEnabled = false
        menu.addItem(sizeItem)

        menu.addItem(.separator())

        let cleanExpired = NSMenuItem(title: L10n.cleanExpiredImagesAction, action: #selector(cleanExpiredImages), keyEquivalent: "")
        cleanExpired.target = self
        menu.addItem(cleanExpired)

        let cleanAll = NSMenuItem(title: L10n.cleanAllImageCacheAction, action: #selector(cleanAllImageCache), keyEquivalent: "")
        cleanAll.target = self
        menu.addItem(cleanAll)
    }

    @objc private func cleanExpiredImages() {
        ClipboardStore.shared.cleanExpiredImages(olderThanDays: 30)
        flashStatusMessage(L10n.cleanSuccess)
    }

    @objc private func cleanAllImageCache() {
        ClipboardStore.shared.cleanAllUnpinnedImages()
        flashStatusMessage(L10n.cleanSuccess)
    }

    private func updatePreviewLayoutMenuState() {
        let mode = panelController?.currentPreviewLayoutMode() ?? "automatic"
        previewLayoutMenu?.items.forEach { item in
            guard let represented = item.representedObject as? String else { return }
            item.state = (represented == mode) ? .on : .off
        }
    }

    @objc private func selectPreviewLayout(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        panelController.applyPreviewLayoutMode(mode)
        updatePreviewLayoutMenuState()
    }

    @objc private func resetSmartPreview(_ sender: NSMenuItem) {
        panelController.resetPreviewToSmartWidth()
        updatePreviewLayoutMenuState()
    }

    @objc private func handleAutoPasteToggle() {
        if !PasteSimulator.isTrusted {
            ClipboardStore.shared.autoPasteEnabled = true
            PasteSimulator.requestPermission()
            return
        }
        ClipboardStore.shared.autoPasteEnabled.toggle()
    }

    private func updateAutoPasteMenuItem(_ item: NSMenuItem) {
        let trusted = PasteSimulator.isTrusted
        let enabled = ClipboardStore.shared.autoPasteEnabled
        item.state = (trusted && enabled) ? .on : .off
        if !trusted {
            item.toolTip = L10n.grantAccessibilityPrompt
        } else if enabled {
            item.toolTip = L10n.accessibilityGranted
        } else {
            item.toolTip = L10n.autoPasteDisabledHint
        }
    }

    @objc private func toggleAlwaysShowPreview(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: "alwaysShowPreview")
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: "alwaysShowPreview")
        sender.state = newValue ? .on : .off
        panelController.applyAlwaysShowPreview(newValue)
    }

    private func updateQueueMenuItem(in menu: NSMenu) {
        menu.items.removeAll { $0.tag == 9991 || $0.tag == 9992 || $0.tag == 9995 }
        let store = ClipboardStore.shared
        if store.isQueueActive {
            let statusText = store.isCollectModeActive
                ? "\(L10n.queueHUDCollectTitle) (\(store.queueRemainingCount) \(L10n.isChinese ? "项" : "items"))"
                : L10n.queueRemaining(store.queueRemainingCount)
            let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            status.tag = 9991
            status.isEnabled = false

            let undoItem = NSMenuItem(title: L10n.queueUndoAction, action: #selector(undoQueueMenuItem(_:)), keyEquivalent: "")
            undoItem.tag = 9995
            undoItem.target = self
            undoItem.isEnabled = !store.poppedHistory.isEmpty

            let stopItem = NSMenuItem(title: L10n.clearQueue, action: #selector(stopQueue), keyEquivalent: "")
            stopItem.tag = 9992
            stopItem.target = self

            menu.insertItem(status, at: 1)
            menu.insertItem(undoItem, at: 2)
            menu.insertItem(stopItem, at: 3)
        }
    }

    private func updateAccessibilityWarning(in menu: NSMenu) {
        menu.items.removeAll { $0.tag == 9993 || $0.tag == 9994 }
        guard ClipboardStore.shared.autoPasteEnabled, !PasteSimulator.isTrusted else { return }
        let warn = NSMenuItem(title: L10n.grantAccessibilityMenu, action: #selector(handleAutoPasteToggle), keyEquivalent: "")
        warn.tag = 9993
        warn.target = self
        let sep = NSMenuItem.separator()
        sep.tag = 9994
        menu.insertItem(warn, at: 0)
        menu.insertItem(sep, at: 1)
    }

    private func flashStatusMessage(_ text: String) {
        statusItem.button?.toolTip = text
        statusFlashWork?.cancel()
        if !ClipboardStore.shared.isQueueActive {
            statusItem.button?.title = " ✓"
        }
        let work = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.toolTip = L10n.statusIconTooltip
            self?.updateStatusItemBadge()
        }
        statusFlashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func updateStatusItemBadge() {
        let store = ClipboardStore.shared
        if store.isQueueActive {
            let prefix = store.isCollectModeActive ? "📥" : ""
            statusItem.button?.title = " \(prefix)\(store.queueRemainingCount)"
        } else {
            statusItem.button?.title = ""
        }
    }

    private func syncDynamicQueueMonitoring() {
        let store = ClipboardStore.shared
        if store.isQueueActive {
            if queueGlobalKeyMonitor == nil {
                queueGlobalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard self != nil else { return }
                    let store = ClipboardStore.shared
                    guard store.isQueueActive else { return }

                    // 检测全局按下了 ⌘V (keyCode == 9, commandKey) 自动推进队列
                    if event.keyCode == 9 &&
                       event.modifierFlags.contains(.command) &&
                       !event.modifierFlags.contains(.option) &&
                       !event.modifierFlags.contains(.control) {
                        // 延迟 70ms，等前台应用完成对当前剪贴板内容的读取与粘贴
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                            guard store.isQueueActive else { return }
                            store.advanceQueue()
                        }
                    }
                }
            }
        } else {
            if let monitor = queueGlobalKeyMonitor {
                NSEvent.removeMonitor(monitor)
                queueGlobalKeyMonitor = nil
            }
        }
    }

    private func handleQueuePaste() {
        let store = ClipboardStore.shared
        if store.isQueueActive {
            store.popNextQueueItem()
        } else {
            panelController.showPanel()
        }
    }

    private func handleQueueUndo() {
        let store = ClipboardStore.shared
        if store.undoQueuePop() != nil {
            flashStatusMessage(L10n.queueUndoSuccess)
        } else {
            flashStatusMessage(L10n.queueUndoEmpty)
        }
    }

    private func handleToggleCollectMode() {
        let store = ClipboardStore.shared
        _ = store.toggleCollectMode()
    }

    @objc private func toggleInterceptCmdV(_ sender: NSMenuItem) {
        let current = ClipboardStore.shared.interceptCmdVDuringQueue
        let newValue = !current
        ClipboardStore.shared.interceptCmdVDuringQueue = newValue
        sender.state = newValue ? .on : .off
        syncDynamicQueueMonitoring()
        QueueHUDWindowController.shared.update()
    }

    @objc private func selectQueueOrder(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let order = ClipboardStore.QueueOrder(rawValue: raw) else { return }
        ClipboardStore.shared.queueOrder = order
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? String == raw) ? .on : .off
            }
        }
    }

    @objc private func toggleQueueHUD(_ sender: NSMenuItem) {
        let current = ClipboardStore.shared.showQueueHUD
        let newValue = !current
        ClipboardStore.shared.showQueueHUD = newValue
        sender.state = newValue ? .on : .off
        QueueHUDWindowController.shared.update()
    }

    @objc private func toggleCollectModeMenuItem(_ sender: NSMenuItem) {
        let active = ClipboardStore.shared.toggleCollectMode()
        sender.state = active ? .on : .off
    }

    @objc private func undoQueueMenuItem(_ sender: NSMenuItem) {
        handleQueueUndo()
    }

    @objc private func stopQueue() {
        ClipboardStore.shared.clearQueue()
        syncDynamicQueueMonitoring()
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
        launchAtLoginItem?.state = isLaunchAtLoginEnabled ? .on : .off
    }

    private var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
            return true
        }
        return FileManager.default.fileExists(atPath: launchAgentPlistURL.path)
    }

    private var launchAgentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.williamlao.clipboardmate.plist")
    }

    private func enableLaunchAtLogin() {
        var registeredWithSystem = false
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                registeredWithSystem = SMAppService.mainApp.status == .enabled
            } catch {
                NSLog("SMAppService register failed: \(error)")
            }
        }
        if registeredWithSystem {
            removeLaunchAgent()
            return
        }
        do {
            try installLaunchAgent()
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.launchAtLoginFailedTitle
            alert.informativeText = L10n.launchAtLoginFailedMessage
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func disableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        removeLaunchAgent()
    }

    private func installLaunchAgent() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: launchAgentPlistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let appPath = Bundle.main.bundleURL.path
        let plist: [String: Any] = [
            "Label": "com.williamlao.clipboardmate",
            "ProgramArguments": ["/usr/bin/open", appPath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentPlistURL, options: .atomic)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: launchAgentPlistURL)
    }

    @objc private func selectMaxItems(_ sender: NSMenuItem) {
        ClipboardStore.shared.maxItems = sender.tag
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.tag == sender.tag) ? .on : .off
            }
        }
    }

    @objc private func selectPositionMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? String {
            UserDefaults.standard.set(mode, forKey: "windowPositionMode")
            if let menu = sender.menu {
                for item in menu.items {
                    item.state = (item == sender) ? .on : .off
                }
            }
        }
    }

    @objc private func togglePrivacyFilter(_ sender: NSMenuItem) {
        ClipboardStore.shared.ignoreSensitiveData.toggle()
        sender.state = ClipboardStore.shared.ignoreSensitiveData ? .on : .off
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L10n.clearHistoryConfirmTitle
        alert.informativeText = L10n.clearHistoryConfirmMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.clearHistoryConfirmAction)
        alert.addButton(withTitle: L10n.cancel)
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardStore.shared.clear(preservePinned: true)
        }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "ClipboardMate",
            .applicationVersion: version,
            .version: build,
            .credits: NSAttributedString(
                string: "Lightweight clipboard history manager for macOS",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            )
        ])
    }

    func applicationWillTerminate(_ notification: Notification) {}
}
