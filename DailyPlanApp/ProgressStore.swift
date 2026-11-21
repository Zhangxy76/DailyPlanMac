import Foundation
import SwiftUI

/// 今天对应计划里的哪一天
enum TodayState {
    case notStarted(PlanDay)      // 今天 < 开始日
    case active(PlanDay)          // 正在进行
    case finished(PlanDay)        // 今天 > 结束日
    case empty

    var day: PlanDay? {
        switch self {
        case .notStarted(let d), .active(let d), .finished(let d): return d
        case .empty: return nil
        }
    }
}

/// 所有本地数据：~/Library/Application Support/DailyPlan/
///   plans.json     所有计划（含导入原文）
///   progress.json  打勾、打卡、复习、错题本，按书 id 分开存（结构见 CheckinModel.swift）
final class PlanStore: ObservableObject {
    static let shared = PlanStore()

    @Published private(set) var plans: [Plan] = []
    @Published var currentPlanID: UUID? { didSet { saveSettings() } }
    @Published private(set) var progress: [String: BookProgress] = [:]
    @Published var today: String = DateUtil.today()

    let dir: URL
    private var plansURL: URL { dir.appendingPathComponent("plans.json") }
    private var progressURL: URL { dir.appendingPathComponent("progress.json") }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var d = base.appendingPathComponent("DailyPlan", isDirectory: true)
        #if DEBUG
        // 测试用：-dataDir /some/path，不碰真实数据
        if let o = UserDefaults.standard.string(forKey: "dataDir") { d = URL(fileURLWithPath: o, isDirectory: true) }
        #endif
        dir = d
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - 读写

    private func load() {
        let dec = JSONDecoder()
        if let data = try? Data(contentsOf: plansURL), let p = try? dec.decode([Plan].self, from: data) {
            plans = p
        }
        if let data = try? Data(contentsOf: progressURL),
           let p = try? dec.decode([String: BookProgress].self, from: data) {
            progress = p
        }
        // 只在第一次打开（还没有 plans.json）时放进预置的书；之后用户删掉它，App 照常用，不会再塞回来
        if !FileManager.default.fileExists(atPath: plansURL.path), let preset = Self.presetPlan() {
            plans = [preset]
            savePlans()
        }
        if let s = UserDefaults.standard.string(forKey: "currentPlanID"), let id = UUID(uuidString: s),
           plans.contains(where: { $0.id == id }) {
            currentPlanID = id
        } else {
            currentPlanID = plans.first?.id
        }
        syncAllToday()
    }

    /// 预置：第一次打开时，用和“导入”同一套流程，从 App 里带的 python-plan.md 生成
    static func presetPlan() -> Plan? {
        guard let url = Bundle.main.url(forResource: "python-plan", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return PlanParser.parse(text, name: "Python 30 天精通计划").plan
    }

    private func savePlans() { write(plans, to: plansURL) }
    private func saveProgress() { write(progress, to: progressURL) }
    private func saveSettings() { UserDefaults.standard.set(currentPlanID?.uuidString, forKey: "currentPlanID") }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? enc.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: - 计划

    var currentPlan: Plan? { plans.first { $0.id == currentPlanID } ?? plans.first }

    func addPlan(_ plan: Plan) {
        plans.append(plan)
        currentPlanID = plan.id
        savePlans()
    }

    func updatePlan(_ plan: Plan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { addPlan(plan); return }
        plans[i] = plan
        savePlans()
    }

    func deletePlan(_ id: UUID) {
        plans.removeAll { $0.id == id }
        progress[id.uuidString] = nil
        if currentPlanID == id { currentPlanID = plans.first?.id }
        savePlans(); saveProgress()
    }

    /// 恢复到导入时的版本：把导入原文重新解析一遍，计划 id / 名字不变，打勾记录保留
    func importedVersion(of plan: Plan) -> Plan {
        var fresh = PlanParser.parse(plan.rawText, name: plan.name, startDate: plan.importStartDate).plan
        fresh.id = plan.id
        return fresh
    }

    func setArchived(_ id: UUID, _ archived: Bool) {
        guard let i = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[i].archived = archived
        savePlans()
    }

    // MARK: - 书架

    enum BookStatus: String { case notStarted = "待开始", studying = "在学中", finished = "已完成", ended = "已结束", archived = "已归档" }

    func status(_ plan: Plan) -> BookStatus {
        if plan.archived { return .archived }
        if !plan.days.isEmpty && completedCount(plan) == plan.days.count { return .finished }
        switch state(for: plan) {
        case .notStarted, .empty: return .notStarted
        case .active: return .studying
        case .finished: return .ended     // 日期过了但没全部打完勾
        }
    }

    /// 上次学到哪天：最后一个有打勾 / 写过东西的那天
    func lastStudied(_ plan: Plan) -> PlanDay? {
        let p = book(plan).days
        return plan.days.last { d in
            guard let x = p[d.date] else { return false }
            return x.learn || x.leetcode || !x.mostImportant.isEmpty || !x.myNote.isEmpty
        }
    }

    // MARK: - 今天

    func refreshToday() {
        let t = DateUtil.today()
        if t != today {
            today = t
            syncAllToday()
        }
        ReviewNotifier.notifyIfNeeded(self)
    }

    func state(for plan: Plan?) -> TodayState {
        guard let plan, let first = plan.days.first, let last = plan.days.last else { return .empty }
        if today < first.date { return .notStarted(first) }
        if today > last.date { return .finished(last) }
        if let d = plan.days.first(where: { $0.date == today }) { return .active(d) }
        // 日期中间有空档（用户改过日期）：显示今天之前最近的一天
        let prev = plan.days.last(where: { $0.date < today }) ?? first
        return .active(prev)
    }

    func dayAfter(_ day: PlanDay, in plan: Plan) -> PlanDay? {
        guard let i = plan.days.firstIndex(where: { $0.id == day.id }), i + 1 < plan.days.count else { return nil }
        return plan.days[i + 1]
    }

    func dayBefore(_ day: PlanDay, in plan: Plan) -> PlanDay? {
        guard let i = plan.days.firstIndex(where: { $0.id == day.id }), i > 0 else { return nil }
        return plan.days[i - 1]
    }

    // MARK: - 打勾

    func book(_ plan: Plan) -> BookProgress { progress[plan.id.uuidString] ?? BookProgress() }

    func mutate(_ plan: Plan, _ f: (inout BookProgress) -> Void) {
        var b = book(plan)
        f(&b)
        progress[plan.id.uuidString] = b
        saveProgress()
    }

    func progress(_ plan: Plan, _ date: String) -> DayProgress {
        book(plan).days[date] ?? DayProgress()
    }

    func setProgress(_ plan: Plan, _ date: String, _ p: DayProgress) {
        mutate(plan) { $0.days[date] = p }
        syncCheckin(plan, date)
    }

    func binding<T>(_ plan: Plan, _ date: String, _ kp: WritableKeyPath<DayProgress, T>) -> Binding<T> {
        Binding(
            get: { self.progress(plan, date)[keyPath: kp] },
            set: { v in
                var p = self.progress(plan, date)
                p[keyPath: kp] = v
                self.setProgress(plan, date, p)
            })
    }

    /// 当天都打勾 = 完成（没有力扣的那天只看“学什么”）
    func isComplete(_ plan: Plan, _ day: PlanDay) -> Bool {
        let p = progress(plan, day.date)
        return p.learn && (day.leetcode.isEmpty || p.leetcode)
    }

    func completedCount(_ plan: Plan) -> Int {
        plan.days.filter { isComplete(plan, $0) }.count
    }

    // MARK: - 打卡

    /// 打勾变了之后同步打卡：
    /// - 当天（23:59 前）完成 → 按时打卡，算连续
    /// - 过了那天才完成（补）→ 补打，只算累计
    /// - 还没到的那天提前打勾 → 先不打卡，到那天打开 App 时自动记为当天打卡
    /// - 取消打勾 → 撤掉这天的打卡和还没做的复习
    func syncCheckin(_ plan: Plan, _ date: String) {
        guard let day = plan.days.first(where: { $0.date == date }) else { return }
        let complete = isComplete(plan, day)
        let key = "day\(day.day)"
        mutate(plan) { b in
            let had = b.checkins[date] == true || b.makeups[date] == true
            if complete {
                guard !had else { return }
                if date == today { b.checkins[date] = true }
                else if date < today { b.makeups[date] = true }
                else { return }
                b.hours[date] = b.hoursPerDay
                // 完成当天起，第 7 天、第 14 天各复习一次
                for n in [7, 14] {
                    let r = DateUtil.adding(days: n, to: today)
                    if !(b.reviews[r] ?? []).contains(key) { b.reviews[r, default: []].append(key) }
                }
            } else {
                guard had else { return }
                b.checkins[date] = nil
                b.makeups[date] = nil
                b.hours[date] = nil
                for (r, keys) in b.reviews {
                    let done = b.reviewsDone[r] ?? []
                    if keys.contains(key) && !done.contains(key) {
                        b.reviews[r] = keys.filter { $0 != key }
                        if b.reviews[r]?.isEmpty == true { b.reviews[r] = nil }
                    }
                }
            }
            b.recomputeHours()
        }
    }

    /// 打开 App / 过零点时：今天这天如果提前就打完勾了，补记成今天的打卡
    func syncAllToday() {
        for p in plans { syncCheckin(p, today) }
    }

    /// 连续打卡：按自然日往回数，只算按时打卡；今天还没打就从昨天数起
    func streak(_ plan: Plan) -> Int {
        let c = book(plan).checkins
        var d = c[today] == true ? today : DateUtil.adding(days: -1, to: today)
        var n = 0
        while c[d] == true { n += 1; d = DateUtil.adding(days: -1, to: d) }
        return n
    }

    func totalCheckins(_ plan: Plan) -> Int { book(plan).totalCheckins }
    func totalHours(_ plan: Plan) -> Double { book(plan).totalHours }

    /// 昨天是这本书里的一天，但没有按时打卡
    func missedYesterday(_ plan: Plan) -> Bool {
        let y = DateUtil.adding(days: -1, to: today)
        guard plan.days.contains(where: { $0.date == y }) else { return false }
        return book(plan).checkins[y] != true
    }

    enum CheckinMark { case checked, madeUp, missed, today, future }

    func mark(_ plan: Plan, _ day: PlanDay) -> CheckinMark {
        let b = book(plan)
        if b.checkins[day.date] == true { return .checked }
        if b.makeups[day.date] == true { return .madeUp }
        if day.date == today { return .today }
        return day.date < today ? .missed : .future
    }

    func setHoursPerDay(_ plan: Plan, _ h: Double) { mutate(plan) { $0.hoursPerDay = h } }

    // MARK: - 复习（第 7、14 天）

    func dueReviews(_ plan: Plan) -> [DueReview] {
        let b = book(plan)
        var seen = Set<String>()
        var out: [DueReview] = []
        for date in b.reviews.keys.sorted() where date <= today {
            let done = b.reviewsDone[date] ?? []
            for key in b.reviews[date] ?? [] where !done.contains(key) && !seen.contains(key) {
                guard let n = Int(key.dropFirst(3)), let day = plan.days.first(where: { $0.day == n }) else { continue }
                seen.insert(key)
                out.append(DueReview(date: date, key: key, day: day))
            }
        }
        return out.sorted { ($0.date, $0.day.day) < ($1.date, $1.day.day) }
    }

    /// 复习完了：这一条以及更早欠着的同一个 Day 都算做完
    func markReviewed(_ plan: Plan, _ r: DueReview) {
        mutate(plan) { b in
            for (date, keys) in b.reviews where date <= today && keys.contains(r.key) {
                if !(b.reviewsDone[date] ?? []).contains(r.key) { b.reviewsDone[date, default: []].append(r.key) }
            }
        }
    }

    // MARK: - 错题本（3 天后重做）

    static func leetKey(_ l: LeetCode) -> String { l.number ?? l.title }

    func wrongList(_ plan: Plan) -> [(key: String, item: WrongItem)] {
        book(plan).wrongLeetcode.map { ($0.key, $0.value) }.sorted { $0.item.firstDate < $1.item.firstDate }
    }

    func isWrong(_ plan: Plan, _ day: PlanDay) -> Bool {
        book(plan).wrongLeetcode[Self.leetKey(day.leetcode)] != nil
    }

    func addWrong(_ plan: Plan, _ day: PlanDay) {
        let key = Self.leetKey(day.leetcode)
        mutate(plan) { b in
            guard b.wrongLeetcode[key] == nil else { return }
            b.wrongLeetcode[key] = WrongItem(title: day.leetcode.title, day: day.day,
                                             firstDate: today, nextReview: DateUtil.adding(days: 3, to: today))
        }
    }

    func removeWrong(_ plan: Plan, _ key: String) { mutate(plan) { $0.wrongLeetcode[key] = nil } }

    func redoFailed(_ plan: Plan, _ key: String) {
        mutate(plan) { $0.wrongLeetcode[key]?.nextReview = DateUtil.adding(days: 3, to: today) }
    }

    /// 今天要重做的力扣：错题本里到期的 + 当天计划里写了“重做”的题（如 Day 30 的 1 / 20 / 704）
    func dueRedos(_ plan: Plan, on day: PlanDay?) -> [DueRedo] {
        let b = book(plan)
        var out: [DueRedo] = b.wrongLeetcode
            .filter { $0.value.nextReview <= today }
            .sorted { $0.value.nextReview < $1.value.nextReview }
            .map { DueRedo(key: $0.key, title: $0.value.title, source: .wrongBook) }
        if let day, day.leetcode.title.contains("重做") {
            let done = progress(plan, day.date).redone
            let nums = day.leetcode.title.split(whereSeparator: { !($0.isASCII && $0.isNumber) }).map(String.init)
            for n in nums where !done.contains(n) && !out.contains(where: { $0.key == n }) {
                let title = plan.days.first(where: { $0.leetcode.number == n && !$0.leetcode.title.contains("重做") })?
                    .leetcode.title ?? "第 \(n) 题"
                out.append(DueRedo(key: n, title: title, source: .planRedo))
            }
        }
        return out
    }

    /// 重做做出来了：从错题本移出；如果是当天计划里要重做的题，记在这天
    func redoPassed(_ plan: Plan, _ r: DueRedo, on day: PlanDay?) {
        mutate(plan) { $0.wrongLeetcode[r.key] = nil }
        if let day, day.leetcode.title.contains("重做") {
            var p = progress(plan, day.date)
            if !p.redone.contains(r.key) { p.redone.append(r.key) }
            mutate(plan) { $0.days[day.date] = p }
        }
    }

    // MARK: - 导出

    func exportMarkdown(_ plan: Plan) -> String {
        var s = "# \(plan.name) · 打勾记录\n\n"
        s += "导出时间：\(DateUtil.today())　已完成 \(completedCount(plan)) / \(plan.days.count) 天\n\n"
        s += "连续打卡 \(streak(plan)) 天 · 累计打卡 \(totalCheckins(plan)) 天 · 累计学习 \(String(format: "%g", totalHours(plan))) 小时 · 错题本 \(book(plan).wrongLeetcode.count) 道\n\n"
        s += "| Day | 日期 | 学什么 | 学 | 力扣 | 力 | 今天最重要的一件事 |\n|---|---|---|---|---|---|---|\n"
        for d in plan.days {
            let p = progress(plan, d.date)
            func cell(_ t: String) -> String { t.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ") }
            s += "| \(d.day) | \(DateUtil.short(d.date)) | \(cell(d.learnTopic)) | \(p.learn ? "✓" : "○") | \(cell(d.leetcode.title)) | \(d.leetcode.isEmpty ? "-" : (p.leetcode ? "✓" : "○")) | \(cell(p.mostImportant)) |\n"
        }
        let notes = plan.days.compactMap { d -> String? in
            let n = progress(plan, d.date).myNote.trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? nil : "### Day \(d.day) · \(DateUtil.short(d.date))\n\n\(n)\n"
        }
        if !notes.isEmpty { s += "\n## 自己写的备注\n\n" + notes.joined(separator: "\n") }
        return s
    }
}
