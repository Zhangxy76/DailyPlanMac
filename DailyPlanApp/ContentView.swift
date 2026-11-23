import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 页面：书架 → 某本书的今天页 → 总览 → 某一天
enum Page: Equatable {
    case shelf
    case todayAll           // 只显示今天要做的（所有在学的书），不带书架
    case today
    case overview
    case wrongBook
    case day(UUID)
}

struct ContentView: View {
    @EnvironmentObject var store: PlanStore
    @EnvironmentObject var settings: WindowSettings
    @State private var page: Page = ContentView.initialPage

    /// 打开 App 先看到书架（调试截图时可以用 -snapshotPage today / overview 直接进书）
    static var initialPage: Page {
        switch UserDefaults.standard.string(forKey: "snapshotPage") {
        case "today": return .today
        case "overview": return .overview
        case "wrongBook": return .wrongBook
        case "todayAll": return .todayAll
        default: return .shelf
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if page == .todayAll {
                TodayAllView(onBack: { page = .shelf }) { plan in
                    store.currentPlanID = plan.id
                    page = .today
                }
            } else if page == .shelf || store.currentPlan == nil {
                ShelfView(onOpen: { plan in
                    store.currentPlanID = plan.id
                    page = .today
                }, onOpenToday: { page = .todayAll })
            } else if let plan = store.currentPlan {
                BookPages(plan: plan, page: $page, standalone: false)
            }
        }
        .padding(.top, 4)
        .background {
            Button("") { NSApp.terminate(nil) }.keyboardShortcut("q").hidden()
        }
        .frame(minWidth: 300, minHeight: 360)
        .background(.regularMaterial)
        .onChange(of: store.plans.map(\.id)) { _, ids in
            // 当前这本书被删了 → 回书架
            if let id = store.currentPlanID, !ids.contains(id) { page = .shelf }
        }
    }
}

/// 一本书里的页面：今天 / 总览 / 错题本 / 某一天。主窗口和“单独窗口”共用
struct BookPages: View {
    let plan: Plan
    @Binding var page: Page
    let standalone: Bool          // true = 单独弹出的窗口，固定显示这本书，没有“书架”按钮

    var body: some View {
        VStack(spacing: 0) {
            BookHeader(plan: plan, page: $page, standalone: standalone)
            Divider()
            Group {
                switch page {
                case .today, .shelf, .todayAll:
                    TodayView(plan: plan)
                case .overview:
                    OverviewView(plan: plan, onOpenWrongBook: { page = .wrongBook }) { page = .day($0.id) }
                case .wrongBook:
                    WrongBookView(plan: plan)
                case .day(let id):
                    if let day = plan.days.first(where: { $0.id == id }) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Day \(day.day) · \(DateUtil.display(day.date))")
                                    .font(.subheadline.bold())
                                DayDetail(plan: plan, day: day)
                            }
                            .padding(12)
                        }
                    } else {
                        OverviewView(plan: plan, onOpenWrongBook: { page = .wrongBook }) { page = .day($0.id) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// 单独弹出的窗口：固定显示一本书
struct BookWindowView: View {
    @EnvironmentObject var store: PlanStore
    let planID: UUID
    @State private var page: Page = .today

    var body: some View {
        Group {
            if let plan = store.plans.first(where: { $0.id == planID }) {
                BookPages(plan: plan, page: $page, standalone: true)
            } else {
                Text("这本书已经删除了").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 4)
        .frame(minWidth: 300, minHeight: 360)
        .background(.regularMaterial)
    }
}

struct PinButton: View {
    @EnvironmentObject var settings: WindowSettings
    var body: some View {
        Toggle(isOn: $settings.pinned) {
            Image(systemName: settings.pinned ? "pin.fill" : "pin.slash")
        }
        .toggleStyle(.button)
        .disabled(settings.desktopMode)
        .help(settings.desktopMode ? "桌面模式下不能钉住，右键菜单栏图标关掉桌面模式"
              : settings.pinned ? "已钉住：一直在最前面。点一下取消钉住" : "未钉住：普通窗口。点一下钉住")
    }
}

// MARK: - 书里的顶部：< 书架 + 书名 + Day X / N · 日期 + 进度 + 钉住

struct BookHeader: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    @Binding var page: Page
    var standalone = false
    @State private var addingTask = false

    /// “+”加到哪一天：看某一天时加到那天，其他页面加到今天这一天
    private var taskDate: String? {
        if case .day(let id) = page { return plan.days.first { $0.id == id }?.date }
        return store.state(for: plan).day?.date
    }

    var body: some View {
        let state = store.state(for: plan)
        let done = store.completedCount(plan)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                switch page {
                case .day, .wrongBook:
                    Button { page = .overview } label: { Label("总览", systemImage: "chevron.left") }
                case .overview:
                    Button { page = .today } label: { Label("今天", systemImage: "chevron.left") }
                default:
                    if standalone {
                        Label("单独窗口", systemImage: "macwindow").foregroundStyle(.secondary)
                            .help("这个窗口固定显示这一本书；关掉它不影响主窗口")
                    } else {
                        Button { page = .shelf } label: { Label("书架", systemImage: "chevron.left") }
                    }
                }
                Spacer()
                if page == .today {
                    Button { page = .overview } label: { Label("总览", systemImage: "list.bullet") }
                        .help("看全部 \(plan.days.count) 天")
                }
                Menu {
                    if standalone {
                        Button("关闭这个窗口") { AppDelegate.shared.closeBookWindow(plan.id) }
                    } else {
                        Button("在新窗口打开") { AppDelegate.shared.openBookWindow(plan.id) }
                    }
                    Divider()
                    Button("编辑这本书…") { PlanActions.openEditor(plan) }
                    Button("导出打勾记录（Markdown）…") { PlanActions.export(plan) }
                    Toggle("保底 1.5 小时版（打卡按 1.5 小时计）", isOn: Binding(
                        get: { store.book(plan).hoursPerDay < 2 },
                        set: { store.setHoursPerDay(plan, $0 ? 1.5 : 2.5) }))
                    Divider()
                    Button(plan.archived ? "取消归档" : "归档") { store.setArchived(plan.id, !plan.archived) }
                    Button("删除这本书…", role: .destructive) { PlanActions.confirmDelete(plan) }
                    Divider()
                    AppMenuItems()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                PinButton()
            }
            .buttonStyle(.borderless)

            Text(plan.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(title(state)).font(.headline)

            ProgressView(value: Double(done), total: Double(max(plan.days.count, 1)))
            HStack(spacing: 6) {
                Text("已完成 \(done) / \(plan.days.count) 天").foregroundStyle(.secondary)
                Spacer()
                StreakLabel(plan: plan)
                if let date = taskDate {
                    Button { addingTask = true } label: {
                        Image(systemName: "plus.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help(date == store.today ? "加一个今天的任务" : "给 \(DateUtil.short(date)) 加一个任务")
                    .sheet(isPresented: $addingTask) {
                        TaskEditor(plan: plan, date: date, row: nil, scope: .future) { addingTask = false }
                    }
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func title(_ s: TodayState) -> String {
        let n = plan.days.count
        switch s {
        case .notStarted(let d): return "还没开始，Day \(d.day) 是 \(DateUtil.short(d.date))"
        case .active(let d): return "Day \(d.day) / \(n) · \(DateUtil.display(store.today))"
        case .finished(let d): return "已完成，Day \(d.day) 验收清单"
        case .empty: return "这本书里还没有任何一天"
        }
    }
}

// MARK: - 今天页

struct TodayView: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    @State private var catchUp: PlanDay?

    var body: some View {
        let state = store.state(for: plan)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if case .active(let today) = state, let y = store.dayBefore(today, in: plan),
                   !store.isComplete(plan, y), !store.progress(plan, y.date).skipped {
                    MissedBanner(plan: plan, yesterday: y) { catchUp = y }
                }
                if case .finished = state {
                    Text("计划已结束：一共完成 \(store.completedCount(plan)) / \(plan.days.count) 天")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let day = state.day {
                    DayDetail(plan: plan, day: day)
                    StudyTimerView()
                    DueList(plan: plan, day: day)
                    if case .active = state, let t = store.dayAfter(day, in: plan) {
                        Divider()
                        Text("明天 Day \(t.day)：\(t.learnTopic)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(12)
        }
        .sheet(item: $catchUp) { y in
            VStack(alignment: .leading) {
                HStack {
                    Text("补 Day \(y.day) · \(DateUtil.display(y.date))").font(.headline)
                    Spacer()
                    Button("完成") { catchUp = nil }.keyboardShortcut(.defaultAction)
                }
                ScrollView { DayDetail(plan: plan, day: y) }
            }
            .padding()
            .frame(width: 340, height: 420)
        }
    }
}

struct MissedBanner: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let yesterday: PlanDay
    let onCatchUp: () -> Void

    var body: some View {
        HStack {
            Text("昨天 Day \(yesterday.day) 没完成，要补吗？").font(.caption)
            Spacer()
            Button("补", action: onCatchUp).controlSize(.small)
            Button("跳过") { store.binding(plan, yesterday.date, \.skipped).wrappedValue = true }
                .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// 一天的内容：只有“学什么”和力扣两行，点一下才弹出备注
struct DayDetail: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let day: PlanDay
    @State private var showLearn = false
    @State private var showLeet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CheckRow(checked: store.binding(plan, day.date, \.learn),
                     text: "学什么：\(day.learnTopic)",
                     review: !day.needsReview.isEmpty) { showLearn = true }
                .popover(isPresented: $showLearn, arrowEdge: .leading) {
                    NoteCard(plan: plan, day: day)
                }

            if !day.leetcode.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CheckRow(checked: store.binding(plan, day.date, \.leetcode),
                             text: "力扣：\(day.leetcode.title)", review: false) { showLeet = true }
                        .popover(isPresented: $showLeet, arrowEdge: .leading) {
                            LeetCard(plan: plan, day: day)
                        }
                    if !day.leetcode.title.contains("重做") {
                        if store.isWrong(plan, day) {
                            // 点错了可以原地撤回
                            Button {
                                store.removeWrong(plan, PlanStore.leetKey(day.leetcode))
                            } label: {
                                Label("在错题本", systemImage: "xmark.circle.fill")
                                    .labelStyle(.titleAndIcon)
                            }
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .buttonStyle(.borderless)
                            .help("点一下移出错题本（误点了就点这里撤回）。不移出的话，3 天后会出现在今天页底部让你重做")
                        } else {
                            Button("难 / 错了") { store.addWrong(plan, day) }
                                .font(.caption2)
                                .buttonStyle(.borderless)
                                .help("这道题进错题本，3 天后再重做")
                        }
                    }
                }
            }

            TaskSection(plan: plan, date: day.date)

            VStack(alignment: .leading, spacing: 4) {
                Text("今天最重要的一件事").font(.caption).foregroundStyle(.secondary)
                TextField("早上写一句…", text: store.binding(plan, day.date, \.mostImportant), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }
        }
    }
}

struct CheckRow: View {
    @Binding var checked: Bool
    let text: String
    let review: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button { checked.toggle() } label: {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(checked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                HStack {
                    Text(text)
                        .strikethrough(checked, color: .secondary)
                        .foregroundStyle(checked ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    if review {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            .help("这天有待确认的地方，去“编辑当前计划”里改")
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 备注卡片

struct NoteCard: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let day: PlanDay

    var body: some View {
        let n = day.notes
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Day \(day.day) · \(DateUtil.display(day.date))").font(.caption).foregroundStyle(.secondary)
                Text("学什么：\(day.learnTopic)").font(.headline)
                if !n.learnDetail.isEmpty && n.learnDetail != day.learnTopic {
                    Text(n.learnDetail).font(.callout)
                }

                // 没写的项直接不显示
                if !n.whatToDo.isEmpty { Section2("要做什么") { Body2(n.whatToDo) } }
                if !n.howToDo.isEmpty { Section2("怎么做") { Body2(n.howToDo) } }
                if !n.practice.isEmpty { Section2("练习 / 作业") { Body2(n.practice) } }
                if !n.project.isEmpty { Section2("复刻项目") { Body2(n.project) } }
                if !n.searchPython.isEmpty || !n.searchLogic.isEmpty || !n.passCriteria.isEmpty || !n.extra.isEmpty {
                Section2("其他") {
                    VStack(alignment: .leading, spacing: 6) {
                        if !n.searchPython.isEmpty { CopyList(label: "直接搜什么", terms: n.searchPython) }
                        if !n.searchLogic.isEmpty { CopyList(label: n.logicTitle, terms: n.searchLogic) }
                        if !n.passCriteria.isEmpty {
                            Text("过关标准").font(.caption).foregroundStyle(.secondary)
                            Text(n.passCriteria).font(.callout)
                        }
                        if !n.extra.isEmpty { Text(n.extra).font(.callout).foregroundStyle(.secondary) }
                    }
                }
                }
                if !day.needsReview.isEmpty {
                    Section2("待确认") {
                        ForEach(day.needsReview, id: \.self) { Text("· \($0)").font(.caption).foregroundStyle(.orange) }
                    }
                }
                Section2("我的备注") {
                    TextEditor(text: store.binding(plan, day.date, \.myNote))
                        .font(.callout)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(14)
            .textSelection(.enabled)
        }
        .frame(width: 340, height: 460)
    }
}

struct LeetCard: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let day: PlanDay

    var body: some View {
        let l = day.leetcode
        VStack(alignment: .leading, spacing: 10) {
            Text("力扣：\(l.title)").font(.headline)
            if !l.difficulty.isEmpty || !l.topic.isEmpty {
                Text([l.difficulty, l.topic.isEmpty ? "" : "对应：\(l.topic)"].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !l.note.isEmpty { Section2("怎么做") { Body2(l.note) } }
            CopyList(label: "搜索词", terms: [l.searchTerm])
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .textSelection(.enabled)
    }
}

struct Section2<C: View>: View {
    let title: String
    @ViewBuilder let content: C
    init(_ title: String, @ViewBuilder content: () -> C) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            content
        }
    }
}

struct Body2: View {
    let text: String
    var placeholder = "（待确认）"
    init(_ text: String, placeholder: String = "（待确认）") { self.text = text; self.placeholder = placeholder }
    var body: some View {
        if text.isEmpty {
            Text(placeholder).font(.callout).foregroundStyle(.tertiary)
        } else {
            Text(text).font(.callout)
        }
    }
}

struct CopyList: View {
    let label: String
    let terms: [String]
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            ForEach(terms.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }, id: \.self) { t in
                HStack(spacing: 6) {
                    Text(t).font(.callout.monospaced())
                    Spacer(minLength: 4)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(t, forType: .string)
                        copied = t
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { if copied == t { copied = nil } }
                    } label: {
                        Image(systemName: copied == t ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("复制")
                }
            }
        }
    }
}

// MARK: - 总览

struct OverviewView: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    var onOpenWrongBook: () -> Void = {}
    let onOpen: (PlanDay) -> Void

    var body: some View {
        let todayID = store.state(for: plan).day?.id
        let wrong = store.book(plan).wrongLeetcode.count
        ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    CheckinCalendar(plan: plan, onOpen: onOpen)

                    Button(action: onOpenWrongBook) {
                        HStack {
                            Image(systemName: "book.closed")
                            Text("错题本（\(wrong) 道）")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .contentShape(Rectangle())
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(plan.days) { d in
                            Button { onOpen(d) } label: {
                                HStack(spacing: 8) {
                                    Text("Day \(d.day)").font(.caption.monospacedDigit()).frame(width: 46, alignment: .leading)
                                    Text(DateUtil.short(d.date)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(d.learnTopic).lineLimit(1)
                                    if !d.needsReview.isEmpty {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).font(.caption)
                                    }
                                    Spacer(minLength: 4)
                                    Text(store.isComplete(plan, d) ? "✓" : "○")
                                        .foregroundStyle(store.isComplete(plan, d) ? Color.green : .secondary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .fontWeight(d.id == todayID ? .semibold : .regular)
                            }
                            .buttonStyle(.plain)
                            .id(d.id)
                            Divider()
                        }
                    }
                }
                .padding(12)
        }
    }
}

// MARK: - 菜单动作

enum PlanActions {
    static func openImport() {
        AppDelegate.shared.openWindow(title: "新书：导入计划", size: NSSize(width: 620, height: 560)) { close in
            ImportView(close: close)
        }
    }

    static func openEditor(_ plan: Plan, isNew: Bool = false, warnings: [String] = []) {
        AppDelegate.shared.openWindow(title: isNew ? "检查生成的新书" : "编辑：\(plan.name)",
                                      size: NSSize(width: 760, height: 640)) { close in
            PlanEditor(draft: plan, isNew: isNew, warnings: warnings, close: close)
        }
    }

    static func export(_ plan: Plan) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "\(plan.name)-打勾记录-\(DateUtil.today()).md"
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? PlanStore.shared.exportMarkdown(plan).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func confirmDelete(_ plan: Plan) {
        let a = NSAlert()
        a.messageText = "删除《\(plan.name)》？"
        a.informativeText = "这本书和它的打勾记录、备注都会删掉，不能恢复。只是暂时不学的话，可以用“归档”。"
        a.addButton(withTitle: "删除")
        a.addButton(withTitle: "取消")
        a.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn { PlanStore.shared.deletePlan(plan.id) }
    }
}
