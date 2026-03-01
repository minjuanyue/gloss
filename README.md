# Gloss

**macOS 菜单栏查词工具** — 在任意应用中选中英文单词，按下 **⌥D**，立即弹出中英双语释义卡片。

A macOS menu bar app for instant word lookup. Select any English word in any app, press **⌥D**, and get a floating card with Chinese translation and detailed English definitions.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 功能 Features

- **全局快捷键** — 在任意应用（Safari、Preview、Word 等）中选中单词，按 ⌥D 立即查词
- **中文释义** — 调用有道翻译 API 获取中文翻译及词性释义
- **英文详细释义** — 调用韦氏词典 API（Merriam-Webster Collegiate），展示：
  - 全部词性（名词、动词、形容词……）
  - 每个词性下的所有释义和例句
  - 词形变化（过去式、名词复数等）
  - 音标发音
- **短语 / 句子翻译** — 选中多个单词时自动切换为纯翻译模式（跳过只支持单词的韦氏 API）
- **悬浮卡片 UI** — 出现在鼠标附近，无标题栏，圆角卡片，点击外部自动消失，内容可滚动
- **无权限回退** — 没有辅助功能权限时，先 ⌘C 复制再按 ⌥D，同样可以查词
- **纯菜单栏应用** — 不占 Dock 位置，常驻菜单栏

---

## 截图 Screenshots

> *(Add screenshots here)*

---

## 环境要求 Requirements

- macOS 13 Ventura 或更高版本
- Xcode 15+
- API Key（见下方申请说明）

---

## 安装与配置 Setup

### 1. 克隆并打开项目

```bash
git clone https://github.com/minjuanyue/gloss.git
cd gloss
open Gloss.xcodeproj
```

### 2. 配置签名

在 Xcode 中选择 **Gloss** Target → **Signing & Capabilities** → 将 **Team** 设置为你的 Apple ID（免费账号即可）。

> 若不配置签名，macOS 14+ 上辅助功能权限可能无法生效。

### 3. 申请 API Key

| 服务 | 用途 | 免费额度 |
|---|---|---|
| [韦氏词典 Merriam-Webster](https://dictionaryapi.com/register/index) | 英文详细释义 | ✅ 1,000 次/天 |
| [有道翻译](https://ai.youdao.com/) | 中文翻译 | ✅ 50 元免费额度 |

两个 Key 均为可选，只填一个也能正常使用。

### 4. 编译运行

在 Xcode 中按 **⌘R**，菜单栏出现书本图标（📖）即为成功。

### 5. 填入 API Key

点击菜单栏图标 → **设置** → 粘贴对应 Key → **保存**。

### 6. 授权辅助功能（推荐）

点击菜单栏图标 → 点击 ⚠️ 条目 → 在弹出的**系统设置 → 隐私与安全性 → 辅助功能**中开启 Gloss。

授权后可直接选词触发，无需手动复制。

---

## 使用方法 Usage

| 场景 | 操作步骤 |
|---|---|
| 已授权辅助功能 | 选中单词或短语 → 按 **⌥D** |
| 未授权辅助功能 | 选中单词或短语 → **⌘C** → 按 **⌥D** |
| 关闭卡片 | 点击卡片以外的任意区域 |

---

## 项目结构 Project Structure

```
Gloss/
├── main.swift                      # 入口点 / App entry point
├── AppDelegate.swift               # 应用生命周期 / App lifecycle
├── AccessibilityManager.swift      # AX API 读取选中文字
├── GlobalHotkeyManager.swift       # Carbon 全局热键注册 (⌥D)
├── StatusBarController.swift       # 菜单栏图标与菜单
├── Models/
│   ├── DictionaryModels.swift      # 韦氏 API 响应模型与解析器
│   └── TranslationModels.swift     # 有道 API 响应模型
├── Services/
│   ├── KeychainManager.swift       # API Key 安全存储（受保护文件）
│   ├── MerriamWebsterService.swift # 韦氏词典 API 客户端
│   └── YoudaoService.swift         # 有道翻译 API 客户端（HMAC-SHA256 签名）
└── Views/
    ├── FloatingWindowController.swift  # NSPanel 悬浮窗（非激活模式）
    ├── LookupView.swift                # SwiftUI 查词结果卡片
    └── SettingsView.swift              # API Key 设置界面
```

---

## 技术说明 Technical Notes

**为什么不启用沙盒？**
应用使用 Carbon `RegisterEventHotKey` 注册全局热键，并通过 `AXUIElement` Accessibility API 读取其他应用中的选中文字，两者均要求在沙盒之外运行。

**API Key 存储**
Key 存储在 `~/Library/Application Support/Gloss/apikeys.json`，文件权限设为 `0600`（仅本账户可读写）。相比传统 macOS Keychain ACL 方案，此方案避免了在使用 ad-hoc 签名开发时反复弹出 login keychain 密码提示框。

**单词 vs. 短语检测**
若输入包含多个词，自动跳过韦氏 API（仅支持单词），仅调用有道翻译并以较大字号展示译文。

---

## Contributing

欢迎提交 Pull Request。较大的改动请先开 Issue 讨论。

Pull requests are welcome. For major changes, please open an issue first.

---

## License

MIT
