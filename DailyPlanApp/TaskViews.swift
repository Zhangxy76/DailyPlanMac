import SwiftUI

/// 今天页列表下面：临时任务 / 重复任务的行（“+”在顶部“已完成”那一行右边）
struct TaskSection: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let date: String

    @State private var editing: EditRequest?
    @State private var askScope: PendingAction?

    struct EditRequest: Identifiable {
        let id = UUID()
        var row: TaskRow?            // nil = 新加
        var scope: TaskScope = .future
    }

    struct PendingAction: Identifiable {
        enum Kind { case edit, delete }
        let id = UUID()
        var kind: Kind
        var row: TaskRow
    }

    var body: some View {
        let rows = store.tasks(plan, date)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows) { row in
                TaskRowView(row: row,
                            onToggle: { store.toggleTask(plan, date, row) },
                            onEdit: { request(.edit, row) },
                            onDelete: { request(.delete, row) })
            }
        }
        .sheet(item: $editing) { req in
            TaskEditor(plan: plan, date: date, row: req.row, scope: req.scope) { editing = nil }
        }
        .confirmationDialog("只改今天这一次，还是以后都改？",
                            isPresented: Binding(get: { askScope != nil }, set: { if !$0 { askScope = nil } }),
                            presenting: askScope) { a in
            Button(a.kind == .delete ? "只删今天这一次" : "只改今天这一次") { run(a, .thisDay) }
            Button(a.kind == .delete ? "以后都删掉" : "以后都改", role: a.kind == .delete ? .destructive : nil) { run(a, .future) }
            Button("取消", role: .cancel) {}
        } message: { a in
            Text("“\(a.row.title)”是重复任务（\(a.row.rule?.frequency.summary ?? "")）。以前的日子不受影响。")
        }
    }

    /// 重复任务先问范围；临时任务直接改 / 删
    private func request(_ kind: PendingAction.Kind, _ row: TaskRow) {
        if row.rule != nil {
            askScope = PendingAction(kind: kind, row: row)
        } else if kind == .edit {
            editing = EditRequest(row: row, scope: .future)
        } else {
            store.deleteTask(plan, date, row, scope: .future)
        }
    }

    private func run(_ a: PendingAction, _ scope: TaskScope) {
        switch a.kind {
        case .edit: editing = EditRequest(row: a.row, scope: scope)
        case .delete: store.deleteTask(plan, date, a.row, scope: scope)
        }
    }
}

struct TaskRowView: View {
    let row: TaskRow
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: row.done ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(row.done ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Text(row.text)
                        .strikethrough(row.done, color: .secondary)
                        .foregroundStyle(row.done ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    if let r = row.rule {
                        Image(systemName: "repeat").font(.caption2).foregroundStyle(.secondary)
                            .help(r.frequency.summary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("点一下修改")

            Menu {
                Button("修改…", action: onEdit)
                Button("删除…", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

/// 输入框：任务名 + 时长 + 频率
struct TaskEditor: View {
    @EnvironmentObject var store: PlanStore
    let plan: Plan
    let date: String
    let row: TaskRow?
    let scope: TaskScope
    let close: () -> Void

    @State private var title = ""
    @State private var duration = ""
    @State private var freq = Frequency()
    @State private var hasEnd = false
    @State private var end = Date()

    /// “只改今天这一次”只能改名字和时长
    private var canChangeFrequency: Bool { !(row?.rule != nil && scope == .thisDay) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading).font(.headline)

            TextField("任务名，比如 口语练习", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("时长（可不填），比如 半小时", text: $duration)
                .textFieldStyle(.roundedBorder)

            if canChangeFrequency {
                Picker("频率", selection: $freq.type) {
                    ForEach(Frequency.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
                }

                switch freq.type {
                case .weekly:
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { d in
                            Toggle(Frequency.weekdayNames[d - 1], isOn: Binding(
                                get: { freq.weekdays.contains(d) },
                                set: { on in
                                    if on { freq.weekdays.append(d) } else { freq.weekdays.removeAll { $0 == d } }
                                    freq.weekdays.sort()
                                }))
                            .toggleStyle(.button)
                        }
                    }
                case .everyNDays:
                    Stepper("每隔 \(freq.everyN) 天出现一次", value: $freq.everyN, in: 2...30)
                default:
                    EmptyView()
                }

                if freq.type != .once {
                    HStack {
                        Toggle("设结束日期", isOn: $hasEnd)
                        if hasEnd {
                            DatePicker("", selection: $end, displayedComponents: .date).labelsHidden()
                        } else {
                            Text("不设就到这本书结束（\(DateUtil.short(plan.endDate))）")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("只改今天这一次：频率不变，以后还是原来的样子。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text("不会改原计划；打勾不影响打卡。").font(.caption).foregroundStyle(.secondary)

            HStack {
                if let row {
                    Text(row.rule.map { "现在：\($0.frequency.summary)" } ?? "现在：仅这一天")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                              || (freq.type == .weekly && freq.weekdays.isEmpty))
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear(perform: load)
    }

    private var heading: String {
        guard let row else { return date == store.today ? "加一个今天的任务" : "加一个 \(DateUtil.short(date)) 的任务" }
        if row.rule != nil { return scope == .thisDay ? "只改今天这一次" : "改这个重复任务（从今天起）" }
        return "修改任务"
    }

    private func load() {
        guard let row else {
            // 默认今天是周几就预选周几，方便选“每周几天”
            if let d = DateUtil.date(date) {
                let wd = DateUtil.calendar.component(.weekday, from: d)
                freq.weekdays = [wd == 1 ? 7 : wd - 1]
            }
            return
        }
        title = row.title
        duration = row.duration
        if let r = row.rule {
            freq = r.frequency
            if let e = r.frequency.endDate, let d = DateUtil.date(e) { hasEnd = true; end = d }
        }
    }

    private func save() {
        var t = title, d = duration
        if d.trimmingCharacters(in: .whitespaces).isEmpty {
            // 名字里直接写了“口语练习 半小时”，把时长拆出来
            (t, d) = DurationSplitter.split(t)
        }
        var f = freq
        f.endDate = (f.type != .once && hasEnd) ? DateUtil.string(end) : nil
        if let row {
            store.editTask(plan, date, row, scope: scope, title: t, duration: d, frequency: f)
        } else {
            store.addTask(plan, date, title: t, duration: d, frequency: f)
        }
        close()
    }
}
