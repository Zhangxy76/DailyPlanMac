import Foundation

/// 错题本里的一道题
struct WrongItem: Codable, Hashable {
    var title: String          // 例如 "1. Two Sum 两数之和"
    var day: Int               // 哪一天的题
    var firstDate: String      // 第一次做（点“难 / 错了”）的日期
    var nextReview: String     // 下次重做的日期
}

/// 一本书的全部进度，progress.json 里按书 id 存：
/// {
///   "<planId>": {
///     "days":          { "2026-11-21": { learn, leetcode, mostImportant, myNote, skipped, redone } },
///     "checkins":      { "2026-11-21": true },        当天按时打卡（算连续）
///     "makeups":       { "2026-11-22": true },        第二天补打的卡（只算累计，不算连续）
///     "hours":         { "2026-11-21": 2.5 },         每次打卡记的学习时长
///     "totalHours":    5.0,
///     "hoursPerDay":   2.5,                           保底版改成 1.5
///     "reviews":       { "2026-11-28": ["day1"] },    哪天要复习哪几个 Day
///     "reviewsDone":   { "2026-11-28": ["day1"] },
///     "wrongLeetcode": { "1": { title, day, firstDate, nextReview } }
///   }
/// }
struct BookProgress: Codable {
    var days: [String: DayProgress] = [:]
    var checkins: [String: Bool] = [:]
    var makeups: [String: Bool] = [:]
    var hours: [String: Double] = [:]
    var totalHours: Double = 0
    var hoursPerDay: Double = 2.5
    var reviews: [String: [String]] = [:]
    var reviewsDone: [String: [String]] = [:]
    var wrongLeetcode: [String: WrongItem] = [:]
    var recurringTasks: [RecurringTask] = []   // 重复任务的规则（每天按规则生成那天的行）

    init() {}

    enum CodingKeys: String, CodingKey, CaseIterable {
        case days, checkins, makeups, hours, totalHours, hoursPerDay, reviews, reviewsDone, wrongLeetcode, recurringTasks
    }

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let any = try decoder.container(keyedBy: AnyKey.self)
        let known = Set(CodingKeys.allCases.map(\.rawValue))
        if any.allKeys.contains(where: { known.contains($0.stringValue) }) {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            days = try c.decodeIfPresent([String: DayProgress].self, forKey: .days) ?? [:]
            checkins = try c.decodeIfPresent([String: Bool].self, forKey: .checkins) ?? [:]
            makeups = try c.decodeIfPresent([String: Bool].self, forKey: .makeups) ?? [:]
            hours = try c.decodeIfPresent([String: Double].self, forKey: .hours) ?? [:]
            totalHours = try c.decodeIfPresent(Double.self, forKey: .totalHours) ?? 0
            hoursPerDay = try c.decodeIfPresent(Double.self, forKey: .hoursPerDay) ?? 2.5
            reviews = try c.decodeIfPresent([String: [String]].self, forKey: .reviews) ?? [:]
            reviewsDone = try c.decodeIfPresent([String: [String]].self, forKey: .reviewsDone) ?? [:]
            wrongLeetcode = try c.decodeIfPresent([String: WrongItem].self, forKey: .wrongLeetcode) ?? [:]
            recurringTasks = try c.decodeIfPresent([RecurringTask].self, forKey: .recurringTasks) ?? []
        } else {
            // 旧格式：{ "2026-11-21": {...}, ... } 直接按日期存
            for k in any.allKeys where DateUtil.date(k.stringValue) != nil {
                days[k.stringValue] = try any.decode(DayProgress.self, forKey: k)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(days, forKey: .days)
        try c.encode(checkins, forKey: .checkins)
        try c.encode(makeups, forKey: .makeups)
        try c.encode(hours, forKey: .hours)
        try c.encode(totalHours, forKey: .totalHours)
        try c.encode(hoursPerDay, forKey: .hoursPerDay)
        try c.encode(reviews, forKey: .reviews)
        try c.encode(reviewsDone, forKey: .reviewsDone)
        try c.encode(wrongLeetcode, forKey: .wrongLeetcode)
        try c.encode(recurringTasks, forKey: .recurringTasks)
    }

    /// 累计打卡天数（按时 + 补打）
    var totalCheckins: Int { Set(checkins.filter(\.value).keys).union(makeups.filter(\.value).keys).count }

    mutating func recomputeHours() {
        totalHours = hours.values.reduce(0, +)
    }
}

/// 今天页底部“要复习”的一条
struct DueReview: Identifiable, Hashable {
    var date: String       // 排在哪天
    var key: String        // "day1"
    var day: PlanDay
    var id: String { date + "|" + key }
}

/// 今天页底部“要重做力扣”的一条
struct DueRedo: Identifiable, Hashable {
    enum Source: Hashable { case wrongBook, planRedo }
    var key: String        // 题号
    var title: String
    var source: Source
    var id: String { key + "|" + (source == .wrongBook ? "w" : "p") }
}
