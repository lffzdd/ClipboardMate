# ClipboardMate

[English](README.md) | **中文**

<!--
  图片位置 — 把 Mac 上截的图按同名文件放进来，中英文 README 会一起用上。
  docs/hero.png              首屏：菜单栏图标 + 真实桌面上的历史面板
  docs/history-panel.png     历史面板，列表和底部提示要看得见
  docs/search.png            搜索，最好是拼音命中中文
  docs/markdown-preview.png  侧边预览：Markdown 和带高亮的代码块
  docs/paste-queue-hud.png   悬浮的填表队列胶囊
  docs/preferences.png       偏好设置菜单（菜单栏右键，或面板里的齿轮）
  docs/demo.gif              逐项粘贴：每贴一项，队列往前走一格
-->

<p align="center">
  <img src="docs/hero.png" alt="菜单栏里的 ClipboardMate，历史面板已打开" width="920">
</p>

<p align="center">
  <strong>姓名、电话、地址，按复制的顺序，一项一项贴进表单。</strong>
</p>

<p align="center">
  <a href="https://github.com/lffzdd/ClipboardMate/releases/latest"><img src="https://img.shields.io/github/v/release/lffzdd/ClipboardMate?style=flat-square&label=release&color=007AFF" alt="最新版本"></a>
  <a href="https://github.com/lffzdd/ClipboardMate/releases/latest"><img src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple&logoColor=white" alt="macOS 13 或更高"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/lffzdd/ClipboardMate?style=flat-square" alt="MIT 许可证"></a>
  <a href="https://github.com/lffzdd/ClipboardMate/releases/latest"><img src="https://img.shields.io/github/downloads/lffzdd/ClipboardMate/total?style=flat-square&color=34C759" alt="下载量"></a>
</p>

<p align="center">
  <a href="https://github.com/lffzdd/ClipboardMate/releases/latest"><img src="https://img.shields.io/badge/下载-ClipboardMate.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="下载 ClipboardMate.dmg"></a>
</p>

<p align="center">
  <a href="https://github.com/lffzdd/ClipboardMate/releases/latest">下载最新的 ClipboardMate.dmg</a>
  · 菜单栏应用 · 纯 Swift · 不用注册
</p>

ClipboardMate 住在菜单栏里。你复制的纯文本、HTML / RTF、图片和访达文件，它都会记下。在任意应用里按 <kbd>⌘⇧V</kbd>，回车，内容就贴回你刚才所在的窗口。

真正会让你留下来的是填表队列。按表单顺序复制好每一项，按 <kbd>⌘S</kbd>，屏幕底部浮出一颗毛玻璃胶囊。它标出下一项，以及排在后面的几项，并且不抢走键盘。每按一次 <kbd>⌘V</kbd>，就填进下一个格子。

## 为什么是 ClipboardMate

| 按顺序填完一张表 | 手不用离开键盘 | 就在这台 Mac 上 |
| --- | --- | --- |
| 先复制的先贴。胶囊显示下一项；贴错了，<kbd>⌘Z</kbd> 把它塞回队列最前。 | 面板一打开，第一行已经选中。回车即贴。<kbd>⌘1</kbd>–<kbd>⌘9</kbd> 直接贴某一行。 | 纯 Swift 和 AppKit，没有第三方库。历史留在「应用程序支持」里。密码管理器里复制的内容会被跳过。 |

## 看一眼

### 一个快捷键，历史就在眼前

<!-- image-slot: docs/history-panel.png — 历史面板 -->

<p align="center">
  <img src="docs/history-panel.png" alt="带分类、列表和底部粘贴提示的历史面板" width="820">
</p>

点菜单栏图标，或按 <kbd>⌘⇧V</kbd>。文本、图片、文件、链接和颜色排成一列，最新的在最上面，前九行标着 <kbd>⌘1</kbd>–<kbd>⌘9</kbd>。用 **全部 · 文本 · 图片 · 文件 · 链接 · 置顶** 过滤。常用的钉住。按 <kbd>⌘R</kbd> 起一个别名，之后用这个名字就能搜到。

### 搜索，包括拼音

<!-- image-slot: docs/search.png — 搜索，最好能看到拼音 -->

<p align="center">
  <img src="docs/search.png" alt="用拼音搜到中文剪贴板内容" width="820">
</p>

直接在搜索框里打。空格分开的每个词都要命中。中文可以按汉字、全拼或首字母匹配 —— 输入 `zs` 能找到「张三」。很长的内容，会在开头约四千字里匹配。<kbd>Esc</kbd> 先清掉搜索，再关面板。

### Markdown 和代码，打开就是排好的

<!-- image-slot: docs/markdown-preview.png — Markdown 与代码预览 -->

<p align="center">
  <img src="docs/markdown-preview.png" alt="侧边预览里的 Markdown 和带语法高亮的代码块" width="820">
</p>

搜索框是空的时候，按 <kbd>Space</kbd> 展开侧边预览。Markdown 可以看排版，也可以看原文。围栏里的代码会高亮，点一下就复制这一块。图片会做文字识别（Vision OCR），<kbd>⌥↵</kbd> 把识别出的字贴出去。链接用 <kbd>⌘O</kbd> 在浏览器打开。文件在访达里显示。十六进制颜色会画出色块，并能复制 HEX、RGB 或 HSL。图片双击进入快速查看。

### 填表队列胶囊

<!-- image-slot: docs/paste-queue-hud.png — 悬浮填表队列 -->

<p align="center">
  <img src="docs/paste-queue-hud.png" alt="显示下一项的悬浮填表队列胶囊" width="520">
</p>

<!-- image-slot: docs/demo.gif — 逐项粘贴演示 -->

<p align="center">
  <img src="docs/demo.gif" alt="表单随着填表队列逐项被填上" width="820">
</p>

四步：

1. 先复制姓名，再复制电话，再复制地址。
2. 按 <kbd>⌘S</kbd>。面板关掉。胶囊显示下一项、后面最多三条，以及还剩几项。<kbd>⇧⌘S</kbd> 则按相反的顺序出队。
3. 点进第一个格子。<kbd>⌘V</kbd> 贴上，胶囊往前走一格。（队列进行时，默认可以直接用 <kbd>⌘V</kbd> / <kbd>⌘Z</kbd>。<kbd>⌥⌘V</kbd> 和 <kbd>⌥⌘Z</kbd> 始终可用。）
4. 贴错格子了？<kbd>⌘Z</kbd> 把这一项放回队列最前。<kbd>Esc</kbd>，或胶囊上的 ✕，清空队列。

**连续收集**（<kbd>⌥⌘C</kbd>）是同一条队列的另一种用法：之后每次复制都会自动入队。不用打开面板，先把字段收齐，再去表单里逐项贴。

选中多行后按回车，会用换行把它们拼成一段再贴。<kbd>⇧↵</kbd> 则用逗号拼接。右键里还可以选空格、无缝拼接，或纯文本。

### 偏好设置

<!-- image-slot: docs/preferences.png — 偏好设置菜单 -->

<p align="center">
  <img src="docs/preferences.png" alt="从菜单栏打开的偏好设置" width="420">
</p>

右键菜单栏图标，或点面板里的齿轮。

| | |
| --- | --- |
| 唤出快捷键 | <kbd>⌘⇧V</kbd>、<kbd>⌥Space</kbd>、<kbd>⌥V</kbd> 或 <kbd>⌃⌥V</kbd>。<kbd>⌘1</kbd>–<kbd>⌘9</kbd> 可以关掉。 |
| 开机自启动 | 在菜单里打开。优先用系统登录项；若系统拒绝，则回退到 Login Agent。 |
| 面板 | 再次打开时保留搜索和分类。点到面板外关闭，或切换应用时关闭（立刻，或延迟几秒）。搜索框旁的图钉让这一次保持打开。 |
| 外观 | 玻璃透明度。在屏幕居中打开，或跟着指针。预览可以始终展开，宽度可选紧凑、自动或宽预览。 |
| 历史容量 | 50、100、200 或 500 条，默认 200。清空历史时，已置顶的条目会留下。 |
| 界面语言 | 跟随系统、简体中文或 English。 |
| 填表队列 | 先复制先贴、后复制先贴，或按列表顺序。显示或隐藏胶囊。队列进行时是否让 <kbd>⌘V</kbd> / <kbd>⌘Z</kbd> 直接操作。 |
| 隐私 | 忽略密码管理器里的复制（1Password、Bitwarden、LastPass、KeePassXC、苹果「密码」等）以及标记为隐藏的剪贴板类型。其他应用可以按名字排除。 |
| 存储 | 查看图片缓存大小，清理 30 天前的图片，去掉文件已经不在的历史条目。 |

删掉一行，面板会告诉你。<kbd>⌘Z</kbd> 可以恢复。**清空历史** 同样能撤销。

## 快捷键

| | |
| --- | --- |
| <kbd>⌘⇧V</kbd> | 显示或隐藏历史。可在偏好设置里更换。 |
| <kbd>↵</kbd> | 粘贴选中项。多选时用换行合并。原来带 HTML / RTF 的会保留格式。 |
| <kbd>⇧↵</kbd> | 用逗号合并后粘贴。 |
| <kbd>⌥↵</kbd> | 作为纯文本粘贴。图片则粘贴识别出的文字。 |
| <kbd>⌘C</kbd> | 只复制到剪贴板。 |
| <kbd>⌘1</kbd>–<kbd>⌘9</kbd> | 粘贴对应的那一行。 |
| <kbd>Space</kbd> | 搜索框为空时切换预览；有内容时就是输入空格。 |
| <kbd>⌘O</kbd> | 打开链接，或在访达中显示文件。 |
| <kbd>⌘P</kbd> | 置顶或取消置顶。 |
| <kbd>⌘R</kbd> | 重命名 / 设置别名。 |
| <kbd>⌘S</kbd> / <kbd>⇧⌘S</kbd> | 启动填表队列：先复制先贴，或后复制先贴。 |
| <kbd>⌘A</kbd> | 全选当前列表。 |
| <kbd>⌘Z</kbd> | 面板打开时，撤销上一次删除或清空。 |
| <kbd>Delete</kbd> | 搜索框为空时删除选中项。 |
| <kbd>Tab</kbd> / <kbd>⇧Tab</kbd> | 切换顶部分类。 |
| <kbd>↑</kbd> <kbd>↓</kbd> | 移动选中项，在搜索框里也行。 |
| <kbd>⌥⌘V</kbd> | 粘贴队列中的下一项。 |
| <kbd>⌥⌘Z</kbd> | 把刚贴出的一项放回队列最前。 |
| <kbd>⌥⌘C</kbd> | 打开或关闭连续收集。 |
| <kbd>Esc</kbd> | 清除搜索、关闭面板，或清空队列。 |

菜单栏里的 **快捷键说明…** 有同样一份清单。

右键条目还可以：编辑文本、格式化或压缩 JSON、改大小写（`camelCase`、`snake_case`、`kebab-case`、全大写、全小写）、URL 编解码、Base64 编解码。

## 安装

1. 下载 [ClipboardMate.dmg](https://github.com/lffzdd/ClipboardMate/releases/latest)。
2. 打开，把 **ClipboardMate** 拖进「应用程序」。
3. 这个磁盘映像是临时签名，没有公证。第一次打开时，请右键应用并选择**打开**。系统会提示无法验证开发者，确认**打开**即可。之后菜单栏会出现剪贴板图标。
4. 点图标看历史。右键图标，或点面板里的齿轮，打开偏好设置。也可以在任意应用里按 <kbd>⌘⇧V</kbd>，选中一行，按回车。

### 让回车直接贴回上一个应用

浏览历史不需要任何权限。模拟 <kbd>⌘V</kbd> 需要一次辅助功能授权：

1. 第一次用回车粘贴时，系统会询问。
2. 打开 **系统设置 → 隐私与安全性 → 辅助功能**，打开 **ClipboardMate**。
3. 之后回车会直接贴回去。未授权，或关掉「回车自动粘贴」时，应用只写入剪贴板，你自己按 <kbd>⌘V</kbd> 即可。

`./build.sh` 会重新做临时签名，系统可能丢掉这项授权。如果回车突然不贴了，到辅助功能里把 ClipboardMate 再打开一次。出现这种情况时，菜单栏会显示 **需要辅助功能权限才能自动粘贴…**。更新版本之后，也需要重新授权一次。

## 从源码构建

需要 macOS 13 或更高版本。

```bash
git clone https://github.com/lffzdd/ClipboardMate.git
cd ClipboardMate
./build.sh          # 编译并安装到 /Applications/ClipboardMate.app
./package_dmg.sh    # 或生成 build/ClipboardMate.dmg
```

## 文件结构

| | |
| --- | --- |
| `main.swift` | 入口 |
| `AppDelegate.swift` | 菜单栏、偏好设置、生命周期 |
| `ClipboardStore.swift` | 剪贴板监听、存储、模拟粘贴、填表队列 |
| `PanelController.swift` | 历史面板 |
| `QueueHUDWindowController.swift` | 悬浮填表队列胶囊 |
| `HotKey.swift` | 通过 Carbon 注册全局快捷键 |
| `ClipItem.swift` | 条目模型 |
| `MarkdownRenderer.swift` / `SyntaxHighlighter.swift` | Markdown 预览与代码着色 |
| `PinyinHelper.swift` | 拼音与首字母搜索 |
| `TextTransformer.swift` | 大小写、JSON、URL、Base64 转换 |
| `QuickLookManager.swift` | 快速查看 |
| `Localization.swift` | 中英文字符串 |

历史保存在 `~/Library/Application Support/ClipboardMate/`。每次写入都会留下上一份备份。

## 许可证

[MIT](LICENSE) © 2026 lffzdd
