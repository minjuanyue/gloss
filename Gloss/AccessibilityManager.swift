import AppKit
import ApplicationServices

final class AccessibilityManager {
    static let shared = AccessibilityManager()
    private init() {}

    // MARK: - 权限状态

    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    func checkAndRequestPermissions() {
        guard !isAccessibilityEnabled else { return }
        NSLog("[Gloss] Accessibility NOT trusted at launch")
    }

    // MARK: - 获取选中文字

    /// 优先用 AX API 读取选中文字；
    /// 若无权限则回退到读取剪贴板（需要用户先 Cmd+C）。
    func getSelectedText() -> (text: String, source: TextSource)? {
        // 方法一：AX API（需要辅助功能权限）
        if isAccessibilityEnabled,
           let text = selectedTextViaAX(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), .accessibility)
        }

        // 方法二：读取剪贴板（无需权限，用户需先 Cmd+C 复制）
        if let text = NSPasteboard.general.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed, .clipboard)
        }

        return nil
    }

    // MARK: - Private

    private func selectedTextViaAX() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focused = focusedRef else { return nil }

        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement,
                                            kAXSelectedTextAttribute as CFString,
                                            &selectedRef) == .success,
              let text = selectedRef as? String else { return nil }
        return text
    }
}

enum TextSource {
    case accessibility
    case clipboard
}
