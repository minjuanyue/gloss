import Foundation

// MARK: - Merriam-Webster API Models

/// 单次查词的完整结果（聚合翻译+词典）
struct LookupResult {
    let word: String
    var translation: YoudaoResult?
    var entries: [MWEntry]
    var error: LookupError?
}

enum LookupError: Error {
    case wordNotFound([String])   // 单词不存在，返回候选词
    case networkError(String)
    case apiKeyMissing(String)
    case decodingError(String)
}

// MARK: - MW Entry

struct MWEntry: Identifiable {
    let id: String          // meta.id
    let headword: String    // hwi.hw（带音节点，如 "hel*lo"）
    let pronunciation: String?  // IPA 发音
    let functionalLabel: String // fl: noun / verb / adjective …
    let inflections: [MWInflection]
    let senses: [MWSense]
    let shortDefs: [String]
}

struct MWInflection: Identifiable {
    let id = UUID()
    let label: String?     // 变形标签，如 "past tense"
    let form: String       // 变形形式，如 "tested"
}

struct MWSense: Identifiable {
    let id = UUID()
    let senseNumber: String?   // "1 a", "b", "2" …
    let definition: String
    let examples: [String]
}

// MARK: - Raw MW JSON Decoding

struct MWRawResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case meta, hom, hwi, fl, def, ins, shortdef
    }

    let meta: MWMeta?
    let hom: Int?
    let hwi: MWHwi?
    let fl: String?
    let def: [MWDef]?
    let ins: [MWIns]?
    let shortdef: [String]?

    // MW 响应可能是词条对象，也可能是建议字符串
    // 通过自定义容器解码处理混合数组
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decodeIfPresent(MWMeta.self, forKey: .meta)
        hom = try container.decodeIfPresent(Int.self, forKey: .hom)
        hwi = try container.decodeIfPresent(MWHwi.self, forKey: .hwi)
        fl = try container.decodeIfPresent(String.self, forKey: .fl)
        def = try container.decodeIfPresent([MWDef].self, forKey: .def)
        ins = try container.decodeIfPresent([MWIns].self, forKey: .ins)
        shortdef = try container.decodeIfPresent([String].self, forKey: .shortdef)
    }
}

struct MWMeta: Decodable {
    let id: String
    let stems: [String]?
}

struct MWHwi: Decodable {
    let hw: String
    let prs: [MWPrs]?
}

struct MWPrs: Decodable {
    let mw: String?   // Merriam-Webster 音标
    let ipa: String?  // IPA
}

struct MWIns: Decodable {
    let ifc: String?  // inflection form cutback label
    let if_: String?  // inflected form
    let il: String?   // inflection label

    enum CodingKeys: String, CodingKey {
        case ifc
        case if_ = "if"
        case il
    }
}

struct MWDef: Decodable {
    let sseq: [[MWSseqElement]]

    struct MWSseqElement: Decodable {
        // sseq 每个元素是 [type, value] 数组
        // type: "sense", "pseq", "bs" 等
        var type: String = ""
        var sense: MWSenseRaw?

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            type = (try? container.decode(String.self)) ?? ""
            if type == "sense" || type == "bs" {
                if type == "bs" {
                    // bs 包装一层
                    struct BSWrapper: Decodable {
                        let sense: MWSenseRaw?
                    }
                    if let bs = try? container.decode(BSWrapper.self) {
                        sense = bs.sense
                    }
                } else {
                    sense = try? container.decode(MWSenseRaw.self)
                }
            }
        }
    }
}

struct MWSenseRaw: Decodable {
    let sn: String?     // sense number
    let dt: [MWDtElement]?

    struct MWDtElement: Decodable {
        var tag: String = ""
        var text: String?
        var vis: [MWVisItem]?

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            tag = (try? container.decode(String.self)) ?? ""
            if tag == "text" {
                text = try? container.decode(String.self)
            } else if tag == "vis" {
                vis = try? container.decode([MWVisItem].self)
            }
        }
    }
}

struct MWVisItem: Decodable {
    let t: String?
}

// MARK: - Conversion MW Raw → Domain Model

extension MWRawResponse {
    func toDomainModel() -> MWEntry? {
        guard let meta = meta, let fl = fl else { return nil }

        let headword = hwi?.hw.replacingOccurrences(of: "*", with: "·") ?? meta.id
        let pronunciation: String? = hwi?.prs?.first?.mw ?? hwi?.prs?.first?.ipa

        let inflections: [MWInflection] = (ins ?? []).compactMap { ins in
            guard let form = ins.if_ else { return nil }
            return MWInflection(label: ins.il, form: form)
        }

        var senses: [MWSense] = []
        for defBlock in (def ?? []) {
            for sseq in defBlock.sseq {
                for element in sseq {
                    guard let raw = element.sense else { continue }
                    let sn = raw.sn
                    var defText = ""
                    var examples: [String] = []
                    for dtEl in (raw.dt ?? []) {
                        if dtEl.tag == "text", let t = dtEl.text {
                            defText = cleanMWMarkup(t)
                        } else if dtEl.tag == "vis" {
                            let exs = (dtEl.vis ?? []).compactMap { v -> String? in
                                guard let t = v.t else { return nil }
                                return cleanMWMarkup(t)
                            }
                            examples.append(contentsOf: exs)
                        }
                    }
                    if !defText.isEmpty {
                        senses.append(MWSense(senseNumber: sn, definition: defText, examples: examples))
                    }
                }
            }
        }

        return MWEntry(
            id: meta.id,
            headword: headword,
            pronunciation: pronunciation,
            functionalLabel: fl,
            inflections: inflections,
            senses: senses,
            shortDefs: shortdef ?? []
        )
    }

    private func cleanMWMarkup(_ text: String) -> String {
        var result = text
        // 移除 {bc} (bold colon → ": ")
        result = result.replacingOccurrences(of: "{bc}", with: ": ")
        // 移除 {it}...{/it} 斜体标记
        result = result.replacingOccurrences(of: "{it}", with: "").replacingOccurrences(of: "{/it}", with: "")
        // 移除 {b}...{/b} 粗体标记
        result = result.replacingOccurrences(of: "{b}", with: "").replacingOccurrences(of: "{/b}", with: "")
        // 移除 {ldquo}{rdquo}
        result = result.replacingOccurrences(of: "{ldquo}", with: "\u{201C}").replacingOccurrences(of: "{rdquo}", with: "\u{201D}")
        // 移除其他花括号标记
        let pattern = "\\{[^}]+\\}"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}

/// 用于解码混合数组（字典词条 或 字符串建议）
enum MWResponseItem: Decodable {
    case entry(MWRawResponse)
    case suggestion(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .suggestion(s)
        } else {
            let entry = try container.decode(MWRawResponse.self)
            self = .entry(entry)
        }
    }
}
