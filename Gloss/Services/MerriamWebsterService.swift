import Foundation

final class MerriamWebsterService {
    static let shared = MerriamWebsterService()
    private init() {}

    private let baseURL = "https://www.dictionaryapi.com/api/v3/references/collegiate/json"

    /// 查询单词，返回解析好的词条列表，或抛出 LookupError
    func lookup(word: String) async throws -> [MWEntry] {
        let apiKey = KeychainManager.shared.load(key: .merriamWebster)
        guard !apiKey.isEmpty else {
            throw LookupError.apiKeyMissing("请在设置中填入 Merriam-Webster API Key")
        }

        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        let urlString = "\(baseURL)/\(encodedWord)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw LookupError.networkError("无效的 URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw LookupError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let items = try JSONDecoder().decode([MWResponseItem].self, from: data)

        // 全是字符串 → 单词未找到，返回建议
        let suggestions = items.compactMap { item -> String? in
            if case .suggestion(let s) = item { return s }
            return nil
        }
        if !suggestions.isEmpty && !items.contains(where: { if case .entry = $0 { return true }; return false }) {
            throw LookupError.wordNotFound(suggestions)
        }

        // 解析词条
        let entries: [MWEntry] = items.compactMap { item in
            if case .entry(let raw) = item { return raw.toDomainModel() }
            return nil
        }

        if entries.isEmpty {
            throw LookupError.wordNotFound([])
        }

        return entries
    }
}
