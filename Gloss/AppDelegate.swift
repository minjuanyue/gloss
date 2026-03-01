import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var hotkeyManager: GlobalHotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，只保留菜单栏
        NSApp.setActivationPolicy(.accessory)

        // 诊断日志
        let trusted = AXIsProcessTrusted()
        NSLog("[Gloss] AXIsProcessTrusted at launch = \(trusted)")
        NSLog("[Gloss] Bundle path = \(Bundle.main.bundlePath)")

        // 检查并引导用户开启辅助功能权限
        AccessibilityManager.shared.checkAndRequestPermissions()

        // 初始化菜单栏控制器
        statusBarController = StatusBarController()

        // 注册全局快捷键 Option+D
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregister()
    }
}
