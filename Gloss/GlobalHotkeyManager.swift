import AppKit
import Carbon

/// 负责注册和响应全局快捷键 Option+D
final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // 用于在 C 回调中反查 Swift 对象
    private var selfPtr: UnsafeMutableRawPointer?

    // MARK: - 注册

    func register() {
        selfPtr = Unmanaged.passRetained(self).toOpaque()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // Option+D: kVK_ANSI_D = 0x02, optionKey = 0x0800
        var hotKeyID = EventHotKeyID(signature: fourCharCode("GLSS"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
        if let ptr = selfPtr {
            Unmanaged<GlobalHotkeyManager>.fromOpaque(ptr).release()
            selfPtr = nil
        }
    }

    // MARK: - 响应

    fileprivate func handleHotkey() {
        DispatchQueue.main.async {
            guard let result = AccessibilityManager.shared.getSelectedText() else {
                NSLog("[Gloss] 未获取到选中文字（AX 未授权且剪贴板为空）")
                return
            }

            // 保留完整选中文本（单词 / 短语 / 句子均可）
            // 只做基础清理：合并连续空白、去首尾空格
            let text = result.text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            NSLog("[Gloss] 查询: '\(text)'，来源: \(result.source)")
            FloatingWindowController.shared.showLookup(for: text)
        }
    }

    deinit {
        unregister()
    }
}

// MARK: - Carbon 回调（C 函数风格）

private let hotkeyCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
    guard let userData = userData else { return noErr }
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotkey()
    return noErr
}

// MARK: - FourCC Helper

private func fourCharCode(_ string: String) -> FourCharCode {
    let bytes = string.utf8.prefix(4)
    var result: FourCharCode = 0
    for byte in bytes {
        result = (result << 8) | FourCharCode(byte)
    }
    return result
}
