import Foundation

/// 每天的备注：列表上不显示，点“学什么”才弹出来
struct DayNotes: Codable, Hashable {
    var learnDetail: String = ""      // 学什么（原文）
    var whatToDo: String = ""         // 要做什么（动手做什么）
    var howToDo: String = ""          // 怎么做（原计划没写就留空，用户自己补）
    var searchPython: [String] = []   // 直接搜什么
    var searchLogic: [String] = []    // 计算机逻辑搜什么
    var passCriteria: String = ""     // 过关标准
    var project: String = ""          // 复刻项目（选填）
    var practice: String = ""         // 练习 / 作业（选填）
    var logicLabel: String? = nil     // 原文里第二个搜索词的标签：“计算机逻辑搜什么” 或 “背景原理搜什么”
    var extra: String = ""            // 解析不出归类的原文，原样保留

    /// 显示用的标签；没记下来就用通用的叫法
    var logicTitle: String { logicLabel ?? "背景原理搜什么" }

    init() {}

    enum CodingKeys: String, CodingKey {
        case learnDetail, whatToDo, howToDo, searchPython, searchLogic, passCriteria, project, practice, logicLabel, extra
    }

    /// 字段都可以缺：旧版本存的 plans.json 没有 project / practice / logicLabel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        learnDetail = try c.decodeIfPresent(String.self, forKey: .learnDetail) ?? ""
        whatToDo = try c.decodeIfPresent(String.self, forKey: .whatToDo) ?? ""
        howToDo = try c.decodeIfPresent(String.self, forKey: .howToDo) ?? ""
        searchPython = try c.decodeIfPresent([String].self, forKey: .searchPython) ?? []
        searchLogic = try c.decodeIfPresent([String].self, forKey: .searchLogic) ?? []
        passCriteria = try c.decodeIfPresent(String.self, forKey: .passCriteria) ?? ""
        project = try c.decodeIfPresent(String.self, forKey: .project) ?? ""
        practice = try c.decodeIfPresent(String.self, forKey: .practice) ?? ""
        logicLabel = try c.decodeIfPresent(String.self, forKey: .logicLabel)
        extra = try c.decodeIfPresent(String.self, forKey: .extra) ?? ""
    }
}

struct LeetCode: Codable, Hashable {
    var title: String = ""            // 原文，例如 "1. Two Sum 两数之和"
    var difficulty: String = ""
    var topic: String = ""            // 对应今天学的点
    var note: String = ""             // 用户自己写的怎么做

    var isEmpty: Bool { title.trimmingCharacters(in: .whitespaces).isEmpty }

    init() {}

    enum CodingKeys: String, CodingKey { case title, difficulty, topic, note, leetcodeId, leetcodeTitleEN, leetcodeTitleCN }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty) ?? ""
        topic = try c.decodeIfPresent(String.self, forKey: .topic) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    /// 存盘时顺带写出 leetcodeId / 英文名 / 中文名（从 title 拆出来，只读）
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(topic, forKey: .topic)
        try c.encode(note, forKey: .note)
        try c.encodeIfPresent(number, forKey: .leetcodeId)
        try c.encode(englishTitle, forKey: .leetcodeTitleEN)
        try c.encode(chineseTitle, forKey: .leetcodeTitleCN)
    }

    /// 中文题名：第一个汉字开始到结尾
    var chineseTitle: String {
        guard let i = title.firstIndex(where: { $0.isCJK }) else { return "" }
        return String(title[i...]).trimmingCharacters(in: .whitespaces)
    }

    /// 题号，例如 "1"
    var number: String? {
        let digits = title.prefix(while: { $0.isASCII && $0.isNumber })
        return digits.isEmpty ? nil : String(digits)
    }

    /// 英文题名（去掉题号和中文部分）
    var englishTitle: String {
        var rest = Substring(title)
        if let n = number { rest = rest.dropFirst(n.count) }
        rest = rest.drop(while: { $0 == "." || $0 == " " })
        let en = rest.prefix(while: { !$0.isCJK })
        return en.trimmingCharacters(in: .whitespaces)
    }

    /// 可复制的搜索词，例如 "LeetCode 1 Two Sum"
    var searchTerm: String {
        guard let n = number else { return "LeetCode \(title)" }
        let en = englishTitle
        return en.isEmpty ? "LeetCode \(n)" : "LeetCode \(n) \(en)"
    }
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id = UUID()
    var day: Int
    var date: String                  // yyyy-MM-dd
    var learnTopic: String            // 列表上唯一显示的“学什么”
    var notes = DayNotes()
    var leetcode = LeetCode()
    var needsReview: [String] = []    // 解析时拿不准的地方，生成后标出来让用户改
}

struct Plan: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var startDate: String             // yyyy-MM-dd
    var days: [PlanDay]
    var rawText: String               // 导入时的原文，用来“恢复到导入时的版本”
    var importStartDate: String? = nil
    var archived = false              // 归档后在书架上收进“已归档”

    var endDate: String { days.last?.date ?? startDate }

    /// 改某一天的日期。shiftFollowing = true 时，它后面的每一天都挪同样的天数（保持间隔不变）；
    /// 然后按日期重新排序、重新编 Day 号
    /// 改完会有两天同一个日期的话不改，返回 false（打勾是按日期存的，同一天两份会串）
    @discardableResult
    mutating func changeDate(of id: UUID, to newDate: String, shiftFollowing: Bool) -> Bool {
        days.sort { $0.date < $1.date }
        guard let i = days.firstIndex(where: { $0.id == id }), newDate != days[i].date,
              let old = DateUtil.date(days[i].date), let new = DateUtil.date(newDate),
              let delta = DateUtil.calendar.dateComponents([.day], from: old, to: new).day else { return false }
        var next = days
        next[i].date = newDate
        if shiftFollowing {
            for j in next.indices where j > i { next[j].date = DateUtil.adding(days: delta, to: next[j].date) }
        }
        guard Set(next.map(\.date)).count == next.count else { return false }
        days = next
        days.sort { $0.date < $1.date }
        for k in days.indices { days[k].day = k + 1 }
        startDate = days.first?.date ?? startDate
        return true
    }

    /// 这一天的日期能选的范围：不能早于前一天；不顺延时也不能晚于后一天（免得两天撞日期）
    func dateRange(for id: UUID, shiftFollowing: Bool) -> (min: String?, max: String?) {
        let sorted = days.sorted { $0.date < $1.date }
        guard let i = sorted.firstIndex(where: { $0.id == id }) else { return (nil, nil) }
        let lo = i > 0 ? DateUtil.adding(days: 1, to: sorted[i - 1].date) : nil
        let hi = (!shiftFollowing && i + 1 < sorted.count) ? DateUtil.adding(days: -1, to: sorted[i + 1].date) : nil
        return (lo, hi)
    }

    init(id: UUID = UUID(), name: String, startDate: String, days: [PlanDay], rawText: String,
         importStartDate: String? = nil, archived: Bool = false) {
        self.id = id; self.name = name; self.startDate = startDate; self.days = days
        self.rawText = rawText; self.importStartDate = importStartDate; self.archived = archived
    }

    enum CodingKeys: String, CodingKey { case id, name, startDate, days, rawText, importStartDate, archived }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        startDate = try c.decode(String.self, forKey: .startDate)
        days = try c.decode([PlanDay].self, forKey: .days)
        rawText = try c.decodeIfPresent(String.self, forKey: .rawText) ?? ""
        importStartDate = try c.decodeIfPresent(String.self, forKey: .importStartDate)
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }
}

/// 打勾记录 + 用户当天自己写的内容（和计划数据分开存）
struct DayProgress: Codable, Hashable {
    var learn = false
    var leetcode = false
    var mostImportant = ""            // 今天最重要的一件事
    var myNote = ""                   // 自己补的今天任务 / 备注
    var skipped = false               // 断档提示里选了“跳过”
    var redone: [String] = []         // 这天计划里要重做的力扣（如 Day 30 的 1 / 20 / 704），做出来的题号
    var extraTasks: [ExtraTask] = []  // 这天临时加的任务（仅这一天）
    var recurringDone: [String] = []  // 这天打了勾的重复任务 id
    var overrides: [String: TaskOverride] = [:]   // 重复任务“只改今天”的改动

    init() {}

    var isEmpty: Bool { !learn && !leetcode && mostImportant.isEmpty && myNote.isEmpty }

    enum CodingKeys: String, CodingKey { case learn, leetcode, mostImportant, myNote, skipped, redone, extraTasks, recurringDone, overrides, topThing }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        learn = try c.decodeIfPresent(Bool.self, forKey: .learn) ?? false
        leetcode = try c.decodeIfPresent(Bool.self, forKey: .leetcode) ?? false
        // 旧版本字段叫 topThing，读进来兼容
        mostImportant = try c.decodeIfPresent(String.self, forKey: .mostImportant)
            ?? c.decodeIfPresent(String.self, forKey: .topThing) ?? ""
        myNote = try c.decodeIfPresent(String.self, forKey: .myNote) ?? ""
        skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        redone = try c.decodeIfPresent([String].self, forKey: .redone) ?? []
        extraTasks = try c.decodeIfPresent([ExtraTask].self, forKey: .extraTasks) ?? []
        recurringDone = try c.decodeIfPresent([String].self, forKey: .recurringDone) ?? []
        overrides = try c.decodeIfPresent([String: TaskOverride].self, forKey: .overrides) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(learn, forKey: .learn)
        try c.encode(leetcode, forKey: .leetcode)
        try c.encode(mostImportant, forKey: .mostImportant)
        try c.encode(myNote, forKey: .myNote)
        try c.encode(skipped, forKey: .skipped)
        try c.encode(redone, forKey: .redone)
        try c.encode(extraTasks, forKey: .extraTasks)
        try c.encode(recurringDone, forKey: .recurringDone)
        try c.encode(overrides, forKey: .overrides)
    }
}

extension Character {
    var isCJK: Bool {
        unicodeScalars.contains { s in
            (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value)
                || (0xFF00...0xFFEF).contains(s.value) || (0x3000...0x303F).contains(s.value)
        }
    }
}

enum DateUtil {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current    // Mac 本地时区，不写死 UTC
        c.locale = Locale(identifier: "zh_CN")
        return c
    }

    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(_ s: String) -> Date? { ymd.date(from: s) }
    static func string(_ d: Date) -> String { ymd.string(from: d) }

    static func adding(days: Int, to s: String) -> String {
        guard let d = date(s), let r = calendar.date(byAdding: .day, value: days, to: d) else { return s }
        return string(r)
    }

    /// 今天（支持测试用启动参数：-debugToday 2026-12-20）
    static func today() -> String {
        if let o = UserDefaults.standard.string(forKey: "debugToday"), date(o) != nil { return o }
        return string(Date())
    }

    /// "11月21日（六）"
    static func display(_ s: String) -> String {
        guard let d = date(s) else { return s }
        let c = calendar
        let m = c.component(.month, from: d), day = c.component(.day, from: d)
        let w = ["日", "一", "二", "三", "四", "五", "六"][c.component(.weekday, from: d) - 1]
        return "\(m)月\(day)日（\(w)）"
    }

    /// "11/21"
    static func short(_ s: String) -> String {
        guard let d = date(s) else { return s }
        let c = calendar
        return String(format: "%02d/%02d", c.component(.month, from: d), c.component(.day, from: d))
    }
}
