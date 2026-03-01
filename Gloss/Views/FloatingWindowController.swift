import AppKit
import SwiftUI

/// 悬浮查词面板（NSPanel 风格，非激活，点击外部自动消失）
final class FloatingWindowController {
    static let shared = FloatingWindowController()
    private init() {}

    private var panel: NSPanel?
    private var monitor: Any?   // 全局鼠标点击监听，用于自动关闭

    // MARK: - 展示

    func showLookup(for word: String) {
        // 关闭旧面板
        dismiss()

        let panel = makePanel()
        self.panel = panel

        // 设置 SwiftUI 内容
        let lookupView = LookupView(word: word) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: lookupView)
        hosting.frame = NSRect(x: 0, y: 0, width: 360, height: 480)
        panel.contentView = hosting

        // 位置：鼠标附近，保持在屏幕内
        let origin = calcOrigin(panelSize: NSSize(width: 360, height: 480))
        panel.setFrameOrigin(origin)

        panel.orderFrontRegardless()

        // 监听点击面板外部 → 关闭
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return }
            let loc = event.locationInWindow
            let screenLoc = NSEvent.mouseLocation
            if !NSPointInRect(screenLoc, panel.frame) {
                self.dismiss()
            }
        }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    // MARK: - Helpers

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func calcOrigin(panelSize: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(mouse, $0.frame) })
                ?? NSScreen.main else {
            return NSPoint(x: mouse.x + 12, y: mouse.y - panelSize.height - 12)
        }

        let screenFrame = screen.visibleFrame
        var x = mouse.x + 12
        var y = mouse.y - panelSize.height - 12

        // 避免超出右边
        if x + panelSize.width > screenFrame.maxX {
            x = mouse.x - panelSize.width - 12
        }
        // 避免超出下边
        if y < screenFrame.minY {
            y = mouse.y + 12
        }
        // 避免超出上边
        if y + panelSize.height > screenFrame.maxY {
            y = screenFrame.maxY - panelSize.height - 8
        }

        return NSPoint(x: x, y: y)
    }
}
