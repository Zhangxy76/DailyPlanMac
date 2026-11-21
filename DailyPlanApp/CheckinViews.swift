import SwiftUI
import UserNotifications

// MARK: - 今天页顶部：已连续打卡 X 天

struct StreakLabel: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan

    var body: some View {
        let n = store.streak(plan)
        if n > 0 {
            Label("已连续打卡 \(n) 天", systemImage: "flame.fill")
                .foregroundStyle(.orange)
        } else if store.missedYesterday(plan) {
            Text("昨天没打卡，今天重新开始").foregroundStyle(.secondary)
        } else if case .active = store.state(for: plan) {
            Text("今天开始打卡").foregroundStyle(.secondary)
        }
    }
}

// MARK: - 总览页顶部：打卡日历

struct CheckinCalendar: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let onOpen: (PlanDay) -> Void

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("打卡日历").font(.subheadline.bold())
                Spacer()
                Text("连续 \(store.streak(plan)) 天 · 累计 \(store.totalCheckins(plan)) 天 · \(String(format: "%g", store.totalHours(plan))) 小时")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                    Text($0).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 26) }
                ForEach(plan.days) { d in
                    Button { onOpen(d) } label: { cell(d) }
                        .buttonStyle(.plain)
                        .help("Day \(d.day) · \(DateUtil.display(d.date))：\(label(store.mark(plan, d)))")
                }
            }
            HStack(spacing: 10) {
                legend(AnyView(Circle().fill(Color.accentColor)), "已打卡")
                legend(AnyView(Circle().fill(Color.orange)), "补打")
                legend(AnyView(Circle().strokeBorder(Color.secondary, lineWidth: 1.5)), "缺卡")
                legend(AnyView(Circle().fill(Color.secondary.opacity(0.2))), "还没到")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    /// 第一天前面空几格（周一开头）
    private var leadingBlanks: Int {
        guard let first = plan.days.first, let d = DateUtil.date(first.date) else { return 0 }
        let wd = DateUtil.calendar.component(.weekday, from: d)   // 1 = 周日
        return (wd + 5) % 7
    }

    @ViewBuilder private func cell(_ d: PlanDay) -> some View {
        let m = store.mark(plan, d)
        let num = Text("\(d.day)").font(.caption2.monospacedDigit())
        ZStack {
            switch m {
            case .checked:
                Circle().fill(Color.accentColor)
                num.foregroundStyle(.white)
            case .madeUp:
                Circle().fill(Color.orange)
                num.foregroundStyle(.white)
            case .missed:
                Circle().strokeBorder(Color.secondary, lineWidth: 1.5)
                num.foregroundStyle(.secondary)
            case .today:
                Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                num.foregroundStyle(Color.accentColor).fontWeight(.bold)
            case .future:
                Circle().fill(Color.secondary.opacity(0.18))
                num.foregroundStyle(.secondary)
            }
        }
        .frame(width: 26, height: 26)
        .frame(maxWidth: .infinity)
    }

    private func label(_ m: PlanStore.CheckinMark) -> String {
        switch m {
        case .checked: return "已打卡"
        case .madeUp: return "补打"
        case .missed: return "缺卡"
        case .today: return "今天"
        case .future: return "还没到"
        }
    }

    private func legend(_ shape: AnyView, _ text: String) -> some View {
        HStack(spacing: 3) { shape.frame(width: 9, height: 9); Text(text) }
    }
}

// MARK: - 今天页底部：今天要复习 / 今天要重做力扣

struct DueList: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let day: PlanDay
    @State private var shown: DueReview?

    var body: some View {
        let reviews = store.dueReviews(plan)
        let redos = store.dueRedos(plan, on: day)
        if !reviews.isEmpty || !redos.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(reviews) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle").foregroundStyle(.blue)
                        Button { shown = r } label: {
                            Text("今天要复习：Day \(r.day.day) \(r.day.learnTopic)")
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .help("点开看那天的过关标准，复习就是重做过关标准")
                        .popover(isPresented: Binding(get: { shown == r }, set: { if !$0 { shown = nil } }),
                                 arrowEdge: .leading) {
                            NoteCard(plan: plan, day: r.day)
                        }
                        Spacer(minLength: 4)
                        Button("复习完了") { store.markReviewed(plan, r) }
                    }
                }
                ForEach(redos) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "pencil.circle").foregroundStyle(.orange)
                        Text("今天要重做力扣：\(r.title)").lineLimit(2)
                        Spacer(minLength: 4)
                        Button("做出来了") { store.redoPassed(plan, r, on: day) }
                        if r.source == .wrongBook {
                            Button("没做出来") { store.redoFailed(plan, r.key) }
                                .help("3 天后再重做")
                        }
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .padding(8)
            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - 错题本

struct WrongBookView: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan

    var body: some View {
        let list = store.wrongList(plan)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("错题本（\(list.count) 道）").font(.headline)
                Text("点“难 / 错了”的题进这里，3 天后出现在今天页底部重做；做出来了就移出，没做出来再排 3 天后。")
                    .font(.caption).foregroundStyle(.secondary)
                if list.isEmpty {
                    Text("还没有错题").foregroundStyle(.tertiary).padding(.top, 20)
                        .frame(maxWidth: .infinity)
                }
                ForEach(list, id: \.key) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.item.title).font(.callout.bold())
                        Text("Day \(e.item.day) · 第一次做 \(DateUtil.short(e.item.firstDate)) · 下次重做 \(DateUtil.short(e.item.nextReview))\(e.item.nextReview == store.today ? "（今天）" : e.item.nextReview < store.today ? "（已到期）" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            CopyList(label: "搜索词", terms: [searchTerm(e.item.title)])
                        }
                        HStack(spacing: 10) {
                            Button("做出来了，移出") {
                                store.redoPassed(plan, DueRedo(key: e.key, title: e.item.title, source: .wrongBook), on: nil)
                            }
                            Button("没做出来，3 天后再做") { store.redoFailed(plan, e.key) }
                            Spacer()
                            Button("移出", role: .destructive) { store.removeWrong(plan, e.key) }
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
        }
    }

    private func searchTerm(_ title: String) -> String {
        var l = LeetCode()
        l.title = title
        return l.searchTerm
    }
}

// MARK: - 可选：复习提醒发系统通知（默认关）

enum ReviewNotifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 每天最多提醒一次，只有用户自己在设置里打开了才发
    static func notifyIfNeeded(_ store: PlanStore) {
        let d = UserDefaults.standard
        guard d.bool(forKey: "reviewNotify"), d.string(forKey: "reviewNotifiedOn") != store.today else { return }
        var reviews = 0, redos = 0
        for p in store.plans where !p.archived {
            reviews += store.dueReviews(p).count
            redos += store.dueRedos(p, on: store.state(for: p).day).count
        }
        guard reviews + redos > 0 else { return }
        d.set(store.today, forKey: "reviewNotifiedOn")
        let c = UNMutableNotificationContent()
        c.title = "每日计划"
        c.body = [reviews > 0 ? "今天要复习 \(reviews) 个" : nil, redos > 0 ? "要重做力扣 \(redos) 道" : nil]
            .compactMap { $0 }.joined(separator: "，")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "review-\(store.today)", content: c, trigger: nil))
    }
}
