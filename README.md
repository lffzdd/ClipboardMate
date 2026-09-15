# ClipboardMate

一个为 macOS 打造的轻量剪贴板历史管理器（菜单栏应用），纯 Swift + AppKit 实现，无第三方依赖。

## 功能

- **自动记录**：后台自动捕获复制的文本、富文本（HTML/RTF）、图片和访达文件，去重后按时间排列
- **全局快捷键**：任意应用中按 `⌘⇧V` 呼出/隐藏历史面板（可在菜单中改为 `⌥Space` / `⌥V` / `⌃⌥V`）
- **纯键盘流交互**：
    - 呼出面板自动高亮选中第 1 项
    - 搜索框中可直接按 `↓` / `↑` 切换选择条目；多个关键词用空格分隔（AND）
    - 直接敲 `Enter`（回车）即可粘贴当前选中项（有 HTML/RTF 时保留原格式）
    - **`⌥ Enter`（Option + 回车）**：**纯文本去格式粘贴**；图片则粘贴 OCR 识别出的文字
    - **`⌘ C`**：**仅写入剪贴板**，不触发键盘模拟，方便连续备料收集
    - **`Space`（空格键）**：搜索框为空时展开/收起侧边预览；搜索框有内容时输入空格分词
    - **`Delete`**：搜索框为空时删除选中条目
    - **`⌘ O`**：链接在浏览器中打开；文件在访达中显示
    - **`Tab` / `⇧Tab`**：在搜索框中快速循环切换分类标签
    - **`⌘ S` / `⇧⌘ S`**：**一键启动填表队列**（`⌘S` 为 FIFO 先复制先贴，`⇧⌘S` 为 LIFO 倒序），面板立即自动关闭
    - **`⌘ A`**：全选当前列表所有条目
- **填表队列（Sequential Paste Queue 进阶体验）**：
  - **智能 FIFO 先入先出**：默认按条目实际复制的时间先后顺序出队，复制姓名 ➔ 电话 ➔ 地址，粘贴即按姓名 ➔ 电话 ➔ 地址输出
  - **屏幕悬浮微型 HUD 胶囊**：启动后屏幕底部浮现毛玻璃胶囊窗口，实时高亮当前待粘贴项（`▶ 张三`）、排队队列与剩余进度，不夺取输入焦点
  - **全局逐项粘贴 `⌥⌘V`**：在目标表单中按一次贴一项
  - **队列容错回退 `⌥⌘Z`**：手滑按快或贴错位置时，一键把刚刚弹出的一项重新塞回队列头部
  - **边复制边入队的「连续收集模式」`⌥⌘C`**：开启后，复制的每一段内容像“购物车加购”般自动入队，无需打开面板即可切到表单连续粘贴
- **多选合并直接粘贴**：
  - 选中多项后按 **`Enter`（回车）**：按换行符（`\n`）将选中的多条记录合并直接粘贴
  - **`⇧ Enter`（Shift + 回车）**：按逗号分隔符（`, `）合并粘贴
  - 右键支持换行、逗号、空格、紧凑拼接或纯文本合并等多种方式
- **顶部分类筛选**：支持 `[全部]`、`[文本]`、`[图片]`、`[文件]`、`[链接]`、`[📌置顶]` 六大分类一键过滤
- **安全防泄密保护**：自动忽略 1Password、Bitwarden、系统密码等密码管理器的敏感剪贴板数据
- **屏幕居中 / 跟随鼠标**：可在菜单中自由切换弹出位置，默认推荐视野最舒适的屏幕正上方偏中位置
- **触控板触觉反馈**：在执行粘贴或拷贝时，调用系统触觉引擎提供清脆干脆的物理确认感
- **原生现代 UI**：采用系统级毛玻璃（`NSVisualEffectView`）半透明效果，列表带 `⌘1~⌘9` 快捷键徽标，图片带精致圆角
- **缩略图缓存**：列表只缓存缩小后的预览图，大量截图滚动时更省内存
- **置顶与管理**：右键条目可置顶常用内容；历史容量对未置顶和超额置顶条目一并生效
- **开机自启动**：菜单栏内置开机启动开关（优先 `SMAppService`，失败时回退到 Login Agent）
- **容量可调**：可在菜单栏自由切换历史保留条数（50 / 100 / 200 / 500 条，默认 200 条）
- **持久化**：历史保存在 `~/Library/Application Support/ClipboardMate/`，重启不丢失；写入时保留上一份备份

## 安装 / 使用

1. 应用已安装到 `/Applications/ClipboardMate.app` 并自动启动，菜单栏会出现剪贴板图标
2. **点击图标**呼出历史面板，**右键图标**（或面板齿轮）打开设置
3. 也可以在任意应用中按 `⌘⇧V` 呼出历史面板，选择条目后按回车粘贴

### 授权「粘贴到原应用」（一次性设置）

「呼出面板、浏览历史」无需任何权限；但**模拟 ⌘V 粘贴**需要辅助功能权限：

1. 第一次用回车粘贴时，系统会自动弹出授权提示
2. 打开 **系统设置 → 隐私与安全性 → 辅助功能**，把 **ClipboardMate** 打开
3. 之后粘贴即可一步到位；未授权或关闭「回车自动粘贴」时，应用只把内容复制到剪贴板，你手动 `⌘V` 也可以

`./build.sh` 使用 ad-hoc 签名。每次重新编译安装后，系统可能丢掉辅助功能授权。若回车粘贴突然失效，到 **系统设置 → 隐私与安全性 → 辅助功能** 里重新打开 ClipboardMate。菜单栏顶部也会出现「需要辅助功能权限」入口。

## 构建与打包

```bash
# 编译并直接部署到本地 /Applications/ClipboardMate.app
./build.sh

# 编译并打包为独立的 DMG 安装镜像 (build/ClipboardMate.dmg)
./package_dmg.sh
```

## 文件结构

- `Sources/ClipboardMate/main.swift` — 应用入口
- `Sources/ClipboardMate/AppDelegate.swift` — 菜单栏、系统事件装配与生命周期管理
- `Sources/ClipboardMate/ClipboardStore.swift` — 剪贴板监听、持久化存储、模拟粘贴与填表队列调度
- `Sources/ClipboardMate/PanelController.swift` — 毛玻璃历史主面板与交互控制器
- `Sources/ClipboardMate/QueueHUDWindowController.swift` — 填表队列屏幕悬浮微型 HUD 胶囊
- `Sources/ClipboardMate/HotKey.swift` — Carbon 底层全局快捷键注册与监听
- `Sources/ClipboardMate/ClipItem.swift` — 数据模型与格式序列化
- `Sources/ClipboardMate/QuickLookManager.swift` — 原生 QuickLook 快速预览
- `Sources/ClipboardMate/SyntaxHighlighter.swift` — 代码语法高亮引擎
- `Sources/ClipboardMate/MarkdownRenderer.swift` — Markdown 格式预览渲染
- `Sources/ClipboardMate/Localization.swift` — 多语言本地化支持
- `Sources/ClipboardMate/PinyinHelper.swift` — 中文拼音及首字母搜索辅助
- `Sources/ClipboardMate/TextTransformer.swift` — 大小写转换、格式清理等文本转换工具

## License

[MIT License](LICENSE) © 2026 lffzdd
