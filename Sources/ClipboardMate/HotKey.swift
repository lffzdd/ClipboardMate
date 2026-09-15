import Carbon.HIToolbox
import Foundation

/// 预设唤出快捷键枚举
enum HotkeyPreset: String, CaseIterable {
    case cmdShiftV = "cmdShiftV"
    case optSpace = "optSpace"
    case optV = "optV"
    case ctrlOptV = "ctrlOptV"

    var title: String {
        switch self {
        case .cmdShiftV: return L10n.hotkeyPresetDefault
        case .optSpace: return L10n.hotkeyPresetOptSpace
        case .optV: return L10n.hotkeyPresetOptV
        case .ctrlOptV: return L10n.hotkeyPresetCtrlOptV
        }
    }

    var shortcutGlyph: String {
        switch self {
        case .cmdShiftV: return "⌘⇧V"
        case .optSpace: return "⌥Space"
        case .optV: return "⌥V"
        case .ctrlOptV: return "⌃⌥V"
        }
    }

    var keyConfig: (keyCode: UInt32, modifiers: UInt32) {
        switch self {
        case .cmdShiftV:
            return (UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey))
        case .optSpace:
            return (UInt32(kVK_Space), UInt32(optionKey))
        case .optV:
            return (UInt32(kVK_ANSI_V), UInt32(optionKey))
        case .ctrlOptV:
            return (UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey))
        }
    }
}

final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID: EventHotKeyID
    var onKeyDown: (() -> Void)?
    private(set) var isRegistered = false
    private(set) var currentKeyCode: UInt32 = 0
    private(set) var currentModifiers: UInt32 = 0

    init(id: UInt32 = 1, keyCode: UInt32, modifiers: UInt32, autoRegister: Bool = true, onKeyDown: @escaping () -> Void) {
        self.hotKeyID = EventHotKeyID(signature: OSType(0x4853_4B31), id: id)
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        self.onKeyDown = onKeyDown
        setupHandler()
        if autoRegister {
            _ = register(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func setupHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handler: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var actualID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &actualID
                )
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                guard status == noErr,
                      actualID.signature == hotKey.hotKeyID.signature,
                      actualID.id == hotKey.hotKeyID.id else {
                    return OSStatus(eventNotHandledErr)
                }
                hotKey.onKeyDown?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handler
        )
        self.eventHandler = handler
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRef = ref
            isRegistered = true
            return true
        }
        hotKeyRef = nil
        isRegistered = false
        return false
    }

    func pause() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        isRegistered = false
    }

    @discardableResult
    func resume() -> Bool {
        guard currentKeyCode != 0, hotKeyRef == nil else { return isRegistered }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(currentKeyCode, currentModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRef = ref
            isRegistered = true
            return true
        }
        hotKeyRef = nil
        isRegistered = false
        return false
    }

    func unregister() {
        pause()
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
