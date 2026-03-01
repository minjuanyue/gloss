import AppKit
import SwiftUI

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private let menu = NSMenu()
    private var accessMenuItem: NSMenuItem!
    private var restartMenuItem: NSMenuItem!
    private var settingsWindowController: NSWindowController?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "book.fill",
                                   accessibilityDescription: "Gloss 查词")
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    // MARK: - Menu（只构建一次）

    private func buildMenu() {
        let titleItem = NSMenuItem()
        titleItem.view = makeMenuHeaderView()
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(title: "快捷键：Option+D", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        menu.addItem(.separator())

        // 权限状态（动态）
        accessMenuItem = NSMenuItem(title: "", action: #selector(openAccessibilityPrefs), keyEquivalent: "")
        accessMenuItem.target = self
        menu.addItem(accessMenuItem)

        // 重启按钮（权限已改但需重启时显示）
        restartMenuItem = NSMenuItem(title: "🔄 重启 Gloss 使权限生效", action: #selector(relaunchApp), keyEquivalent: "")
        restartMenuItem.target = self
        restartMenuItem.isHidden = true
        menu.addItem(restartMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Gloss", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        NSLog("[Gloss] menuWillOpen: AXIsProcessTrusted = \(trusted)")

        if trusted {
            accessMenuItem.title  = "✅ 辅助功能已授权（选词后 Option+D）"
            accessMenuItem.action = nil
            restartMenuItem.isHidden = true
        } else {
            // 未授权时仍可用——Cmd+C 复制后 Option+D 查词
            accessMenuItem.title  = "⚠️ 未授权（先 Cmd+C 再 Option+D 仍可查词）"
            accessMenuItem.action = #selector(openAccessibilityPrefs)
            restartMenuItem.isHidden = false
        }
    }

    // MARK: - Actions

    @objc private func openAccessibilityPrefs() {
        // 先用 tccutil 清除可能存在的过期记录，让系统重新识别当前二进制
        resetTCC()

        // 打开系统设置 > 隐私与安全 > 辅助功能
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 通过 tccutil 清除当前 app 的 Accessibility 授权记录，
    /// 让 macOS 重新识别当前二进制并展示授权入口
    private func resetTCC() {
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments  = ["reset", "Accessibility", "com.minjuan.Gloss"]
        try? task.run()
        task.waitUntilExit()
        NSLog("[Gloss] tccutil reset Accessibility exit code: \(task.terminationStatus)")
    }

    @objc private func relaunchApp() {
        let path = Bundle.main.bundlePath
        NSLog("[Gloss] Relaunching from: \(path)")
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments  = [path]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Gloss 设置"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 360))
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeMenuHeaderView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 36))
        let label = NSTextField(labelWithString: "Gloss 查词")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.frame = NSRect(x: 14, y: 8, width: 172, height: 20)
        view.addSubview(label)
        return view
    }
}
