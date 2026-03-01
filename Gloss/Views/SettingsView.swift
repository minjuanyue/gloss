import SwiftUI

struct SettingsView: View {
    @State private var mwKey:      String = ""
    @State private var youdaoKey:  String = ""
    @State private var youdaoSec:  String = ""

    @State private var showMW      = false
    @State private var showYoudao  = false
    @State private var showYoudaoS = false
    @State private var saved       = false

    var body: some View {
        VStack(spacing: 0) {
            // ── 标题 ──
            HStack {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Gloss 设置")
                    .font(.title2.bold())
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            Form {
                // ── 快捷键 ──
                Section {
                    LabeledContent("全局快捷键") {
                        HStack(spacing: 4) {
                            KeyBadge(label: "⌥")
                            KeyBadge(label: "D")
                        }
                    }
                } header: {
                    Text("快捷键").font(.headline)
                }

                // ── MW API ──
                Section {
                    APIKeyField(
                        placeholder: "粘贴你的 API Key",
                        text: $mwKey,
                        isVisible: $showMW
                    )
                    HStack {
                        keyStatusBadge(mwKey)
                        Spacer()
                        Link("申请 Key →",
                             destination: URL(string: "https://dictionaryapi.com/register/index")!)
                            .font(.caption)
                    }
                } header: {
                    Text("Merriam-Webster 词典 API").font(.headline)
                } footer: {
                    Text("Key 仅保存在本机 Keychain 中，不会上传。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // ── 有道 API ──
                Section {
                    APIKeyField(
                        placeholder: "应用 ID (appKey)",
                        text: $youdaoKey,
                        isVisible: $showYoudao
                    )
                    APIKeyField(
                        placeholder: "应用密钥 (secret)",
                        text: $youdaoSec,
                        isVisible: $showYoudaoS
                    )
                    HStack {
                        keyStatusBadge(youdaoKey, and: youdaoSec)
                        Spacer()
                        Link("申请有道 API →",
                             destination: URL(string: "https://ai.youdao.com/")!)
                            .font(.caption)
                    }
                } header: {
                    Text("有道翻译 API（可选）").font(.headline)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Divider()

            // ── 保存 ──
            HStack {
                Spacer()
                if saved {
                    Label("已保存到 Keychain", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Button("保存") { saveKeys() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440)
        .onAppear(perform: loadKeys)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func keyStatusBadge(_ key: String, and extra: String = "ok") -> some View {
        let configured = !key.isEmpty && !extra.isEmpty
        Label(
            configured ? "已配置" : "未配置",
            systemImage: configured ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .font(.caption)
        .foregroundColor(configured ? .green : .secondary)
    }

    // MARK: - Keychain I/O

    private func loadKeys() {
        mwKey     = KeychainManager.shared.load(key: .merriamWebster)
        youdaoKey = KeychainManager.shared.load(key: .youdaoAppKey)
        youdaoSec = KeychainManager.shared.load(key: .youdaoSecret)
    }

    private func saveKeys() {
        KeychainManager.shared.save(key: .merriamWebster, value: mwKey)
        KeychainManager.shared.save(key: .youdaoAppKey,   value: youdaoKey)
        KeychainManager.shared.save(key: .youdaoSecret,   value: youdaoSec)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }
}

// MARK: - APIKeyField

private struct APIKeyField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isVisible {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help(isVisible ? "隐藏" : "显示")
        }
    }
}

// MARK: - KeyBadge

private struct KeyBadge: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
}
