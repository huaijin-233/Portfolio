import Foundation
import OSLog
import Translation

actor WordTranslationService {
    private var cache: [String: String] = [:]
    private let logger = Logger(subsystem: "com.zhuhuaijin.danci", category: "translation")
    private let batchTimeoutNanoseconds: UInt64 = 16_000_000_000
    private let singleWordTimeoutNanoseconds: UInt64 = 6_000_000_000
    private let batchSize = 8

    func cachedTranslations(for words: [String]) -> [String: String] {
        let uniqueWords = uniquePreservingOrder(words)
        guard !uniqueWords.isEmpty else { return [:] }

        var results: [String: String] = [:]

        for word in uniqueWords {
            let cacheKey = normalizedKey(for: word)
            if let cached = cache[cacheKey] {
                results[cacheKey] = cached
            }
        }

        return results
    }

    func cachedDetailedTranslations(for words: [String]) -> [String: String] {
        [:]
    }

    func translate(words: [String], using session: TranslationSession) async -> [String: String] {
        let uniqueWords = uniquePreservingOrder(words)
        guard !uniqueWords.isEmpty else { return [:] }

        var results = cachedTranslations(for: uniqueWords)
        var pendingWords: [String] = []

        for word in uniqueWords {
            let cacheKey = normalizedKey(for: word)

            if results[cacheKey] == nil {
                pendingWords.append(cacheKey)
            }
        }

        guard !pendingWords.isEmpty else {
            return results
        }

        for batch in pendingWords.chunked(into: batchSize) {
            do {
                var batchResults = try await translateBatch(batch, session: session)

                let unresolvedWords = batch.filter { batchResults[$0] == nil }
                if !unresolvedWords.isEmpty {
                    logger.error("Batch translation returned partial results for \(unresolvedWords.count) words, retrying individually.")
                    let retriedResults = await translateIndividually(unresolvedWords, session: session)

                    for (key, translatedNote) in retriedResults {
                        batchResults[key] = translatedNote
                    }
                }

                for (key, translatedNote) in batchResults {
                    results[key] = translatedNote
                    cache[key] = translatedNote
                }
            } catch {
                logger.error("Translation failed: \(String(describing: error), privacy: .public)")
            }
        }

        return results
    }

    func translateDetailed(words: [String], using session: TranslationSession) async -> [String: String] {
        let uniqueWords = uniquePreservingOrder(words)
        guard !uniqueWords.isEmpty else { return [:] }

        var results: [String: String] = [:]
        var pendingWords: [String] = []

        for word in uniqueWords {
            let cacheKey = normalizedKey(for: word)
            pendingWords.append(cacheKey)
        }

        guard !pendingWords.isEmpty else {
            return results
        }

        for batch in pendingWords.chunked(into: batchSize) {
            do {
                var batchResults = try await translateDetailedBatch(batch, session: session)

                let unresolvedWords = batch.filter { batchResults[$0] == nil }
                if !unresolvedWords.isEmpty {
                    logger.error("Detailed translation returned partial results for \(unresolvedWords.count) words, retrying individually.")
                    let retriedResults = await translateDetailedIndividually(unresolvedWords, session: session)

                    for (key, translatedNote) in retriedResults {
                        batchResults[key] = translatedNote
                    }
                }

                for (key, translatedNote) in batchResults {
                    results[key] = translatedNote
                }
            } catch {
                logger.error("Detailed translation failed: \(String(describing: error), privacy: .public)")

                for word in batch where results[word] == nil {
                    if let fallbackTranslation = CommonDetailedMeaningDictionary.translation(for: word) {
                        results[word] = fallbackTranslation
                    }
                }
            }
        }

        return results
    }

    private func uniquePreservingOrder(_ words: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for word in words where !seen.contains(word) {
            seen.insert(word)
            result.append(word)
        }

        return result
    }

    private func translateBatch(
        _ words: [String],
        session: TranslationSession
    ) async throws -> [String: String] {
        do {
            return try await withTimeout(batchTimeoutNanoseconds) { [self] in
                try await self.requestBatchTranslations(words, session: session)
            }
        } catch {
            logger.error("Batch translation failed, retrying per word: \(String(describing: error), privacy: .public)")

            var results: [String: String] = [:]

            for word in words {
                do {
                    if let translation = try await withTimeout(singleWordTimeoutNanoseconds, operation: { [self] in
                        try await self.translateSingleWord(word, session: session)
                    }) {
                        results[word] = translation
                    }
                } catch {
                    logger.error("Single-word translation failed for \(word, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }

            if results.isEmpty {
                throw error
            }

            return results
        }
    }

    private func translateIndividually(
        _ words: [String],
        session: TranslationSession
    ) async -> [String: String] {
        var results: [String: String] = [:]

        for word in words {
            do {
                if let translation = try await withTimeout(singleWordTimeoutNanoseconds, operation: { [self] in
                    try await self.translateSingleWord(word, session: session)
                }) {
                    results[word] = translation
                }
            } catch {
                logger.error("Retry translation failed for \(word, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        return results
    }

    private func translateDetailedBatch(
        _ words: [String],
        session: TranslationSession
    ) async throws -> [String: String] {
        do {
            return try await withTimeout(batchTimeoutNanoseconds) { [self] in
                try await self.requestDetailedTranslations(words, session: session)
            }
        } catch {
            logger.error("Detailed batch translation failed, retrying per word: \(String(describing: error), privacy: .public)")

            var results: [String: String] = [:]

            for word in words {
                do {
                    if let translation = try await withTimeout(singleWordTimeoutNanoseconds, operation: { [self] in
                        try await self.translateDetailedSingleWord(word, session: session)
                    }) {
                        results[word] = translation
                    }
                } catch {
                    logger.error("Detailed single-word translation failed for \(word, privacy: .public): \(String(describing: error), privacy: .public)")
                }
            }

            if results.isEmpty {
                throw error
            }

            return results
        }
    }

    private func translateDetailedIndividually(
        _ words: [String],
        session: TranslationSession
    ) async -> [String: String] {
        var results: [String: String] = [:]

        for word in words {
            do {
                if let translation = try await withTimeout(singleWordTimeoutNanoseconds, operation: { [self] in
                    try await self.translateDetailedSingleWord(word, session: session)
                }) {
                    results[word] = translation
                }
            } catch {
                logger.error("Detailed retry translation failed for \(word, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        return results
    }

    private func requestBatchTranslations(
        _ words: [String],
        session: TranslationSession
    ) async throws -> [String: String] {
        let requests = words.map {
            TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
        }
        let responses = try await session.translations(from: requests)
        return mappedTranslations(from: responses)
    }

    private func requestDetailedTranslations(
        _ words: [String],
        session: TranslationSession
    ) async throws -> [String: String] {
        let requests = words.map {
            TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
        }
        let responses = try await session.translations(from: requests)
        return mappedDetailedTranslations(from: responses)
    }

    private func translateSingleWord(
        _ word: String,
        session: TranslationSession
    ) async throws -> String? {
        let response = try await session.translate(word)
        let translatedNote = condensedTranslation(response.targetText)
        return translatedNote.isEmpty ? nil : translatedNote
    }

    private func translateDetailedSingleWord(
        _ word: String,
        session: TranslationSession
    ) async throws -> String? {
        let response = try await session.translate(word)
        let translatedNote = detailedTranslation(for: word, translatedText: response.targetText)
        return translatedNote.isEmpty ? nil : translatedNote
    }

    private func mappedTranslations(
        from responses: [TranslationSession.Response]
    ) -> [String: String] {
        var mapped: [String: String] = [:]

        for response in responses {
            let key = normalizedKey(for: response.clientIdentifier ?? response.sourceText)
            let translatedNote = condensedTranslation(response.targetText)

            guard !translatedNote.isEmpty else { continue }
            mapped[key] = translatedNote
        }

        return mapped
    }

    private func mappedDetailedTranslations(
        from responses: [TranslationSession.Response]
    ) -> [String: String] {
        var mapped: [String: String] = [:]

        for response in responses {
            let key = normalizedKey(for: response.clientIdentifier ?? response.sourceText)
            let translatedNote = detailedTranslation(for: key, translatedText: response.targetText)

            guard !translatedNote.isEmpty else { continue }
            mapped[key] = translatedNote
        }

        return mapped
    }

    private func normalizedKey(for word: String) -> String {
        EnglishWordSanitizer.normalize(word, minimumLength: 2)
            ?? word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func condensedTranslation(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return "" }

        let separators = CharacterSet(charactersIn: "\n；;/，,")
        let parts = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        return parts.first ?? normalized
    }

    private func detailedTranslation(for word: String, translatedText: String) -> String {
        let key = normalizedKey(for: word)
        let primaryMeanings = detailedMeanings(translatedText)
        let dictionaryMeanings = CommonDetailedMeaningDictionary.meanings(for: key)

        var seen: Set<String> = []
        var meanings: [String] = []

        for meaning in primaryMeanings + dictionaryMeanings {
            let cleaned = cleanedDetailedMeaning(meaning)
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            meanings.append(cleaned)

            if meanings.count >= 5 {
                break
            }
        }

        if !meanings.isEmpty {
            return meanings.joined(separator: "，")
        }

        return detailedTranslation(translatedText)
    }

    private func detailedTranslation(_ text: String) -> String {
        let meanings = detailedMeanings(text)
        guard !meanings.isEmpty else {
            return condensedTranslation(text)
        }

        return meanings.joined(separator: "，")
    }

    private func detailedMeanings(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        let separators = CharacterSet(charactersIn: "\n；;/，,、")
        let parts = normalized
            .components(separatedBy: separators)
            .map { cleanedDetailedMeaning($0) }
            .filter { !$0.isEmpty }

        var seen: Set<String> = []
        var meanings: [String] = []

        for part in parts {
            guard !seen.contains(part) else { continue }
            seen.insert(part)
            meanings.append(part)

            if meanings.count >= 5 {
                break
            }
        }

        return meanings
    }

    private func cleanedDetailedMeaning(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}

private enum CommonDetailedMeaningDictionary {
    nonisolated private static let safeEntries: [String: [String]] = [
        "again": ["再一次", "又", "重新"],
        "apple": ["苹果", "苹果公司"],
        "ask": ["问", "请求", "要求"],
        "back": ["后面", "返回", "背部"],
        "book": ["书", "预订", "登记"],
        "break": ["打破", "休息", "中断"],
        "business": ["商业", "生意", "业务"],
        "call": ["打电话", "称呼", "呼叫"],
        "change": ["改变", "变化", "更换"],
        "check": ["检查", "核对"],
        "close": ["关闭", "接近", "亲密的"],
        "come": ["来", "到达", "发生"],
        "company": ["公司", "陪伴"],
        "control": ["控制", "管理", "支配"],
        "course": ["课程", "过程", "路线"],
        "cut": ["切", "削减", "剪辑"],
        "develop": ["发展", "开发", "形成"],
        "draw": ["画", "吸引", "抽签"],
        "drive": ["驾驶", "推动", "驱动"],
        "end": ["结束", "末端", "目标"],
        "experience": ["经验", "经历", "体验"],
        "fall": ["落下", "秋天", "下降"],
        "feel": ["感觉", "觉得", "触摸"],
        "field": ["领域", "田野", "场地"],
        "find": ["找到", "发现", "认为"],
        "follow": ["跟随", "遵循", "理解"],
        "form": ["形式", "表格", "形成"],
        "free": ["免费的", "自由的", "释放"],
        "get": ["得到", "变得", "到达"],
        "give": ["给", "提供", "让步"],
        "go": ["去", "进行", "变成"],
        "good": ["好的", "优秀的", "有益的"],
        "great": ["伟大的", "很棒的", "大量的"],
        "group": ["组", "团体", "分组"],
        "grow": ["成长", "增长", "种植"],
        "happy": ["快乐的", "高兴的", "幸福的"],
        "hard": ["困难的", "坚硬的", "努力地"],
        "have": ["有", "拥有", "经历"],
        "help": ["帮助", "帮忙", "有用"],
        "hold": ["握住", "举行", "保持"],
        "interest": ["兴趣", "利益", "利息"],
        "keep": ["保持", "保留", "继续"],
        "know": ["知道", "认识", "了解"],
        "last": ["最后的", "持续", "上一个"],
        "leave": ["离开", "留下", "休假"],
        "like": ["喜欢", "像", "例如"],
        "line": ["线", "排", "路线"],
        "live": ["居住", "生活", "现场直播"],
        "look": ["看", "寻找", "样子"],
        "love": ["爱", "爱情", "喜欢"],
        "make": ["制作", "使得", "赚得"],
        "market": ["市场", "销售", "行情"],
        "mean": ["意思是", "意味着", "打算"],
        "mind": ["头脑", "介意", "注意"],
        "move": ["移动", "搬家", "行动"],
        "need": ["需要", "必要", "需求"],
        "open": ["打开", "开放的", "公开的"],
        "order": ["顺序", "命令", "订单"],
        "pass": ["通过", "传递", "通行证"],
        "place": ["地方", "放置", "位置"],
        "plan": ["计划", "方案", "打算"],
        "play": ["玩", "播放", "比赛"],
        "point": ["点", "观点", "指出"],
        "present": ["现在的", "礼物", "提出"],
        "put": ["放", "表达", "使处于"],
        "question": ["问题", "询问", "质疑"],
        "read": ["阅读", "读懂"],
        "right": ["正确的", "右边", "权利"],
        "run": ["跑", "运行", "经营"],
        "say": ["说", "表示"],
        "see": ["看见", "理解", "会见"],
        "set": ["设置", "集合", "一套"],
        "show": ["显示", "展示", "表演"],
        "side": ["一边", "方面", "支持"],
        "sound": ["声音", "听起来", "可靠的"],
        "stand": ["站立", "忍受", "立场"],
        "start": ["开始", "启动", "起点"],
        "state": ["状态", "国家", "陈述"],
        "study": ["学习", "研究", "书房"],
        "take": ["拿", "带走", "花费"],
        "talk": ["谈话", "讲话", "讨论"],
        "tell": ["告诉", "辨别", "讲述"],
        "test": ["测试", "考试", "检验"],
        "think": ["认为", "思考", "想"],
        "time": ["时间", "次数", "时期"],
        "try": ["尝试", "努力", "试用"],
        "turn": ["转动", "轮到", "变成"],
        "use": ["使用", "用途", "利用"],
        "want": ["想要", "需要", "希望"],
        "way": ["方法", "道路", "方面"],
        "well": ["好地", "健康的"],
        "will": ["将要", "意志"],
        "word": ["单词", "话语", "消息"],
        "work": ["工作", "作品", "运转"],
        "write": ["写", "写作", "写信"]
    ]

    nonisolated private static let entries: [String: [String]] = [
        "about": ["关于", "大约", "到处", "在附近"],
        "above": ["在上方", "超过", "高于"],
        "accept": ["接受", "同意", "承认"],
        "account": ["账户", "叙述", "解释", "认为"],
        "act": ["行动", "表现", "法案", "行为"],
        "address": ["地址", "演讲", "处理", "称呼"],
        "after": ["在之后", "后来", "追赶"],
        "again": ["再一次", "又", "重新"],
        "against": ["反对", "靠着", "违背"],
        "age": ["年龄", "时代", "变老"],
        "all": ["全部", "所有的", "完全"],
        "allow": ["允许", "准许", "承认"],
        "also": ["也", "而且", "同样"],
        "always": ["总是", "一直", "永远"],
        "and": ["和", "并且", "然后"],
        "answer": ["答案", "回答", "回应"],
        "appear": ["出现", "显得", "似乎"],
        "apple": ["苹果", "苹果公司"],
        "area": ["区域", "面积", "领域"],
        "around": ["周围", "大约", "到处"],
        "ask": ["问", "请求", "要求"],
        "back": ["后面", "背部", "返回", "支持"],
        "bad": ["坏的", "严重的", "不好的"],
        "base": ["基础", "基地", "以为基础"],
        "be": ["是", "存在", "成为"],
        "bear": ["熊", "忍受", "承担", "生育"],
        "beat": ["打败", "敲打", "节拍"],
        "beautiful": ["美丽的", "漂亮的", "美好的"],
        "because": ["因为", "由于"],
        "become": ["变成", "成为", "适合"],
        "before": ["在之前", "以前", "先于"],
        "begin": ["开始", "着手", "启动"],
        "best": ["最好的", "最好地", "最佳事物"],
        "better": ["更好的", "更好地", "改善"],
        "big": ["大的", "重要的", "重大的"],
        "board": ["木板", "委员会", "登上"],
        "body": ["身体", "主体", "尸体", "机构"],
        "book": ["书", "预订", "登记"],
        "break": ["打破", "休息", "中断", "突破"],
        "bring": ["带来", "引起", "促使"],
        "business": ["商业", "事务", "公司"],
        "but": ["但是", "除了", "只是"],
        "buy": ["购买", "相信", "买到"],
        "call": ["打电话", "称呼", "呼叫", "拜访"],
        "can": ["能够", "可以", "罐头"],
        "card": ["卡片", "纸牌", "银行卡"],
        "care": ["关心", "照顾", "小心"],
        "case": ["情况", "案例", "箱子", "病例"],
        "change": ["改变", "变化", "零钱", "更换"],
        "check": ["检查", "核对", "支票", "阻止"],
        "child": ["孩子", "儿童", "子女"],
        "city": ["城市", "都市"],
        "clear": ["清楚的", "清除", "晴朗的", "明确"],
        "close": ["关闭", "接近", "亲密的"],
        "come": ["来", "到达", "发生"],
        "company": ["公司", "陪伴", "同伴"],
        "complete": ["完成", "完整的", "彻底的"],
        "consider": ["考虑", "认为", "体谅"],
        "control": ["控制", "管理", "支配"],
        "cost": ["花费", "成本", "代价"],
        "course": ["课程", "过程", "路线", "一道菜"],
        "cut": ["切", "削减", "伤口", "剪辑"],
        "date": ["日期", "约会", "枣"],
        "day": ["一天", "白天", "时期"],
        "deal": ["交易", "处理", "大量"],
        "develop": ["发展", "开发", "形成"],
        "do": ["做", "进行", "适合"],
        "down": ["向下", "沮丧的", "下降"],
        "draw": ["画", "吸引", "抽签", "平局"],
        "drive": ["驾驶", "推动", "驱动器"],
        "early": ["早的", "早期的", "提前"],
        "end": ["结束", "末端", "目标"],
        "enough": ["足够的", "足够地", "充分"],
        "even": ["甚至", "平坦的", "偶数的"],
        "example": ["例子", "榜样", "示例"],
        "experience": ["经验", "经历", "体验"],
        "face": ["脸", "面对", "表面"],
        "fact": ["事实", "实际情况"],
        "fall": ["落下", "秋天", "下降", "跌倒"],
        "family": ["家庭", "家人", "家族"],
        "feel": ["感觉", "觉得", "触摸"],
        "few": ["少数", "几个", "不多"],
        "field": ["田野", "领域", "场地"],
        "figure": ["数字", "人物", "身材", "认为"],
        "file": ["文件", "归档", "提出"],
        "find": ["找到", "发现", "认为"],
        "fine": ["好的", "精细的", "罚款"],
        "first": ["第一", "首先", "最初"],
        "follow": ["跟随", "遵循", "理解"],
        "for": ["为了", "对于", "因为", "持续"],
        "form": ["形式", "表格", "形成"],
        "free": ["免费的", "自由的", "释放"],
        "from": ["从", "来自", "由于"],
        "game": ["游戏", "比赛", "猎物"],
        "get": ["得到", "变得", "到达", "理解"],
        "give": ["给", "提供", "让步"],
        "go": ["去", "进行", "变成"],
        "good": ["好的", "优秀的", "有益的"],
        "great": ["伟大的", "很棒的", "大量的"],
        "group": ["组", "团体", "分组"],
        "grow": ["成长", "增长", "种植"],
        "hand": ["手", "递给", "帮助"],
        "happy": ["快乐的", "高兴的", "幸福的"],
        "hard": ["困难的", "坚硬的", "努力地"],
        "have": ["有", "拥有", "经历"],
        "head": ["头", "负责人", "前往"],
        "help": ["帮助", "帮忙", "有用"],
        "here": ["这里", "在这里", "这时"],
        "high": ["高的", "高级的", "高处"],
        "hold": ["握住", "举行", "保持", "容纳"],
        "home": ["家", "家庭", "主页"],
        "house": ["房子", "住宅", "容纳"],
        "idea": ["想法", "主意", "理念"],
        "important": ["重要的", "有影响的", "重大的"],
        "interest": ["兴趣", "利益", "利息"],
        "keep": ["保持", "保留", "继续"],
        "kind": ["种类", "友好的", "亲切的"],
        "know": ["知道", "认识", "了解"],
        "large": ["大的", "大量的", "广泛的"],
        "last": ["最后的", "持续", "上一个"],
        "late": ["迟的", "晚的", "已故的"],
        "leave": ["离开", "留下", "休假"],
        "left": ["左边", "剩下的", "离开了"],
        "let": ["让", "允许", "出租"],
        "life": ["生命", "生活", "人生"],
        "like": ["喜欢", "像", "例如"],
        "line": ["线", "排", "台词", "路线"],
        "little": ["小的", "少量", "一点"],
        "live": ["居住", "生活", "现场直播"],
        "long": ["长的", "长期的", "渴望"],
        "look": ["看", "寻找", "样子"],
        "love": ["情感", "爱情", "爱", "喜欢"],
        "make": ["制作", "使得", "赚得"],
        "man": ["男人", "人类", "操纵"],
        "market": ["市场", "销售", "行情"],
        "mean": ["意思是", "意味着", "刻薄的", "平均的"],
        "mind": ["头脑", "介意", "注意"],
        "money": ["钱", "资金", "财富"],
        "move": ["移动", "搬家", "行动"],
        "name": ["名字", "命名", "名声"],
        "need": ["需要", "必要", "需求"],
        "new": ["新的", "新近的", "陌生的"],
        "next": ["下一个", "接下来", "旁边"],
        "no": ["不", "没有", "否定"],
        "not": ["不", "没有"],
        "number": ["数字", "号码", "数量"],
        "off": ["离开", "关闭", "折扣"],
        "old": ["老的", "旧的", "以前的"],
        "one": ["一", "一个", "某个"],
        "only": ["仅仅", "唯一的", "只是"],
        "open": ["打开", "开放的", "公开的"],
        "order": ["顺序", "命令", "订单"],
        "other": ["其他的", "另一个", "另外"],
        "over": ["在上方", "超过", "结束"],
        "own": ["自己的", "拥有", "承认"],
        "page": ["页面", "页", "传呼"],
        "part": ["部分", "角色", "分开"],
        "pass": ["通过", "传递", "通行证"],
        "people": ["人们", "民族", "人民"],
        "place": ["地方", "放置", "位置"],
        "plan": ["计划", "方案", "打算"],
        "play": ["玩", "播放", "戏剧", "比赛"],
        "point": ["点", "观点", "指出"],
        "power": ["力量", "权力", "电力"],
        "present": ["现在的", "礼物", "提出", "出席"],
        "problem": ["问题", "难题", "麻烦"],
        "program": ["程序", "节目", "计划"],
        "put": ["放", "表达", "使处于"],
        "question": ["问题", "询问", "质疑"],
        "read": ["阅读", "读懂", "显示"],
        "real": ["真实的", "真正的", "实际的"],
        "right": ["右边", "正确的", "权利"],
        "room": ["房间", "空间", "余地"],
        "run": ["跑", "运行", "经营", "流动"],
        "same": ["相同的", "同样的", "一样"],
        "say": ["说", "表示", "比方说"],
        "school": ["学校", "学派", "训练"],
        "see": ["看见", "理解", "会见"],
        "seem": ["似乎", "好像"],
        "service": ["服务", "维修", "服役"],
        "set": ["设置", "集合", "一套", "固定的"],
        "show": ["显示", "展示", "表演"],
        "side": ["一边", "方面", "支持"],
        "small": ["小的", "少的", "小规模的"],
        "sound": ["声音", "听起来", "可靠的"],
        "stand": ["站立", "忍受", "立场"],
        "start": ["开始", "启动", "起点"],
        "state": ["状态", "国家", "陈述"],
        "still": ["仍然", "静止的", "平静的"],
        "study": ["学习", "研究", "书房"],
        "take": ["拿", "带走", "花费", "采取"],
        "talk": ["谈话", "讲话", "讨论"],
        "tell": ["告诉", "辨别", "讲述"],
        "test": ["测试", "考试", "检验"],
        "thing": ["事情", "东西", "事物"],
        "think": ["认为", "思考", "想"],
        "time": ["时间", "次数", "时期"],
        "to": ["到", "向", "对于"],
        "too": ["也", "太", "过于"],
        "try": ["尝试", "努力", "试用"],
        "turn": ["转动", "轮到", "变成"],
        "under": ["在下面", "低于", "受控制"],
        "up": ["向上", "增加", "起来"],
        "use": ["使用", "用途", "利用"],
        "very": ["非常", "很", "真正地"],
        "want": ["想要", "需要", "缺乏"],
        "water": ["水", "浇水", "水域"],
        "way": ["方法", "道路", "方面"],
        "well": ["好地", "健康的", "井"],
        "will": ["将要", "意志", "遗嘱"],
        "word": ["单词", "话语", "消息"],
        "work": ["工作", "作品", "运转"],
        "world": ["世界", "领域", "世人"],
        "write": ["写", "写作", "写信"],
        "year": ["年", "年度", "岁数"],
        "yes": ["是", "好的", "同意"],
        "young": ["年轻的", "幼小的", "年轻人"]
    ]

    nonisolated private static let chineseEntries: [String: [String]] = [
        "爱": ["情感", "爱情", "爱", "喜欢"],
        "喜欢": ["喜欢", "喜爱", "愿意", "像"],
        "苹果": ["苹果", "苹果公司"],
        "去": ["去", "前往", "进行", "变成"],
        "来": ["来", "到来", "出现", "发生"],
        "做": ["做", "制作", "进行", "完成"],
        "使": ["使得", "让", "造成", "制作"],
        "有": ["有", "拥有", "经历", "包含"],
        "得到": ["得到", "获得", "变得", "到达"],
        "看": ["看", "观看", "寻找", "看起来"],
        "说": ["说", "表示", "说明", "比方说"],
        "告诉": ["告诉", "讲述", "辨别", "命令"],
        "认为": ["认为", "思考", "想", "考虑"],
        "知道": ["知道", "认识", "了解", "懂得"],
        "发现": ["发现", "找到", "发觉", "认为"],
        "给": ["给", "提供", "交给", "让步"],
        "使用": ["使用", "用途", "利用", "消耗"],
        "工作": ["工作", "作品", "运转", "奏效"],
        "学习": ["学习", "研究", "书房"],
        "帮助": ["帮助", "帮忙", "有用", "救助"],
        "需要": ["需要", "必要", "需求", "缺乏"],
        "想要": ["想要", "需要", "希望", "缺乏"],
        "尝试": ["尝试", "努力", "试用", "审理"],
        "开始": ["开始", "启动", "起点", "着手"],
        "结束": ["结束", "末端", "目标", "终止"],
        "打开": ["打开", "开放的", "公开的", "开阔的"],
        "关闭": ["关闭", "接近", "亲密的", "结束"],
        "改变": ["改变", "变化", "零钱", "更换"],
        "移动": ["移动", "搬家", "行动", "感动"],
        "运行": ["运行", "跑", "经营", "流动"],
        "播放": ["播放", "玩", "戏剧", "比赛"],
        "设置": ["设置", "集合", "一套", "固定的"],
        "检查": ["检查", "核对", "支票", "阻止"],
        "控制": ["控制", "管理", "支配", "调节"],
        "发展": ["发展", "开发", "形成", "成长"],
        "增长": ["增长", "成长", "种植", "扩大"],
        "显示": ["显示", "展示", "表演", "说明"],
        "关注": ["关注", "关心", "注意", "照顾"],
        "关心": ["关心", "照顾", "在意", "小心"],
        "感觉": ["感觉", "觉得", "触摸", "感受"],
        "保持": ["保持", "保留", "继续", "维持"],
        "离开": ["离开", "留下", "休假", "出发"],
        "留下": ["留下", "离开", "保持", "遗留"],
        "带来": ["带来", "引起", "促使", "拿来"],
        "拿": ["拿", "带走", "花费", "采取"],
        "放": ["放", "表达", "安置", "使处于"],
        "画": ["画", "吸引", "抽签", "平局"],
        "打破": ["打破", "休息", "中断", "突破"],
        "通过": ["通过", "传递", "经过", "通行证"],
        "接受": ["接受", "同意", "承认", "接纳"],
        "允许": ["允许", "准许", "承认", "让"],
        "考虑": ["考虑", "认为", "体谅", "顾及"],
        "出现": ["出现", "显得", "似乎", "露面"],
        "似乎": ["似乎", "好像", "看来"],
        "成为": ["成为", "变成", "适合"],
        "意思是": ["意思是", "意味着", "打算", "表示"],
        "意味着": ["意味着", "意思是", "表示", "预示"],
        "问": ["问", "请求", "要求", "询问"],
        "回答": ["回答", "答案", "回应", "接听"],
        "问题": ["问题", "难题", "询问", "质疑"],
        "测试": ["测试", "考试", "检验", "试验"],
        "考试": ["考试", "测试", "考验", "测验"],
        "计划": ["计划", "方案", "打算", "规划"],
        "程序": ["程序", "节目", "计划", "项目"],
        "服务": ["服务", "维修", "服役", "招待"],
        "市场": ["市场", "销售", "行情", "集市"],
        "商业": ["商业", "事务", "公司", "生意"],
        "公司": ["公司", "陪伴", "同伴", "连队"],
        "学校": ["学校", "学派", "训练"],
        "家庭": ["家庭", "家人", "家族"],
        "家": ["家", "家庭", "主页", "归属地"],
        "房子": ["房子", "住宅", "容纳", "议院"],
        "房间": ["房间", "空间", "余地"],
        "城市": ["城市", "都市"],
        "世界": ["世界", "领域", "世人"],
        "区域": ["区域", "面积", "领域", "地区"],
        "领域": ["领域", "田野", "场地", "范围"],
        "地方": ["地方", "放置", "位置", "名次"],
        "位置": ["位置", "地点", "职位", "放置"],
        "方面": ["方面", "一边", "侧面", "支持"],
        "部分": ["部分", "角色", "分开", "零件"],
        "观点": ["观点", "点", "指出", "要点"],
        "情况": ["情况", "案例", "箱子", "病例"],
        "事实": ["事实", "实际情况"],
        "想法": ["想法", "主意", "理念"],
        "名字": ["名字", "命名", "名声"],
        "单词": ["单词", "话语", "消息"],
        "书": ["书", "预订", "登记"],
        "页面": ["页面", "页", "传呼"],
        "表格": ["表格", "形式", "形成", "形态"],
        "文件": ["文件", "归档", "提出"],
        "卡片": ["卡片", "纸牌", "银行卡"],
        "数字": ["数字", "号码", "数量"],
        "时间": ["时间", "次数", "时期"],
        "日期": ["日期", "约会", "枣"],
        "年": ["年", "年度", "岁数"],
        "一天": ["一天", "白天", "时期"],
        "生活": ["生活", "生命", "人生"],
        "身体": ["身体", "主体", "尸体", "机构"],
        "头": ["头", "负责人", "前往"],
        "手": ["手", "递给", "帮助"],
        "脸": ["脸", "面对", "表面"],
        "声音": ["声音", "听起来", "可靠的"],
        "水": ["水", "浇水", "水域"],
        "钱": ["钱", "资金", "财富"],
        "力量": ["力量", "权力", "电力"],
        "权利": ["权利", "正确的", "右边", "权益"],
        "状态": ["状态", "国家", "陈述"],
        "国家": ["国家", "状态", "陈述", "州"],
        "顺序": ["顺序", "命令", "订单"],
        "命令": ["命令", "顺序", "订单", "订购"],
        "课程": ["课程", "过程", "路线", "一道菜"],
        "经验": ["经验", "经历", "体验"],
        "兴趣": ["兴趣", "利益", "利息"],
        "利益": ["利益", "兴趣", "利息", "好处"],
        "成本": ["成本", "花费", "代价"],
        "变化": ["变化", "改变", "零钱", "更换"],
        "答案": ["答案", "回答", "回应"],
        "例子": ["例子", "榜样", "示例"],
        "游戏": ["游戏", "比赛", "猎物"],
        "比赛": ["比赛", "游戏", "竞赛", "匹配"],
        "线": ["线", "排", "台词", "路线"],
        "基础": ["基础", "基地", "以为基础"],
        "组": ["组", "团体", "分组"],
        "团体": ["团体", "组", "群体", "集团"],
        "人": ["人", "人们", "人民", "民族"],
        "人们": ["人们", "人民", "民族"],
        "孩子": ["孩子", "儿童", "子女"],
        "男人": ["男人", "人类", "操纵"],
        "年轻的": ["年轻的", "幼小的", "年轻人"],
        "旧的": ["旧的", "老的", "以前的"],
        "新的": ["新的", "新近的", "陌生的"],
        "大的": ["大的", "重要的", "重大的"],
        "小的": ["小的", "少的", "小规模的"],
        "长的": ["长的", "长期的", "渴望"],
        "高的": ["高的", "高级的", "高处"],
        "好的": ["好的", "优秀的", "有益的"],
        "坏的": ["坏的", "严重的", "不好的"],
        "最好的": ["最好的", "最好地", "最佳事物"],
        "更好的": ["更好的", "更好地", "改善"],
        "美丽的": ["美丽的", "漂亮的", "美好的"],
        "快乐的": ["快乐的", "高兴的", "幸福的"],
        "困难的": ["困难的", "坚硬的", "努力地"],
        "重要的": ["重要的", "有影响的", "重大的"],
        "真实的": ["真实的", "真正的", "实际的"],
        "清楚的": ["清楚的", "清除", "晴朗的", "明确"],
        "免费的": ["免费的", "自由的", "释放"],
        "正确的": ["正确的", "右边", "权利"],
        "相同的": ["相同的", "同样的", "一样"],
        "只有": ["仅仅", "唯一的", "只是"],
        "也": ["也", "而且", "同样"],
        "非常": ["非常", "很", "真正地"],
        "太": ["也", "太", "过于"],
        "再次": ["再一次", "又", "重新"],
        "大约": ["大约", "关于", "到处", "在附近"],
        "超过": ["超过", "在上方", "结束"],
        "向下": ["向下", "沮丧的", "下降"],
        "向上": ["向上", "增加", "起来"],
        "这里": ["这里", "在这里", "这时"],
        "之前": ["在之前", "以前", "先于"],
        "之后": ["在之后", "后来", "追赶"],
        "为了": ["为了", "对于", "因为", "持续"],
        "从": ["从", "来自", "由于"],
        "和": ["和", "并且", "然后"],
        "但是": ["但是", "除了", "只是"],
        "因为": ["因为", "由于"],
        "如果": ["如果", "是否", "条件"],
        "全部": ["全部", "所有的", "完全"],
        "没有": ["没有", "不", "否定"],
        "是": ["是", "存在", "成为"],
        "将要": ["将要", "意志", "遗嘱"],
        "能够": ["能够", "可以", "罐头"]
    ]

    nonisolated static func translation(for word: String) -> String? {
        joinedMeanings(meanings(for: word))
    }

    nonisolated static func translation(forChineseTranslation translation: String) -> String? {
        joinedMeanings(meanings(forChineseTranslation: translation))
    }

    nonisolated static func meanings(for word: String) -> [String] {
        let key = EnglishWordSanitizer.normalize(word, minimumLength: 2)
            ?? word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let meanings = safeEntries[key] {
            return cleanedMeanings(meanings)
        }

        return []
    }

    nonisolated static func meanings(forChineseTranslation translation: String) -> [String] {
        let key = translation
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: ".", with: "")

        guard let meanings = chineseEntries[key] else { return [] }

        return cleanedMeanings(meanings)
    }

    nonisolated private static func joinedMeanings(_ meanings: [String]) -> String? {
        let cleanedMeanings = cleanedMeanings(meanings)

        guard !cleanedMeanings.isEmpty else { return nil }

        return cleanedMeanings.joined(separator: "，")
    }

    nonisolated private static func cleanedMeanings(_ meanings: [String]) -> [String] {
        Array(meanings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5))
    }

}

private enum TranslationTimeoutError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Translation timed out."
    }
}

private func withTimeout<T>(
    _ nanoseconds: UInt64,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw TranslationTimeoutError.timedOut
        }

        guard let result = try await group.next() else {
            throw TranslationTimeoutError.timedOut
        }

        group.cancelAll()
        return result
    }
}

private extension Array {
    nonisolated func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }

        var index = startIndex
        var result: [[Element]] = []

        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }

        return result
    }
}
