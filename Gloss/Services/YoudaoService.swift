import Foundation
import CryptoKit

final class YoudaoService {
    static let shared = YoudaoService()
    private init() {}

    private let apiURL = "https://openapi.youdao.com/api"

    /// 翻译单词，返回有道翻译结果
    func translate(word: String) async throws -> YoudaoResult {
        let appKey = KeychainManager.shared.load(key: .youdaoAppKey)
        let secret  = KeychainManager.shared.load(key: .youdaoSecret)

        guard !appKey.isEmpty, !secret.isEmpty else {
            throw LookupError.apiKeyMissing("请在设置中填入有道 API Key 和 Secret")
        }

        let salt = UUID().uuidString
        let curtime = String(Int(Date().timeIntervalSince1970))

        // 有道签名：SHA-256(appKey + input + salt + curtime + appSecret)
        let input = makeInput(q: word)
        let signStr = appKey + input + salt + curtime + secret
        let sign = sha256Hex(signStr)

        var components = URLComponents(string: apiURL)!
        components.queryItems = [
            URLQueryItem(name: "q",        value: word),
            URLQueryItem(name: "from",     value: "en"),
            URLQueryItem(name: "to",       value: "zh-CHS"),
            URLQueryItem(name: "appKey",   value: appKey),
            URLQueryItem(name: "salt",     value: salt),
            URLQueryItem(name: "sign",     value: sign),
            URLQueryItem(name: "signType", value: "v3"),
            URLQueryItem(name: "curtime",  value: curtime)
        ]

        guard let url = components.url else {
            throw LookupError.networkError("无效的 URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw LookupError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(YoudaoResult.self, from: data)

        if result.errorCode != "0" {
            throw LookupError.networkError("有道 API 错误码: \(result.errorCode)")
        }

        return result
    }

    // MARK: - Helpers

    /// 有道 input 规则：q.length <= 20 → input = q
    /// 否则 input = q前10字符 + q.length + q后10字符
    private func makeInput(q: String) -> String {
        let len = q.count
        if len <= 20 { return q }
        let start = String(q.prefix(10))
        let end   = String(q.suffix(10))
        return "\(start)\(len)\(end)"
    }

    private func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
