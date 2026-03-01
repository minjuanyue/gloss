import Foundation

// MARK: - 有道翻译 API 响应模型

struct YoudaoResult: Decodable {
    let errorCode: String
    let query: String?
    let translation: [String]?
    let basic: YoudaoBasic?
    let web: [YoudaoWeb]?

    /// 主要中文翻译（取第一条）
    var mainTranslation: String {
        translation?.first ?? ""
    }

    /// 基础释义列表（来自 basic.explains）
    var basicExplains: [String] {
        basic?.explains ?? []
    }
}

struct YoudaoBasic: Decodable {
    let phonetic: String?       // 英式音标
    let usPhonetic: String?     // 美式音标
    let ukPhonetic: String?     // 英式音标
    let explains: [String]?     // 基础释义，如 ["n. 测试", "vt. 测试，检验"]

    enum CodingKeys: String, CodingKey {
        case phonetic
        case usPhonetic = "us-phonetic"
        case ukPhonetic = "uk-phonetic"
        case explains
    }
}

struct YoudaoWeb: Decodable {
    let key: String
    let value: [String]
}
