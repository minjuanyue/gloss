import SwiftUI

// MARK: - 查词结果视图

struct LookupView: View {
    let word: String
    let onDismiss: () -> Void

    /// 是否为单个单词（决定是否调用 MW 词典）
    private var isSingleWord: Bool {
        word.split(separator: " ").count == 1
    }

    @State private var state: ViewState = .loading

    enum ViewState {
        case loading
        case loaded(LookupResult)
        case error(String)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 卡片背景
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 4)

            VStack(spacing: 0) {
                switch state {
                case .loading:
                    loadingContent
                case .loaded(let result):
                    ScrollView(.vertical, showsIndicators: true) {
                        resultContent(result)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                case .error(let msg):
                    errorContent(msg)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .frame(width: 360, height: 480)
        .task {
            await loadData()
        }
    }

    // MARK: - Sub Views

    private var loadingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在查询 \(word)…")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorContent(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(msg)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func resultContent(_ result: LookupResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── 标题：单词大字，短语/句子适当缩小并换行 ──
            Text(result.word)
                .font(isSingleWord
                      ? .system(size: 28, weight: .bold, design: .serif)
                      : .system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)

            // 发音（仅单词有）
            if let pron = result.entries.first?.pronunciation {
                Text("/\(pron)/")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }

            Divider().padding(.vertical, 8)

            // ── 中文释义 ──
            if let tr = result.translation {
                chineseSection(tr)
                Divider().padding(.vertical, 8)
            }

            // ── 英文详细释义（按词性分组） ──
            if !result.entries.isEmpty {
                englishSection(result.entries)
            }

            // 错误提示（部分失败）
            if let err = result.error {
                errorBadge(err)
            }
        }
    }

    // MARK: - 中文释义区

    @ViewBuilder
    private func chineseSection(_ tr: YoudaoResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(isSingleWord ? "中文释义" : "翻译", systemImage: "character.bubble")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            // 主翻译：短语/句子字号更大，更突出
            if !tr.mainTranslation.isEmpty {
                Text(tr.mainTranslation)
                    .font(isSingleWord
                          ? .system(size: 15, weight: .medium)
                          : .system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // basic explains（仅单词有，如 "n. 测试", "vt. 测试"）
            if isSingleWord, !tr.basicExplains.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(tr.basicExplains, id: \.self) { exp in
                        Text(exp)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - 英文详细释义区

    @ViewBuilder
    private func englishSection(_ entries: [MWEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("英文详细释义", systemImage: "text.book.closed")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            ForEach(entries) { entry in
                entryView(entry)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: MWEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 词性标签
            Text(entry.functionalLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(posColor(for: entry.functionalLabel))
                .cornerRadius(6)

            // 词形变化
            if !entry.inflections.isEmpty {
                inflectionsView(entry.inflections)
            }

            // 每条释义
            ForEach(Array(entry.senses.enumerated()), id: \.element.id) { idx, sense in
                senseView(sense, index: idx + 1)
            }
        }
    }

    @ViewBuilder
    private func inflectionsView(_ infs: [MWInflection]) -> some View {
        HStack(spacing: 0) {
            ForEach(infs) { inf in
                HStack(spacing: 3) {
                    if let label = inf.label {
                        Text(label + ":")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Text(inf.form)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .padding(.trailing, 4)
            }
        }
    }

    @ViewBuilder
    private func senseView(_ sense: MWSense, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                // 序号
                Text(sense.senseNumber ?? "\(index)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 18, alignment: .leading)

                // 释义文字
                Text(sense.definition)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 例句
            if !sense.examples.isEmpty {
                ForEach(sense.examples, id: \.self) { ex in
                    HStack(alignment: .top, spacing: 6) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: 2)
                        Text(ex)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 24)
                }
            }
        }
    }

    private func errorBadge(_ err: LookupError) -> some View {
        Text(errorBadgeMessage(err))
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.top, 8)
    }

    private func errorBadgeMessage(_ err: LookupError) -> String {
        switch err {
        case .wordNotFound(let suggestions):
            return suggestions.isEmpty ? "未找到该词" : "未找到该词，您是否要查：\(suggestions.prefix(3).joined(separator: "、"))"
        case .apiKeyMissing(let s): return s
        case .networkError(let s):  return "网络错误：\(s)"
        case .decodingError(let s): return "解析错误：\(s)"
        }
    }

    // MARK: - Async Load

    private func loadData() async {
        let hasMW     = !KeychainManager.shared.load(key: .merriamWebster).isEmpty
        let hasYoudao = !KeychainManager.shared.load(key: .youdaoAppKey).isEmpty
                     && !KeychainManager.shared.load(key: .youdaoSecret).isEmpty

        // 没有任何 key 时直接报错
        guard hasMW || hasYoudao else {
            await MainActor.run {
                state = .error("请先在设置中填入 API Key（Merriam-Webster 或有道翻译，至少填一个）")
            }
            return
        }

        var translation: YoudaoResult?
        var entries: [MWEntry] = []
        var mwError: LookupError?

        // MW 词典只支持单词，短语/句子跳过
        let shouldQueryMW = hasMW && isSingleWord

        async let trTask: YoudaoResult? = {
            guard hasYoudao else { return nil }
            do { return try await YoudaoService.shared.translate(word: word) }
            catch { return nil }
        }()

        async let mwTask: [MWEntry] = {
            guard shouldQueryMW else { return [] }
            do { return try await MerriamWebsterService.shared.lookup(word: word) }
            catch let e as LookupError { mwError = e; return [] }
            catch { mwError = .networkError(error.localizedDescription); return [] }
        }()

        translation = await trTask
        entries     = await mwTask

        let result = LookupResult(
            word: word,
            translation: translation,
            entries: entries,
            error: mwError
        )

        await MainActor.run {
            // 有内容就展示，哪怕只有一个来源
            if !entries.isEmpty || translation != nil {
                state = .loaded(result)
            } else {
                // 都失败了才整体报错
                let msg = mwError.map { errorMessage($0) } ?? "查询失败，请检查网络连接"
                state = .error(msg)
            }
        }
    }

    private func errorMessage(_ e: LookupError) -> String {
        switch e {
        case .wordNotFound(let s): return s.isEmpty ? "未找到该词" : "未找到该词，候选：\(s.prefix(3).joined(separator: "、"))"
        case .apiKeyMissing(let s): return s
        case .networkError(let s): return s
        case .decodingError(let s): return s
        }
    }

    // MARK: - 词性颜色

    private func posColor(for pos: String) -> Color {
        switch pos.lowercased() {
        case let s where s.hasPrefix("noun"):        return .blue
        case let s where s.hasPrefix("verb"):        return .green
        case let s where s.hasPrefix("adjective"):   return .orange
        case let s where s.hasPrefix("adverb"):      return .purple
        case let s where s.hasPrefix("preposition"): return .pink
        case let s where s.hasPrefix("conjunction"): return .teal
        case let s where s.hasPrefix("interjection"): return .red
        default:                                      return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    LookupView(word: "test") {}
        .frame(width: 360, height: 480)
}
