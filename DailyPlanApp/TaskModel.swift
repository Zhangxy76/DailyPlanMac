import Foundation

/// 今天临时加的任务（仅这一天），存在 progress.json 的 days[日期].extraTasks 里
struct ExtraTask: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var duration: String = ""
    var done = false
}

/// 频率
struct Frequency: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case once, daily, weekly, everyNDays, weekdays, weekends

        var label: String {
            switch self {
            case .once: return "仅今天一次"
            case .daily: return "每天都有"
            case .weekly: return "每周几天"
            case .everyNDays: return "每隔几天"
            case .weekdays: return "工作日"
            case .weekends: return "周末"
            }
        }
    }

    var type: Kind = .once
    var weekdays: [Int] = []          // 1 = 周一 … 7 = 周日
    var everyN: Int = 2
    var endDate: String? = nil        // 不设就是一直到这本书结束

    static let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    /// 例如 “每周一、三、五，到 12/20”
    var summary: String {
        var s: String
        switch type {
        case .once: s = "仅一次"
        case .daily: s = "每天"
        case .weekly: s = "每周" + weekdays.sorted().map { Self.weekdayNames[$0 - 1] }.joined(separator: "、")
        case .everyNDays: s = "每隔 \(everyN) 天"
        case .weekdays: s = "工作日"
        case .weekends: s = "周末"
        }
        if type != .once, let e = endDate { s += "，到 \(DateUtil.short(e))" }
        return s
    }
}

/// 重复任务：只存一条规则，每天按规则生成那天的行
struct RecurringTask: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var duration: String = ""
    var frequency: Frequency
    var startDate: String             // 从哪天开始
    var anchorDate: String? = nil     // “每隔几天”从哪天开始数（拆分规则时保持节奏不变）

    /// 这天会不会出现（还要再加上“不超过这本书的最后一天”）
    func occurs(on date: String, planEnd: String) -> Bool {
        guard date >= startDate, date <= (frequency.endDate ?? planEnd) else { return false }
        guard let d = DateUtil.date(date) else { return false }
        let wd = DateUtil.calendar.component(.weekday, from: d)   // 1 = 周日
        let iso = wd == 1 ? 7 : wd - 1                            // 1 = 周一 … 7 = 周日
        switch frequency.type {
        case .once: return date == startDate
        case .daily: return true
        case .weekly: return frequency.weekdays.contains(iso)
        case .weekdays: return iso <= 5
        case .weekends: return iso >= 6
        case .everyNDays:
            guard let a = DateUtil.date(anchorDate ?? startDate),
                  let n = DateUtil.calendar.dateComponents([.day], from: a, to: d).day else { return false }
            return n >= 0 && n % max(frequency.everyN, 1) == 0
        }
    }
}

/// 重复任务在某一天“只改今天”的改动
struct TaskOverride: Codable, Hashable {
    var title: String? = nil
    var duration: String? = nil
    var deleted = false
}

/// 今天页上的一行任务（临时任务或重复任务当天的那一次）
struct TaskRow: Identifiable, Hashable {
    var id: String
    var title: String
    var duration: String
    var done: Bool
    var rule: RecurringTask?          // nil = 仅这一天的临时任务

    var text: String { duration.isEmpty ? title : "\(title) \(duration)" }
}

enum TaskScope { case thisDay, future }

enum TaskID {
    static func make() -> String { "t" + UUID().uuidString.prefix(8).lowercased() }
}

/// “口语练习 半小时” → ("口语练习", "半小时")：最后一段像时长就拆出来
enum DurationSplitter {
    static func split(_ text: String) -> (String, String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let sp = t.lastIndex(of: " ") else { return (t, "") }
        let tail = String(t[t.index(after: sp)...])
        let looksLikeDuration = ["小时", "分钟", "分", "钟头", "min", "h", "H"].contains { tail.hasSuffix($0) }
            || tail.hasPrefix("半小时")
        guard looksLikeDuration else { return (t, "") }
        return (String(t[..<sp]).trimmingCharacters(in: .whitespaces), tail)
    }
}
