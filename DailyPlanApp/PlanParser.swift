import Foundation

/// 把粘贴进来的计划文字解析成每天的任务。
/// 支持三种写法：
///   1. 按天：`## Day 1 · 11/21（六）— 环境 + 变量 + 内存`，下面跟 `- **学什么**：...` 这样的条目；
///      也支持“导入用 AI 提示词模板”生成的格式：开头 `书名：…`，`Day 1 · 2026-11-21（周六）：…`，下面是不带 `- ` 的 `学什么：…` 等固定标签
///   2. 按日期：`11/21：学什么……`
///   3. 简单的一行一条任务
/// 拿不准的地方不编内容，写进 needsReview 让用户改。
enum PlanParser {

    struct Result {
        var plan: Plan
        var warnings: [String]
        var detectedName: String?     // 文字里 “书名：xxx” 那一行
    }

    static func parse(_ text: String, name: String, startDate: String? = nil) -> Result {
        // AI 常会把全文包在 ``` 代码块里，先去掉
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
        var warnings: [String] = []
        let detectedName = lines.lazy.compactMap { l -> String? in
            guard let m = firstMatch(#"^\s*(?:#+\s*)?\**书名\**\s*[：:]\s*(.+)$"#, in: l) else { return nil }
            return stripMarkdown(m[1].replacingOccurrences(of: "《", with: "").replacingOccurrences(of: "》", with: ""))
        }.first

        // 文本里第一个完整日期 yyyy-MM-dd 当开始日 / 年份参考
        let fullDate = firstMatch(#"(20\d{2})-(\d{1,2})-(\d{1,2})"#, in: text)
        var year = DateUtil.calendar.component(.year, from: Date())
        var textStart: String?
        if let m = fullDate, let y = Int(m[1]), let mo = Int(m[2]), let d = Int(m[3]) {
            year = y
            textStart = String(format: "%04d-%02d-%02d", y, mo, d)
        }

        var days = parseDayHeaders(lines)
        var mode = "day"
        if days.isEmpty { days = parseDateLines(lines); mode = "date" }
        if days.isEmpty { days = parseSimpleLines(lines); mode = "simple" }

        // 力扣表格
        let leet = parseLeetTable(lines)
        for i in days.indices {
            if let l = leet[days[i].day], days[i].leetcode.isEmpty {
                days[i].leetcode = l
            }
        }

        days.sort { $0.day < $1.day }

        // ---- 日期 ----
        // 有月/日的：按年份顺推（月份变小就跨年）
        var prevMonth = 0
        var explicit: [Int: String] = [:]   // index -> yyyy-MM-dd
        for (i, d) in days.enumerated() {
            // 完整日期 2026-11-21
            if let m = firstMatch(#"^(20\d{2})-(\d{1,2})-(\d{1,2})$"#, in: d.date),
               let y = Int(m[1]), let mo = Int(m[2]), let dd = Int(m[3]) {
                year = y
                prevMonth = mo
                explicit[i] = String(format: "%04d-%02d-%02d", y, mo, dd)
                continue
            }
            let parts = d.date.split(separator: "/").compactMap { Int($0) }
            guard parts.count == 2 else { continue }
            if prevMonth != 0 && parts[0] < prevMonth { year += 1 }
            prevMonth = parts[0]
            explicit[i] = String(format: "%04d-%02d-%02d", year, parts[0], parts[1])
        }

        let start: String = startDate ?? textStart ?? explicit[0] ?? DateUtil.today()
        let base = days.first?.day ?? 1
        for i in days.indices {
            let computed = DateUtil.adding(days: days[i].day - base, to: start)
            if startDate != nil {               // 用户手动指定了开始日，就按它顺推
                days[i].date = computed
            } else if let e = explicit[i] {
                days[i].date = e
                if e != computed {
                    days[i].needsReview.append("日期 \(DateUtil.short(e)) 和按开始日顺推的 \(DateUtil.short(computed)) 不一致")
                }
            } else {
                days[i].date = computed
                if mode != "simple" { days[i].needsReview.append("原文没写日期，按开始日顺推") }
            }
        }

        // ---- 检查 ----
        for i in days.indices {
            if days[i].learnTopic.isEmpty {
                days[i].learnTopic = "待确认"
                days[i].needsReview.append("没解析出“学什么”")
            }
            // AI 拿不准时会写“待确认”，标出来让用户改
            let n = days[i].notes
            let fields: [(String, String)] = [("学什么", days[i].learnTopic + n.learnDetail),
                                              ("直接搜什么", n.searchPython.joined()), ("计算机逻辑搜什么", n.searchLogic.joined()),
                                              ("动手做什么", n.whatToDo), ("过关标准", n.passCriteria), ("力扣", days[i].leetcode.title)]
            for (k, v) in fields where v.contains("待确认") { days[i].needsReview.append("“\(k)”写的是待确认") }
            if mode == "day" {
                if days[i].notes.whatToDo.isEmpty { days[i].needsReview.append("没找到“动手做什么”") }
                if days[i].notes.passCriteria.isEmpty { days[i].needsReview.append("没找到“过关标准”") }
            }
        }
        if mode == "day", let first = days.first?.day, let last = days.last?.day,
           last - first + 1 != days.count {
            warnings.append("Day 编号不连续（共 \(days.count) 天，编号 \(first)-\(last)）")
        }
        let review = days.filter { !$0.needsReview.isEmpty }.count
        if review > 0 { warnings.append("\(review) 天有待确认的地方，已标黄") }
        if days.isEmpty { warnings.append("没解析出任何一天") }

        let plan = Plan(name: name, startDate: days.first?.date ?? start, days: days,
                        rawText: text, importStartDate: startDate)
        return Result(plan: plan, warnings: warnings, detectedName: detectedName)
    }

    // MARK: - 写法 1：Day 标题

    private static let dayHeader = try! NSRegularExpression(
        pattern: #"^\s*(?:#{1,6}\s*)?(?:[-*]\s*)?\**\s*Day\s*(\d+)\b\**\s*(.*)$"#, options: [.caseInsensitive])

    private static func parseDayHeaders(_ lines: [String]) -> [PlanDay] {
        var days: [PlanDay] = []
        var current: PlanDay?
        var seen = Set<Int>()

        func flush() {
            if var c = current {
                c.notes.extra = c.notes.extra.trimmingCharacters(in: .whitespacesAndNewlines)
                days.append(c)
            }
            current = nil
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("|") { continue }   // 表格行不算标题

            if let m = match(dayHeader, line), let n = Int(m[1]) {
                var rest = m[2]
                var date = ""
                if let dm = firstMatch(#"^[\s·・:：\-—]*(20\d{2})-(\d{1,2})-(\d{1,2})\s*(?:[（(][^）)]*[）)])?"#, in: rest) {
                    date = "\(dm[1])-\(Int(dm[2])!)-\(Int(dm[3])!)"
                    rest = String(rest.dropFirst(dm[0].count))
                } else if let dm = firstMatch(#"^[\s·・:：\-—]*(\d{1,2})/(\d{1,2})\s*(?:[（(][^）)]*[）)])?"#, in: rest) {
                    date = "\(Int(dm[1])!)/\(Int(dm[2])!)"
                    rest = String(rest.dropFirst(dm[0].count))
                }
                // 重复的 Day 编号且没有日期 → 不是新的一天（比如 “Day 30 · 11 项验收清单”），当作别的章节
                if seen.contains(n) && date.isEmpty {
                    flush()
                    continue
                }
                flush()
                seen.insert(n)
                let title = cleanTitle(rest)
                current = PlanDay(day: n, date: date, learnTopic: title)
                continue
            }

            guard current != nil else { continue }

            // 新的标题 / 分隔线 → 当天结束
            if line.hasPrefix("#") || line == "---" { flush(); continue }
            if line.isEmpty { continue }

            if let (key, value) = bullet(line) {
                apply(key: key, value: value, to: &current!)
            } else if let (key, value) = plainLabel(line) {
                apply(key: key, value: value, to: &current!)
            } else {
                current!.notes.extra += stripMarkdown(line) + "\n"
            }
        }
        flush()
        return days
    }

    private static func apply(key: String, value: String, to d: inout PlanDay) {
        let v = stripMarkdown(value)
        if key.contains("直接搜") || (key.contains("搜") && !key.contains("逻辑")) {
            d.notes.searchPython = searchTerms(value)
        } else if key.contains("逻辑") {
            d.notes.searchLogic = searchTerms(value)
        } else if key.contains("学什么") {
            d.notes.learnDetail = v
            if d.learnTopic.isEmpty { d.learnTopic = v }
        } else if key.contains("动手") || key.contains("要做什么") || key.contains("任务") {
            d.notes.whatToDo = v
        } else if key.contains("怎么做") || key.contains("方法") || key.contains("步骤") {
            d.notes.howToDo = v
        } else if key.contains("过关") || key.contains("标准") {
            d.notes.passCriteria = v
        } else if key.contains("力扣") || key.lowercased().contains("leetcode") {
            d.leetcode.title = v
        } else {
            d.notes.extra += "\(key)：\(v)\n"
        }
    }

    // MARK: - 写法 2：按日期 `11/21：...`

    private static func parseDateLines(_ lines: [String]) -> [PlanDay] {
        var days: [PlanDay] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let m = firstMatch(#"^(?:[-*]\s*)?(\d{1,2})/(\d{1,2})\s*(?:[（(][^）)]*[）)])?\s*[：:\-—·]\s*(.+)$"#, in: line) else { continue }
            days.append(PlanDay(day: days.count + 1, date: "\(Int(m[1])!)/\(Int(m[2])!)",
                                learnTopic: cleanTitle(m[3])))
        }
        return days
    }

    // MARK: - 写法 3：一行一条

    private static func parseSimpleLines(_ lines: [String]) -> [PlanDay] {
        var days: [PlanDay] = []
        for raw in lines {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(">") || line.hasPrefix("|") || line == "---" { continue }
            if line.hasPrefix("书名：") || line.hasPrefix("书名:") { continue }
            line = line.replacingOccurrences(of: #"^(?:[-*•]\s*)?(?:\[[ xX]\]\s*)?(?:\d+[.、)]\s*)?"#,
                                             with: "", options: .regularExpression)
            line = stripMarkdown(line)
            if line.isEmpty { continue }
            days.append(PlanDay(day: days.count + 1, date: "", learnTopic: line))
        }
        return days
    }

    // MARK: - 力扣表格 `| Day 1 | 1. Two Sum 两数之和 | Easy | list / dict 入门 |`

    private static func parseLeetTable(_ lines: [String]) -> [Int: LeetCode] {
        var result: [Int: LeetCode] = [:]
        var inTable = false
        var cols: [String] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("|") else { inTable = false; continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .dropFirst().dropLast().map { String($0) }
            if !inTable {
                // 表头
                if cells.contains(where: { $0.contains("力扣") || $0.lowercased().contains("leetcode") }) {
                    inTable = true
                    cols = cells
                } else {
                    // 不是力扣表，跳过整张表
                    cols = []
                }
                continue
            }
            guard !cols.isEmpty, let first = cells.first,
                  let m = firstMatch(#"^Day\s*(\d+)$"#, in: first), let n = Int(m[1]) else { continue }
            var l = LeetCode()
            for (i, c) in cols.enumerated() where i < cells.count {
                if c.contains("力扣") || c.lowercased().contains("leetcode") { l.title = stripMarkdown(cells[i]) }
                else if c.contains("难度") { l.difficulty = cells[i] }
                else if c.contains("对应") || c.contains("知识点") { l.topic = cells[i] }
            }
            if !l.isEmpty { result[n] = l }
        }
        return result
    }

    // MARK: - 小工具

    /// 不带 “- ” 的 `学什么：…`：只认已知的标签，免得把正文里带冒号的句子拆错
    private static let knownKeys = ["学什么", "搜", "逻辑", "动手", "要做什么", "怎么做", "方法", "步骤",
                                    "过关", "标准", "力扣", "leetcode", "复刻项目"]

    private static func plainLabel(_ line: String) -> (String, String)? {
        guard let m = firstMatch(#"^\**([^*：:]{1,12}?)\**\s*[：:]\s*(.*)$"#, in: line) else { return nil }
        let key = m[1].trimmingCharacters(in: .whitespaces)
        guard knownKeys.contains(where: { key.lowercased().contains($0) }) else { return nil }
        return (key, m[2])
    }

    private static func bullet(_ line: String) -> (String, String)? {
        guard let m = firstMatch(#"^[-*•]\s*\*{0,2}([^*：:]{1,16}?)\*{0,2}\s*[：:]\s*(.*)$"#, in: line) else { return nil }
        return (m[1].trimmingCharacters(in: .whitespaces), m[2])
    }

    /// `\`中文\` / \`English\`` → ["中文", "English"]
    static func searchTerms(_ value: String) -> [String] {
        let quoted = allMatches(#"`([^`]+)`"#, in: value).map { $0[1] }
        if !quoted.isEmpty { return quoted }
        return stripMarkdown(value).components(separatedBy: " / ")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func stripMarkdown(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func cleanTitle(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        t = t.replacingOccurrences(of: #"^[\s·・:：\-—]+"#, with: "", options: .regularExpression)
        return stripMarkdown(t)
    }

    private static func match(_ re: NSRegularExpression, _ s: String) -> [String]? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map {
            let r = m.range(at: $0)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    private static func firstMatch(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        return match(re, s)
    }

    private static func allMatches(_ pattern: String, in s: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map {
                let r = m.range(at: $0)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }
}
