import Foundation

enum L10n {
    static var isChinese: Bool {
        let pref = Locale.preferredLanguages.first ?? Locale.current.identifier
        return pref.hasPrefix("zh")
    }

    // Menu Bar
    static func showHistory(shortcut: String = "⌘⇧V") -> String {
        isChinese ? "显示历史（\(shortcut)）" : "Show History (\(shortcut))"
    }
    static var launchAtLogin: String { isChinese ? "开机自启动" : "Launch at Login" }
    static var launchAtLoginFailedTitle: String { isChinese ? "无法开启开机自启动" : "Couldn’t Enable Launch at Login" }
    static var launchAtLoginFailedMessage: String {
        isChinese
            ? "系统拒绝了登录项注册。请确认应用位于「应用程序」文件夹后重试；若仍失败，可在「系统设置 → 通用 → 登录项」中手动添加 ClipboardMate。"
            : "macOS refused to register the login item. Keep ClipboardMate in the Applications folder and try again, or add it manually in System Settings → General → Login Items."
    }
    static var historyCapacity: String { isChinese ? "历史记录容量" : "History Capacity" }
    static func itemsCount(_ count: Int) -> String { isChinese ? "\(count) 条" : "\(count) items" }
    static var windowPosition: String { isChinese ? "呼出位置" : "Window Position" }
    static var posScreenCenter: String { isChinese ? "屏幕居中（推荐）" : "Screen Center (Recommended)" }
    static var posNearMouse: String { isChinese ? "跟随鼠标" : "Near Mouse" }
    static var ignorePasswords: String { isChinese ? "忽略密码管理器复制" : "Ignore Password Managers" }
    static var clearHistory: String { isChinese ? "清空历史" : "Clear History" }
    static var quitApp: String { isChinese ? "退出 ClipboardMate" : "Quit ClipboardMate" }
    static var aboutApp: String { isChinese ? "关于 ClipboardMate" : "About ClipboardMate" }
    static var statusIconDescription: String { isChinese ? "剪贴板历史" : "Clipboard History" }
    static var statusIconTooltip: String {
        isChinese ? "点击显示历史，右键打开设置" : "Click to show history, right-click for settings"
    }
    static var autoPasteItem: String { isChinese ? "回车自动粘贴" : "Auto-Paste on Enter" }
    static var grantAccessibilityPrompt: String { isChinese ? "前往系统设置授予辅助功能权限..." : "Grant Accessibility Permission..." }
    static var accessibilityGranted: String { isChinese ? "已授权辅助功能（回车直接粘贴）" : "Accessibility Granted (Auto-Paste Enabled)" }
    static var autoPasteDisabledHint: String { isChinese ? "已关闭自动粘贴，回车只写入剪贴板" : "Auto-paste is off; Return copies to the clipboard only" }
    static var grantAccessibilityMenu: String { isChinese ? "需要辅助功能权限才能自动粘贴…" : "Grant Accessibility to Auto-Paste…" }
    static var hotkeyConflictTitle: String { isChinese ? "无法注册唤出快捷键" : "Couldn’t Register Shortcut" }
    static func hotkeyConflictMessage(_ shortcut: String) -> String {
        isChinese
            ? "\(shortcut) 已被其他应用占用。请在菜单中改用其他唤出快捷键，或关掉冲突的剪贴板工具。"
            : "\(shortcut) is already used by another app. Pick a different shortcut, or quit the other clipboard utility."
    }
    static var preferences: String { isChinese ? "偏好设置" : "Preferences" }
    static var pasteSelectedTooltip: String { isChinese ? "粘贴当前选中项（回车）" : "Paste selected item (Return)" }
    static var imageFitTooltip: String { isChinese ? "按图片比例恢复合适的预览宽度" : "Fit preview width to the image ratio" }
    static var mergeCopy: String { isChinese ? "合并复制到剪贴板（⌘C）" : "Merge Copy (⌘C)" }
    static var deleteSelected: String { isChinese ? "批量删除（Delete）" : "Delete Selected (Delete)" }
    static var pasteEnter: String { isChinese ? "粘贴（↵）" : "Paste (↵)" }
    static var snippet: String { isChinese ? "代码片段" : "Snippet" }
    static var codeLabel: String { isChinese ? "代码片段" : "Code" }
    static var markdownPreview: String { isChinese ? "预览" : "Preview" }
    static var markdownRaw: String { isChinese ? "原文" : "Raw" }
    static var markdownTypePreview: String { isChinese ? "Markdown（预览）" : "Markdown (Preview)" }
    static var markdownTypeRaw: String { isChinese ? "Markdown（原文）" : "Markdown (Raw)" }
    static var mergePreviewTitle: String { isChinese ? "多选合并预览" : "Merge Preview" }
    static func mergePreviewMeta(_ count: Int) -> String {
        isChinese ? "已选中 \(count) 项 • 按 Enter 合并粘贴" : "\(count) items selected • Enter to merge"
    }
    static func blacklistExcluded(_ name: String) -> String {
        isChinese ? "\(blacklistMenu): \(name)（已排除）" : "\(blacklistMenu): \(name) (excluded)"
    }
    static func fileCountShort(_ count: Int) -> String {
        isChinese ? "\(count) 项" : "\(count) items"
    }
    static func fileAndMore(_ count: Int) -> String {
        isChinese ? "等 \(count) 项" : "+ \(count) more"
    }
    static var pinned: String { isChinese ? "已置顶" : "Pinned" }
    static var rowKindText: String { isChinese ? "文本" : "Text" }
    static var rowKindImage: String { isChinese ? "图片" : "Image" }
    static var rowKindFile: String { isChinese ? "文件" : "File" }
    static var rowKindLink: String { isChinese ? "链接" : "Link" }
    static var rowKindColor: String { isChinese ? "颜色" : "Color" }
    static func quickPasteHint(_ n: Int) -> String { "⌘\(n)" }

    // Search & Tabs
    static var searchPlaceholder: String { isChinese ? "搜索剪贴板历史（空格分词，Tab 切换分类）" : "Search history (space = AND, Tab to switch)" }
    static var catAll: String { isChinese ? "全部" : "All" }
    static var catText: String { isChinese ? "文本" : "Text" }
    static var catImage: String { isChinese ? "图片" : "Images" }
    static var catLink: String { isChinese ? "链接" : "Links" }
    static var catPinned: String { isChinese ? "📌置顶" : "📌 Pinned" }

    // Bottom hint
    static var isQuickPasteEnabled: Bool { UserDefaults.standard.object(forKey: "quickPasteEnabled") as? Bool ?? true }
    static var bottomHint: String {
        let qp = isQuickPasteEnabled
        if isChinese {
            return qp ? "↵ 粘贴/合并   ⌥↵ 纯文本   Space 预览   ⌘1-9 秒贴" : "↵ 粘贴/合并   ⌥↵ 纯文本   Space 预览"
        } else {
            return qp ? "↵ Paste/Merge   ⌥↵ Plain Text   Space Preview   ⌘1-9 Quick Paste" : "↵ Paste/Merge   ⌥↵ Plain Text   Space Preview"
        }
    }
    static var primaryPaste: String { isChinese ? "↵ 粘贴" : "↵ Paste" }
    static var secondaryPasteHints: String {
        let qp = isQuickPasteEnabled
        if isChinese {
            return qp ? "⌥↵ 纯文本   Space 预览   ⌘1-9 秒贴" : "⌥↵ 纯文本   Space 预览"
        } else {
            return qp ? "⌥↵ Plain Text   Space Preview   ⌘1-9 Quick Paste" : "⌥↵ Plain Text   Space Preview"
        }
    }

    // Empty states
    static var emptyHistory: String {
        isChinese ? "暂无剪贴板历史\n复制任意内容后自动出现在这里" : "No clipboard history yet\nCopy anything to see it here"
    }
    static var emptyCategory: String { isChinese ? "该分类下暂无内容" : "No items in this category" }
    static var emptySearch: String { isChinese ? "无匹配结果" : "No matching results" }

    // Context Menu
    static var pastePlain: String { isChinese ? "作为纯文本粘贴（⌥↵）" : "Paste as Plain Text (⌥↵)" }
    static var copyOnly: String { isChinese ? "仅复制到剪贴板（⌘C）" : "Copy to Clipboard Only (⌘C)" }
    static var openURL: String { isChinese ? "在浏览器中打开（⌘O）" : "Open in Browser (⌘O)" }
    static var togglePreview: String { isChinese ? "切换即时预览（Space）" : "Toggle QuickLook (Space)" }
    static var pinToggle: String { isChinese ? "置顶 / 取消置顶（⌘P）" : "Pin / Unpin (⌘P)" }
    static var deleteItem: String { isChinese ? "删除（Delete）" : "Delete (Delete)" }
    static var clearAll: String { isChinese ? "清空全部..." : "Clear All..." }

    // Queue Paste (连续填表队列模式)
    static var startQueue: String { isChinese ? "启动填表队列（⌘S 逐项粘贴）" : "Start Paste Queue (⌘S)" }
    static var startQueueFIFO: String { isChinese ? "启动填表队列：先复制先贴（FIFO 推荐，⌘S）" : "Start Queue: First Copied First Pasted (FIFO, ⌘S)" }
    static var startQueueLIFO: String { isChinese ? "启动填表队列：后复制先贴（LIFO，⇧⌘S）" : "Start Queue: Last Copied First Pasted (LIFO, ⇧⌘S)" }
    static var startQueueSelection: String { isChinese ? "启动填表队列：按列表当前顺序" : "Start Queue: As Listed in Panel" }
    static func queueRemaining(_ count: Int) -> String {
        isChinese ? "粘贴队列进行中 (剩余 \(count) 项，按 ⌘V / ⌥⌘V 粘贴)" : "Paste Queue Active (\(count) left, press ⌘V / ⌥⌘V)"
    }
    static var clearQueue: String { isChinese ? "停止/清空粘贴队列 (Esc)" : "Stop / Clear Paste Queue (Esc)" }
    static var queueFinished: String { isChinese ? "粘贴队列已全部完成" : "Paste queue finished" }
    static var queueUndoSuccess: String { isChinese ? "已回退上一项到队列头部 (⌘Z)" : "Rewound previous item (⌘Z)" }
    static var queueUndoEmpty: String { isChinese ? "无可回退的队列历史" : "No queue history to rewind" }
    static var queueHUDTitle: String { isChinese ? "填表粘贴队列" : "Paste Queue" }
    static var queueHUDCollectTitle: String { isChinese ? "连续收集模式" : "Continuous Collect Mode" }
    static var queueHUDNextItem: String { isChinese ? "待粘贴" : "Next" }
    static var queueHUDUpcoming: String { isChinese ? "排队中" : "Upcoming" }
    static var queueHUDShortcutHintDirect: String { isChinese ? "⌘V 粘贴下一项  •  ⌘Z 回退  •  Esc 清空" : "⌘V Paste Next  •  ⌘Z Undo  •  Esc Clear" }
    static var queueHUDShortcutHint: String { isChinese ? "⌥⌘V 粘贴下一项  •  ⌥⌘Z 回退  •  Esc 清空" : "⌥⌘V Paste Next  •  ⌥⌘Z Undo  •  Esc Clear" }
    static var queueHUDCollectHint: String { isChinese ? "按 ⌘C 自动入队  •  ⌘V 粘贴  •  ⌥⌘C 退出" : "Press ⌘C to queue  •  ⌘V to paste  •  ⌥⌘C to exit" }
    static var queueSettingsMenu: String { isChinese ? "填表队列设置" : "Paste Queue Settings" }
    static var queueInterceptCmdVToggle: String { isChinese ? "队列激活时直接按 ⌘V / ⌘Z 操作（推荐）" : "Direct ⌘V / ⌘Z during Queue (Recommended)" }
    static var queueOrderMenu: String { isChinese ? "出队默认顺序" : "Default Queue Order" }
    static var queueOrderFIFO: String { isChinese ? "先复制先贴（FIFO 推荐）" : "First Copied First Pasted (FIFO)" }
    static var queueOrderLIFO: String { isChinese ? "后复制先贴（LIFO 最新优先）" : "Last Copied First Pasted (LIFO)" }
    static var queueOrderSelection: String { isChinese ? "按列表从上到下顺序" : "List Top-to-Bottom Order" }
    static var queueHUDToggle: String { isChinese ? "显示屏幕悬浮提示条 (HUD)" : "Show Floating Queue Pill (HUD)" }
    static var queueCollectToggle: String { isChinese ? "连续收集模式 (⌥⌘C 边复制边入队)" : "Continuous Collect Mode (⌥⌘C)" }
    static var queueUndoAction: String { isChinese ? "回退上一项 (⌘Z / ⌥⌘Z)" : "Rewind Previous Item (⌘Z / ⌥⌘Z)" }
    static var queueCollectStarted: String { isChinese ? "已开启连续收集模式！按 ⌘C 复制的内容将自动加入队列" : "Collect mode on! Copied items will auto-join queue" }
    static var queueCollectStopped: String { isChinese ? "已退出连续收集模式" : "Collect mode off" }

    // Clear Confirmation
    static var clearHistoryConfirmTitle: String {
        isChinese ? "确认清空剪贴板历史？" : "Clear Clipboard History?"
    }
    static var clearHistoryConfirmMessage: String {
        isChinese ? "此操作将清除所有未置顶的历史记录。已置顶的常用条目将被安全保留。" : "This will remove all unpinned history items. Pinned items will be preserved safely."
    }
    static var clearHistoryConfirmAction: String {
        isChinese ? "清空历史" : "Clear History"
    }

    // OCR
    static var copyOCR: String { isChinese ? "拷贝识别出的文字（Vision OCR）" : "Copy Recognized Text (OCR)" }
    static var ocrTitle: String { isChinese ? "文字识别 (OCR)" : "Recognized Text (OCR)" }
    static var ocrCopyButton: String { isChinese ? "拷贝文字" : "Copy Text" }

    // Image QuickLook & Preview
    static var fullSizeQuickLook: String { isChinese ? "全尺寸原图 (Quick Look)" : "Full Size (Quick Look)" }
    static var openInPreviewApp: String { isChinese ? "在「预览」中打开" : "Open in Preview.app" }
    static var doubleClickToZoom: String { isChinese ? "双击查看全尺寸高清原图 (Quick Look)" : "Double-click to view full size (Quick Look)" }

    // Snippets & Alias
    static var setAlias: String { isChinese ? "重命名 / 设置别名（⌘R）..." : "Rename / Set Alias (⌘R)..." }
    static var setAliasTitle: String { isChinese ? "设置别名 / 代码片段名称" : "Set Snippet Alias" }
    static var setAliasPrompt: String { isChinese ? "为该条目指定自定义名称（支持在搜索框快速匹配）：" : "Enter a custom alias for quick search:" }
    static var save: String { isChinese ? "保存" : "Save" }
    static var cancel: String { isChinese ? "取消" : "Cancel" }
    static var clearAlias: String { isChinese ? "清除别名" : "Clear Alias" }

    // Text Transformations
    static var transformMenu: String { isChinese ? "格式转换" : "Transform" }
    static var jsonFormat: String { isChinese ? "JSON 格式化 (Beautify)" : "Format JSON (Beautify)" }
    static var jsonMinify: String { isChinese ? "JSON 压缩 (Minify)" : "Minify JSON (Compact)" }
    static var toCamelCase: String { isChinese ? "转为 camelCase (小驼峰)" : "To camelCase" }
    static var toSnakeCase: String { isChinese ? "转为 snake_case (下划线)" : "To snake_case" }
    static var toKebabCase: String { isChinese ? "转为 kebab-case (短横线)" : "To kebab-case" }
    static var toUpperCase: String { isChinese ? "转为 UPPER_CASE (全大写)" : "To UPPER_CASE" }
    static var toLowerCase: String { isChinese ? "转为 lower_case (全小写)" : "To lower_case" }
    static var urlEncode: String { isChinese ? "URL 编码 (Percent-encode)" : "URL Encode" }
    static var urlDecode: String { isChinese ? "URL 解码" : "URL Decode" }
    static var base64Encode: String { isChinese ? "Base64 编码" : "Base64 Encode" }
    static var base64Decode: String { isChinese ? "Base64 解码" : "Base64 Decode" }

    // Row cells & Types
    static var imageLabel: String { isChinese ? "图片" : "Image" }
    static var fileLabel: String { isChinese ? "文件" : "File" }
    static var justNow: String { isChinese ? "刚刚" : "Just now" }
    static var typeImage: String { isChinese ? "图像" : "Image" }
    static var typeColor: String { isChinese ? "颜色" : "Color" }
    static var typeLinkHint: String { isChinese ? "网页链接 (⌘O 打开)" : "Web Link (⌘O to open)" }

    // Preview
    static var previewTitle: String { isChinese ? "预览" : "QuickLook" }
    static var noSelection: String { isChinese ? "未选中条目" : "No item selected" }
    static func previewImageInfo(w: Int, h: Int) -> String {
        isChinese ? "图片 • \(w) × \(h) 像素" : "Image • \(w) × \(h) pixels"
    }
    static func previewTextInfo(type: String, chars: Int, lines: Int) -> String {
        isChinese ? "\(type) • \(chars) 字符 • \(lines) 行" : "\(type) • \(chars) chars • \(lines) lines"
    }
    static var typeWebLink: String { isChinese ? "网页链接" : "Web Link" }
    static var typeColorCode: String { isChinese ? "颜色色值" : "Color Code" }
    static var typePlainText: String { isChinese ? "纯文本" : "Plain Text" }
    static var typeJSON: String { isChinese ? "JSON 数据" : "JSON Data" }
    static var copyRGB: String { isChinese ? "拷贝 RGB" : "Copy RGB" }
    static var copyHEX: String { isChinese ? "拷贝 HEX" : "Copy HEX" }
    static var copyHSL: String { isChinese ? "拷贝 HSL" : "Copy HSL" }
    static var openInBrowser: String { isChinese ? "在浏览器中打开 (⌘O)" : "Open in Browser (⌘O)" }
    static var sourceFrom: String { isChinese ? "来源: " : "From: " }
    static var alwaysShowPreview: String { isChinese ? "始终常驻右侧预览" : "Always Show Preview Pane" }
    static var previewLayout: String { isChinese ? "预览布局" : "Preview Layout" }
    static var previewLayoutCompact: String { isChinese ? "紧凑（320）" : "Compact (320)" }
    static var previewLayoutAutomatic: String { isChinese ? "自动" : "Automatic" }
    static var previewLayoutWide: String { isChinese ? "宽预览（520）" : "Wide Preview (520)" }
    static var resetSmartPreview: String { isChinese ? "恢复智能宽度" : "Reset to Smart Width" }
    static var previewLayoutManual: String { isChinese ? "手动" : "Manual" }
    static var imageFitPreview: String { isChinese ? "适合预览" : "Fit Preview" }
    static var previewResizeHint: String { isChinese ? "拖动调整预览宽度；双击恢复智能宽度" : "Drag to resize preview; double-click to reset smart width" }
    static var panelResizeHint: String { isChinese ? "拖动调整弹窗宽度" : "Drag to resize panel width" }
    static var scrollToTop: String { isChinese ? "回到顶部" : "Scroll to Top" }
    static var copyAll: String { isChinese ? "复制全部" : "Copy All" }
    static var foldOCR: String { isChinese ? "收起 ▲" : "Collapse ▲" }
    static var unfoldOCR: String { isChinese ? "展开 ▼" : "Expand ▼" }
    static func textCountInfo(chars: Int, lines: Int) -> String {
        isChinese ? "\(chars) 字符 • \(lines) 行" : "\(chars) chars • \(lines) lines"
    }

    // Files & Folders
    static var catFile: String { isChinese ? "文件" : "Files" }
    static var typeFile: String { isChinese ? "文件" : "File" }
    static var typeFolder: String { isChinese ? "文件夹" : "Folder" }
    static func fileItemsCount(_ count: Int) -> String {
        isChinese ? "\(count) 个项目" : "\(count) items"
    }
    static var openFileInFinder: String { isChinese ? "在访达中显示（⌘O）" : "Reveal in Finder (⌘O)" }
    static var fileMissing: String { isChinese ? "原文件已移动或删除" : "Original file moved or deleted" }
    static var filePartiallyMissing: String { isChinese ? "部分文件已丢失" : "Some files are missing" }

    // Hotkey Presets
    static var hotkeySettings: String { isChinese ? "唤出快捷键" : "Shortcut" }
    static var hotkeyPresetDefault: String { isChinese ? "⌘⇧V (默认)" : "⌘⇧V (Default)" }
    static var hotkeyPresetOptSpace: String { isChinese ? "⌥Space (仿 Spotlight)" : "⌥Space (Spotlight style)" }
    static var hotkeyPresetOptV: String { isChinese ? "⌥V (Option + V)" : "⌥V (Option + V)" }
    static var hotkeyPresetCtrlOptV: String { isChinese ? "⌃⌥V (Control + Option + V)" : "⌃⌥V (Control + Option + V)" }
    static var quickPasteToggle: String { isChinese ? "⌘1~⌘9 秒贴" : "⌘1–⌘9 Quick Paste" }

    // App Blacklist
    static var blacklistMenu: String { isChinese ? "排除应用 (不记录剪贴板)" : "Excluded Apps (Ignore Clipboard)" }
    static var excludeCurrentApp: String { isChinese ? "排除当前前台应用: " : "Exclude Frontmost App: " }
    static var noCurrentApp: String { isChinese ? "未检测到前台应用" : "No Active App Detected" }
    static var clearBlacklist: String { isChinese ? "清空所有已排除应用" : "Clear All Excluded Apps" }
    static var blacklistEmpty: String { isChinese ? "(暂无排除应用)" : "(No excluded apps)" }

    // Storage Maintenance
    static var storageMenu: String { isChinese ? "存储与缓存" : "Storage & Cache" }
    static func imageCacheSize(_ size: String) -> String {
        isChinese ? "图片缓存占用: \(size)" : "Image Cache: \(size)"
    }
    static var cleanExpiredImagesAction: String {
        isChinese ? "清理 30 天前过期图片 (保留置顶)" : "Clean Expired Images (>30 days, Keep Pinned)"
    }
    static var cleanAllImageCacheAction: String {
        isChinese ? "清空图片缓存 (保留置顶)" : "Clear All Image Cache (Keep Pinned)"
    }
    static var cleanSuccess: String { isChinese ? "已完成清理" : "Cleanup Complete" }

    // Multi-select separators
    static var mergeSeparatorMenu: String { isChinese ? "合并粘贴为..." : "Merge and Paste As..." }
    static var mergeNewline: String { isChinese ? "换行合并 (↵ 回车)" : "Merge with Newline (↵)" }
    static var mergeComma: String { isChinese ? "逗号合并 (⇧↵ Shift+回车)" : "Merge with Comma (⇧↵)" }
    static var mergeSpace: String { isChinese ? "空格合并" : "Merge with Space" }
    static var mergeNone: String { isChinese ? "无缝直接拼接" : "Merge Directly" }
    static var bottomHintUpdated: String {
        let qp = isQuickPasteEnabled
        if isChinese {
            return qp ? "↵ 粘贴   ⌥↵ 纯文本   Space 预览   ⌘S 填表队列   ⌘1-9 秒贴" : "↵ 粘贴   ⌥↵ 纯文本   Space 预览   ⌘S 填表队列"
        } else {
            return qp ? "↵ Paste   ⌥↵ Plain Text   Space Preview   ⌘S Queue   ⌘1-9 Paste" : "↵ Paste   ⌥↵ Plain Text   Space Preview   ⌘S Queue"
        }
    }
    static func bottomHintMultiSelected(_ count: Int) -> String {
        if isChinese {
            return "↵ 合并粘贴(\(count)项)   ⌘S 填表队列   ⌥↵ 纯文本   Delete 删除"
        } else {
            return "↵ Merge (\(count) items)   ⌘S Queue   ⌥↵ Plain Text   Delete"
        }
    }
}

