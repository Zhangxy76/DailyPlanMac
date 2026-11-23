import SwiftUI

/// 书架：像背单词 App 选单词书一样，一本书就是一个计划
struct ShelfView: View {
    @EnvironmentObject var store: PlanStore
    @EnvironmentObject var settings: WindowSettings
    let onOpen: (Plan) -> Void
    var onOpenToday: () -> Void = {}
    @State private var showArchived = false

    var body: some View {
        let active = store.plans.filter { !$0.archived }
        let archived = store.plans.filter { $0.archived }
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("我的计划书").font(.title3.bold())
                    Text("选一本计划书，开始每日学习").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu { AppMenuItems() } label: { Image(systemName: "gearshape") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("开机启动、桌面模式、退出")
                PinButton().buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    StudyTimerView()
                    if settings.showTodaySummary {
                        TodaySummaryView(onOpen: onOpen, onOpenToday: onOpenToday)
                    }
                    ForEach(active) { p in
                        BookCard(plan: p, isCurrent: p.id == store.currentPlanID) { onOpen(p) }
                    }

                    Button { PlanActions.openImport() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("新书").font(.headline)
                                Text("导入计划文字，生成一本新书").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(.secondary))
                    }
                    .buttonStyle(.plain)

                    if !archived.isEmpty {
                        DisclosureGroup(isExpanded: $showArchived) {
                            VStack(spacing: 10) {
                                ForEach(archived) { p in
                                    BookCard(plan: p, isCurrent: false) { onOpen(p) }
                                }
                            }
                            .padding(.top, 6)
                        } label: {
                            Text("已归档 \(archived.count) 本").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}

struct BookCard: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let isCurrent: Bool
    let onOpen: () -> Void

    var body: some View {
        let done = store.completedCount(plan)
        let total = plan.days.count
        let status = store.status(plan)
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.name).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 6)
                    Text(status.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(color(status).opacity(0.18), in: Capsule())
                        .foregroundStyle(color(status))
                }
                Text("\(total) 天 · 已完成 \(done) / \(total) · \(plan.days.first?.date ?? plan.startDate) 开始")
                    .font(.caption).foregroundStyle(.secondary)
                Text("连续打卡 \(store.streak(plan)) 天 · 累计 \(store.totalCheckins(plan)) 天 · 学习 \(String(format: "%g", store.totalHours(plan))) 小时")
                    .font(.caption)
                    .foregroundStyle(store.streak(plan) > 0 ? Color.orange : .secondary)
                if let last = store.lastStudied(plan) {
                    Text("上次学到 Day \(last.day)：\(last.learnTopic)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                    Text("\(total == 0 ? 0 : done * 100 / total)%")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isCurrent ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isCurrent ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("打开") { onOpen() }
            Button("在新窗口打开") { AppDelegate.shared.openBookWindow(plan.id) }
            Button("编辑这本书…") { PlanActions.openEditor(plan) }
            Button("导出打勾记录（Markdown）…") { PlanActions.export(plan) }
            Divider()
            Button(plan.archived ? "取消归档" : "归档") { store.setArchived(plan.id, !plan.archived) }
            Button("删除这本书…", role: .destructive) { PlanActions.confirmDelete(plan) }
        }
        .help("点一下进去学这本书；右键可以编辑、归档、删除")
    }

    private func color(_ s: PlanStore.BookStatus) -> Color {
        switch s {
        case .studying: return .accentColor
        case .finished: return .green
        case .ended: return .secondary
        case .notStarted: return .orange
        case .archived: return .secondary
        }
    }
}

/// 窗口里的 App 菜单：菜单栏图标被刘海挡住时也能找到开机启动、桌面模式、退出
struct AppMenuItems: View {
    @EnvironmentObject var settings: WindowSettings

    var body: some View {
        Toggle("开机启动", isOn: Binding(
            get: { LoginItem.isEnabled },
            set: { on in
                UserDefaults.standard.set(!on, forKey: "loginItemUserDisabled")
                LoginItem.set(on)
            }))
        Toggle("钉住（一直在最前面）", isOn: $settings.pinned).disabled(settings.desktopMode)
        Toggle("桌面模式（贴在桌面上）", isOn: $settings.desktopMode)
        Toggle("在程序坞显示", isOn: $settings.showInDock)
        Toggle("书架顶部显示“今天要做”", isOn: $settings.showTodaySummary)
        Toggle("复习 / 重做提醒发系统通知", isOn: Binding(
            get: { UserDefaults.standard.bool(forKey: "reviewNotify") },
            set: { on in
                UserDefaults.standard.set(on, forKey: "reviewNotify")
                if on { ReviewNotifier.requestPermission() }
            }))
        Divider()
        Button("隐藏窗口") { AppDelegate.shared.panel.orderOut(nil) }
        Button("退出每日计划（⌘Q）") { NSApp.terminate(nil) }
    }
}

// MARK: - 书架顶部：今天要做（所有在学的书的今天，放在一起）

struct TodaySummaryView: View {
    @EnvironmentObject var store: PlanStore
    let onOpen: (Plan) -> Void
    var onOpenToday: (() -> Void)? = nil

    struct Item: Identifiable {
        let plan: Plan
        let day: PlanDay
        var id: UUID { plan.id }
    }

    var body: some View {
        let items = Self.items(store)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { onOpenToday?() } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("今天要做").font(.headline)
                        if onOpenToday != nil {
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DateUtil.display(store.today)).font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onOpenToday == nil)
                .help("只看今天要做的")
                ForEach(items) { item in
                    BookToday(plan: item.plan, day: item.day, onOpen: { onOpen(item.plan) })
                    if item.id != items.last?.id { Divider() }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// 所有在学的书今天那一天
    static func items(_ store: PlanStore) -> [Item] {
        store.plans.filter { !$0.archived }.compactMap { p in
            if case .active(let d) = store.state(for: p) { return Item(plan: p, day: d) }
            return nil
        }
    }

    /// 一本书今天的几行：学什么、力扣、临时 / 重复任务，都能直接打勾
    struct BookToday: View {
        @EnvironmentObject var store: PlanStore
        let plan: Plan
        let day: PlanDay
        let onOpen: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Button(action: onOpen) {
                        HStack(spacing: 4) {
                            Text(plan.name).font(.subheadline.bold()).lineLimit(1)
                            Text("· Day \(day.day)").font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("进到这本书")
                    Spacer()
                    if store.streak(plan) > 0 {
                        Label("\(store.streak(plan))", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                            .help("已连续打卡 \(store.streak(plan)) 天")
                    }
                    Button { AppDelegate.shared.openBookWindow(plan.id) } label: {
                        Image(systemName: "macwindow.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("在新窗口打开这本书")
                }
                CheckRow(checked: store.binding(plan, day.date, \.learn),
                         text: "学什么：\(day.learnTopic)", review: false, onTap: onOpen)
                if !day.leetcode.isEmpty {
                    CheckRow(checked: store.binding(plan, day.date, \.leetcode),
                             text: "力扣：\(day.leetcode.title)", review: false, onTap: onOpen)
                }
                ForEach(store.tasks(plan, day.date)) { row in
                    CheckRow(checked: Binding(get: { row.done },
                                              set: { _ in store.toggleTask(plan, day.date, row) }),
                             text: row.text, review: false, onTap: onOpen)
                }
            }
        }
    }
}

// MARK: - 今天要做（单独一页，只显示今天要做的，不带书架）

struct TodayAllView: View {
    @EnvironmentObject var store: PlanStore
    let onBack: () -> Void
    let onOpen: (Plan) -> Void

    var body: some View {
        let items = TodaySummaryView.items(store)
        let total = items.reduce(0) { n, i in n + 1 + (i.day.leetcode.isEmpty ? 0 : 1) + store.tasks(i.plan, i.day.date).count }
        let done = items.reduce(0) { n, i in
            let p = store.progress(i.plan, i.day.date)
            return n + (p.learn ? 1 : 0) + (!i.day.leetcode.isEmpty && p.leetcode ? 1 : 0)
                + store.tasks(i.plan, i.day.date).filter(\.done).count
        }
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Button(action: onBack) { Label("书架", systemImage: "chevron.left") }
                    Spacer()
                    Menu { AppMenuItems() } label: { Image(systemName: "gearshape") }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    PinButton()
                }
                .buttonStyle(.borderless)
                Text("今天要做").font(.title3.bold())
                HStack {
                    Text(DateUtil.display(store.today))
                    Spacer()
                    if total > 0 { Text("已完成 \(done) / \(total) 项") }
                }
                .font(.caption).foregroundStyle(.secondary)
                if total > 0 {
                    ProgressView(value: Double(done), total: Double(total))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    StudyTimerView()
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Text("今天没有在学的书").foregroundStyle(.secondary)
                            Button("回书架", action: onBack)
                        }
                        .padding(.top, 30)
                    }
                    ForEach(items) { item in
                        TodaySummaryView.BookToday(plan: item.plan, day: item.day, onOpen: { onOpen(item.plan) })
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(12)
            }
        }
    }
}
