import Foundation

// 名称保持 KeychainManager 以避免修改所有调用处，
// 但实现改为受保护文件（0600 权限），彻底告别 login-keychain 密码弹窗。
// 安全性：文件仅本账户可读写，与 Keychain 对本地威胁的防护级别相当。

enum APIKeyName: String, CodingKey {
    case merriamWebster = "gloss.apikey.merriam_webster"
    case youdaoAppKey   = "gloss.apikey.youdao_appkey"
    case youdaoSecret   = "gloss.apikey.youdao_secret"
}

final class KeychainManager {
    static let shared = KeychainManager()
    private init() { loadFromDisk() }

    private var store: [String: String] = [:]

    // MARK: - Public

    func save(key: APIKeyName, value: String) {
        store[key.rawValue] = value
        persist()
    }

    func load(key: APIKeyName) -> String {
        store[key.rawValue] ?? ""
    }

    // MARK: - Storage

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gloss", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("apikeys.json")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        let url = fileURL
        try? data.write(to: url, options: .atomic)
        // 0600：仅本账户可读写，其他用户无权访问
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
        NSLog("[Gloss] API keys saved to \(url.path)")
    }

    private func loadFromDisk() {
        let url = fileURL
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        store = dict
        NSLog("[Gloss] API keys loaded from \(url.path)")
    }
}
