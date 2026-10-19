# ClipboardMate

**English** | [中文](README.zh-CN.md)

A lightweight menu-bar clipboard history manager for macOS. Pure Swift and AppKit, with no third-party dependencies.

## Features

- **Automatic capture**: records copied text, rich text (HTML/RTF), images, and Finder files in the background, deduplicates them, and sorts them by time
- **Global shortcut**: press `⌘⇧V` in any app to show or hide the history panel (changeable in the menu to `⌥Space` / `⌥V` / `⌃⌥V`)
- **Keyboard-first interaction**:
    - The first item is selected when the panel opens
    - Use `↓` / `↑` in the search field to move the selection. Separate keywords with spaces (AND)
    - Press `Enter` to paste the selection, keeping HTML/RTF formatting when it exists
    - **`⌥ Enter`**: paste as plain text. For images, paste the OCR text
    - **`⌘C`**: copy to the clipboard only, without simulating a paste, so you can collect several items
    - **`Space`**: toggle the side preview when the search field is empty; otherwise insert a space
    - **`Delete`**: delete the selection when the search field is empty
    - **`⌘O`**: open a link in the browser, or reveal a file in Finder
    - **`Tab` / `⇧Tab`**: cycle the category tabs from the search field
    - **`⌘S` / `⇧⌘S`**: start the paste queue (`⌘S` is FIFO, `⇧⌘S` is LIFO) and close the panel
    - **`⌘A`**: select every item in the current list
- **Paste queue**:
  - **FIFO by default**: items leave the queue in the order they were copied. Copy a name, then a phone number, then an address, and they paste in that same order
  - **Floating HUD**: a small frosted capsule at the bottom of the screen shows the next item (for example `▶ Alex`), the upcoming items, and the remaining count, without taking keyboard focus
  - **`⌥⌘V`**: paste the next queued item into the target form
  - **`⌥⌘Z`**: put the item you just pasted back at the front of the queue
  - **Collect mode (`⌥⌘C`)**: each new copy joins the queue automatically, so you can fill a form without opening the panel
- **Merge and paste a selection**:
  - **`Enter`**: join the selected items with newlines and paste them
  - **`⇧ Enter`**: join them with commas (`, `) and paste them
  - The context menu also offers space-separated, concatenated, and plain-text merges
- **Category filter**: All, Text, Images, Files, Links, and Pinned
- **Sensitive-data filter**: ignores copies from password managers such as 1Password, Bitwarden, and the system password UI
- **Window position**: open at the center of the screen or near the pointer. Centered is the default
- **Haptic feedback**: a light tap when you paste or copy
- **Native UI**: system vibrancy, `⌘1`–`⌘9` badges on the list, and rounded image thumbnails
- **Thumbnail cache**: the list keeps downscaled previews so scrolling through many screenshots stays lighter
- **Pinning**: pin frequent items from the context menu. History capacity applies to unpinned items and to pinned items past the limit
- **Launch at login**: a menu-bar switch. Uses `SMAppService` first, then falls back to a login agent
- **Capacity**: 50 / 100 / 200 / 500 items, default 200
- **Persistence**: history is stored in `~/Library/Application Support/ClipboardMate/` and survives restarts. Each save keeps the previous file as a backup

## Install

Download [ClipboardMate.dmg](https://github.com/lffzdd/ClipboardMate/releases/latest), open it, and drag ClipboardMate into Applications.

The DMG is ad-hoc signed and not notarized. The first time you launch it, right-click the app and choose **Open**. macOS will say the developer cannot be verified; confirm Open. After that, a clipboard icon appears in the menu bar.

**Click the icon** to open history. **Right-click the icon** (or use the gear in the panel) for settings. You can also press `⌘⇧V` in any app, choose an item, and press Return to paste.

### Allow pasting into the previous app (one-time)

Opening the panel and browsing history needs no permission. **Simulating ⌘V** needs Accessibility access:

1. The first time you paste with Return, macOS asks for permission
2. Open **System Settings → Privacy & Security → Accessibility** and turn **ClipboardMate** on
3. Pasting then goes straight back to the previous app. Without permission, or with “Auto-paste on Enter” turned off, the app only writes the clipboard and you can press `⌘V` yourself

`./build.sh` signs the app ad hoc. Rebuilding can drop the Accessibility grant. If Return stops pasting, turn ClipboardMate on again under **System Settings → Privacy & Security → Accessibility**. The menu bar also shows a “Grant Accessibility” item when that happens.

## Build from source

Requires macOS 13 or later.

```bash
git clone https://github.com/lffzdd/ClipboardMate.git
cd ClipboardMate
# Compile and install to /Applications/ClipboardMate.app
./build.sh

# Or build a DMG at build/ClipboardMate.dmg
./package_dmg.sh
```

## Layout

- `Sources/ClipboardMate/main.swift` — entry point
- `Sources/ClipboardMate/AppDelegate.swift` — menu bar, system events, and app lifecycle
- `Sources/ClipboardMate/ClipboardStore.swift` — clipboard watching, storage, paste simulation, and the paste queue
- `Sources/ClipboardMate/PanelController.swift` — history panel and its interactions
- `Sources/ClipboardMate/QueueHUDWindowController.swift` — floating paste-queue capsule
- `Sources/ClipboardMate/HotKey.swift` — global shortcuts through Carbon
- `Sources/ClipboardMate/ClipItem.swift` — item model and serialization
- `Sources/ClipboardMate/QuickLookManager.swift` — Quick Look previews
- `Sources/ClipboardMate/SyntaxHighlighter.swift` — code highlighting
- `Sources/ClipboardMate/MarkdownRenderer.swift` — Markdown preview
- `Sources/ClipboardMate/Localization.swift` — interface strings
- `Sources/ClipboardMate/PinyinHelper.swift` — pinyin and initial-letter search
- `Sources/ClipboardMate/TextTransformer.swift` — case changes and text cleanup

## License

[MIT License](LICENSE) © 2026 lffzdd
