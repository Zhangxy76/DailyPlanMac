import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 第 1 步：粘贴 / 导入

struct ImportView: View {
    @EnvironmentObject var store: PlanStore
    let close: () -> Void

    @State private var name = ""
    @State private var text = ""
    @State private var useCustomStart = false
    @State private var start = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("把计划文字粘贴进来，或者导入一个 .md / .txt 文件").font(.headline)
            Text("支持：`Day 1 · 11/21：变量、数据类型、内存`、`11/21：学什么……`、或者一行一条任务。解析不出来的地方会标出来让你改，不会自己编。")
                .font(.caption).foregroundStyle(.secondary)

            AIPromptBox()

            HStack {
                TextField("计划名字，比如 AI 30 天计划", text: $name).textFieldStyle(.roundedBorder)
                Button("导入文件…", action: pickFile)
            }
            HStack {
                Toggle("自己指定开始日期", isOn: $useCustomStart)
                if useCustomStart {
                    DatePicker("", selection: $start, displayedComponents: .date).labelsHidden()
                } else {
                    Text("（不勾就用文字里的日期，没写日期就从今天开始）").font(.caption).foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Text("\(text.count) 字").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("取消", action: close)
                Button("生成计划", action: generate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 440)
    }

    private func pickFile() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        p.allowsMultipleSelection = false
        p.level = .floating
        guard p.runModal() == .OK, let url = p.url,
              let s = try? String(contentsOf: url, encoding: .utf8) else { return }
        text = s
        if name.isEmpty {
            // 用文件里第一个一级标题当名字，没有就用文件名
            let h1 = s.components(separatedBy: .newlines).first { $0.hasPrefix("# ") }
            name = h1.map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
                ?? url.deletingPathExtension().lastPathComponent
        }
    }

    private func generate() {
        let n = name.trimmingCharacters(in: .whitespaces)
        var r = PlanParser.parse(text, name: n.isEmpty ? "新计划" : n,
                                 startDate: useCustomStart ? DateUtil.string(start) : nil)
        // 没填名字的话，用文字里 “书名：xxx” 那一行
        if n.isEmpty, let d = r.detectedName, !d.isEmpty { r.plan.name = d }
        close()
        PlanActions.openEditor(r.plan, isNew: true, warnings: r.warnings)
    }
}

// MARK: - 第 2、3 步：看生成结果 + 微调

struct PlanEditor: View {
    @EnvironmentObject var store: PlanStore
    @State var draft: Plan
    let isNew: Bool
    let warnings: [String]
    let close: () -> Void
    @State private var selection: PlanDay.ID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("计划名字", text: $draft.name).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Text("共 \(draft.days.count) 天 · \(DateUtil.short(draft.days.first?.date ?? draft.startDate)) – \(DateUtil.short(draft.endDate))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(warnings, id: \.self) { Text("⚠︎ \($0)").font(.caption) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.yellow.opacity(0.15))
            }

            HSplitView {
                // 左：天列表，可拖动换顺序
                VStack(spacing: 0) {
                    List(selection: $selection) {
                        ForEach(draft.days) { d in
                            HStack(spacing: 6) {
                                Text("Day \(d.day)").font(.caption.monospacedDigit()).frame(width: 44, alignment: .leading)
                                Text(DateUtil.short(d.date)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Text(d.learnTopic).lineLimit(1)
                                if !d.needsReview.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).font(.caption)
                                }
                            }
                            .tag(d.id)
                        }
                        .onMove(perform: move)
                    }
                    HStack {
                        Button { addDay() } label: { Image(systemName: "plus") }.help("在选中的那天后面加一天")
                        Button { deleteSelected() } label: { Image(systemName: "minus") }
                            .disabled(selection == nil).help("删掉选中的那天")
                        Spacer()
                        Text("拖动可换顺序").font(.caption2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .padding(6)
                }
                .frame(minWidth: 240, idealWidth: 280)

                // 右：编辑选中的那天
                Group {
                    if let id = selection, let i = draft.days.firstIndex(where: { $0.id == id }) {
                        DayEditor(day: $draft.days[i], onDateChange: { sortByDate() })
                    } else {
                        Text("在左边选一天来改").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 360)
            }

            Divider()
            HStack {
                if !isNew {
                    Button("恢复到导入时的版本…", action: restore)
                }
                Spacer()
                Button("取消", action: close)
                Button(isNew ? "放进书架" : "保存") { save() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear { selection = selection ?? draft.days.first(where: { !$0.needsReview.isEmpty })?.id ?? draft.days.first?.id }
    }

    /// 拖动换顺序：内容跟着走，Day 编号和日期按位置重新排
    private func move(from: IndexSet, to: Int) {
        let dates = draft.days.map(\.date)
        draft.days.move(fromOffsets: from, toOffset: to)
        for i in draft.days.indices {
            draft.days[i].day = i + 1
            draft.days[i].date = dates[i]
        }
    }

    private func renumber() {
        for i in draft.days.indices { draft.days[i].day = i + 1 }
        draft.startDate = draft.days.first?.date ?? draft.startDate
    }

    private func sortByDate() {
        draft.days.sort { $0.date < $1.date }
        renumber()
    }

    private func addDay() {
        let idx = selection.flatMap { id in draft.days.firstIndex { $0.id == id } } ?? (draft.days.count - 1)
        let date = idx >= 0 ? DateUtil.adding(days: 1, to: draft.days[idx].date) : DateUtil.today()
        let new = PlanDay(day: 0, date: date, learnTopic: "新的一天")
        // 后面的日期都顺延一天
        for i in draft.days.indices where i > idx { draft.days[i].date = DateUtil.adding(days: 1, to: draft.days[i].date) }
        draft.days.insert(new, at: idx + 1)
        renumber()
        selection = new.id
    }

    private func deleteSelected() {
        guard let id = selection, let i = draft.days.firstIndex(where: { $0.id == id }) else { return }
        draft.days.remove(at: i)
        renumber()
        selection = draft.days.indices.contains(i) ? draft.days[i].id : draft.days.last?.id
    }

    private func restore() {
        let a = NSAlert()
        a.messageText = "恢复到导入时的版本？"
        a.informativeText = "你对这个计划内容做的修改会被丢掉（打勾记录和自己写的备注不受影响）。点“保存”后才生效。"
        a.addButton(withTitle: "恢复")
        a.addButton(withTitle: "取消")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let name = draft.name
        draft = store.importedVersion(of: draft)
        draft.name = name
        selection = draft.days.first?.id
    }

    private func save() {
        // 已经确认过的天，去掉“待确认”标记只靠用户自己在编辑器里清，这里原样保存
        draft.startDate = draft.days.first?.date ?? draft.startDate
        if isNew { store.addPlan(draft) } else { store.updatePlan(draft) }
        close()
    }
}

struct DayEditor: View {
    @Binding var day: PlanDay
    let onDateChange: () -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Day \(day.day)").font(.headline)
                    Spacer()
                    DatePicker("日期", selection: Binding(
                        get: { DateUtil.date(day.date) ?? Date() },
                        set: { day.date = DateUtil.string($0); onDateChange() }),
                               displayedComponents: .date)
                }
                TextField("学什么（列表上显示的标题）", text: $day.learnTopic)
            }
            Section("备注") {
                field("学什么（详细）", $day.notes.learnDetail)
                field("要做什么", $day.notes.whatToDo)
                field("怎么做", $day.notes.howToDo)
                field("直接搜什么（一行一个）", lines($day.notes.searchPython))
                field("\(day.notes.logicTitle)（一行一个）", lines($day.notes.searchLogic))
                field("过关标准", $day.notes.passCriteria)
                field("复刻项目（选填）", $day.notes.project)
                field("练习 / 作业（选填）", $day.notes.practice)
                field("其他", $day.notes.extra)
            }
            Section("力扣") {
                TextField("题目，例如 1. Two Sum 两数之和", text: $day.leetcode.title)
                HStack {
                    TextField("难度", text: $day.leetcode.difficulty)
                    TextField("对应知识点", text: $day.leetcode.topic)
                }
                field("怎么做", $day.leetcode.note)
            }
            if !day.needsReview.isEmpty {
                Section("待确认") {
                    ForEach(day.needsReview, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                    Button("我改好了，去掉待确认标记") { day.needsReview = [] }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func field(_ title: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: b, axis: .vertical).labelsHidden().lineLimit(1...6)
        }
    }

    private func lines(_ b: Binding<[String]>) -> Binding<String> {
        Binding(get: { b.wrappedValue.joined(separator: "\n") },
                set: { b.wrappedValue = $0.components(separatedBy: "\n") })
    }
}

// MARK: - 用 AI 生成计划：可复制的提示词（来自《导入用AI提示词模板》）

struct AIPromptBox: View {
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("还没有计划？让 AI 帮你生成").font(.callout.bold())
                    Text("复制提示词发给 AI（Claude / ChatGPT 都行），不用改。AI 会一个一个问你问题，问完生成全文，把全文粘贴到下面")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(copied ? "已复制 ✓" : "复制提示词") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.prompt, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                Button(expanded ? "收起" : "看一眼") { expanded.toggle() }
                    .buttonStyle(.borderless)
            }
            if expanded {
                ScrollView {
                    Text(Self.prompt)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 160)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    static let prompt = """
    你现在是我的学习规划师，帮我做一本可以直接导入每日计划 App 的计划书。

    规则：
    - 你要一步一步问我，一次只问一个问题，等我回答了再问下一个，不要一次把所有问题都抛出来，也不要直接生成计划
    - 问的时候用大白话，不要用专业术语，每个问题给 2-3 个例子，方便我选；我也可以说“不知道”“随便”“跳过”，你就按最常见的帮我定
    - 问完所有问题后，先把我的情况总结成 5 行给我确认，我说“可以”你再生成，不要直接生成
    - 生成的时候必须严格按下面的导入格式写，不要加多余的介绍、总结、表格

    你要问我的问题，按这个顺序问：
    1. 你想学什么？最后想达到什么效果？比如：想练口语能开口说、想 30 天学会 AI 基础做出一个小项目、想读完一本书、想健身减 5 斤
    2. 你打算学多少天？从哪天开始？比如：30 天，从 2026-12-21 开始；不知道就说不知道，我帮你定 30 天，从明天开始
    3. 你每天能投入多久？周末呢？比如：每天 1 小时，周末 2 小时；每天 2.5 小时，周末 3 小时
    4. 你现在是什么水平？比如：完全不会、有点基础、会一点但不熟
    5. 你最后想做出什么、能做到什么？比如：能做 5 分钟自我介绍、能做出一个小项目、能跑 5 公里；没有就说没有
    6. 有没有特别不想做的，或者特别喜欢的方式？比如：不想刷题、不想看视频、喜欢动手做、喜欢每天背一点

    生成格式，必须严格按这个格式写：
    - 开头只写一行：书名：[计划书的名字]
    - 然后按天写，Day 1 到 Day [天数]，一天一个块，块和块之间空一行
    - 每个块的第一行必须是：Day X · YYYY-MM-DD（周X）：[当天学什么，一句话]
    - 每个块下面固定 5 行，顺序不要变，标签不要改，所有计划都用这 5 行：
      学什么：[当天核心知识点，一句话]
      直接搜什么：[中文搜索词] / [英文搜索词]
      背景原理搜什么：[当天要理解的背景 / 原理 / 规则 + 搜索词]
      动手做什么：[当天具体动手任务，能做完、可检查]
      过关标准：[做完怎么算过关，一句话，能自己检查]
    - 下面这 3 行是选填，只有对得上的计划才写，对不上就不要写，不要硬凑：
      力扣：[只有编程计划才写，题号. 英文题名 中文题名]
      复刻项目：[只有做项目的计划才写，项目名 + 做到哪一步：跑通 / 重写 / 改需求 / 讲清原理]
      练习 / 作业：[只有需要刷题、背诵、练习的计划才写，写清楚做什么、做多少]
    - 不要编假的链接、假的书名、假的数据；不确定的就写“待确认”，不要编
    - 每天的任务量要和我每天能投入的时间匹配，不要一天排 5 小时的活
    - 最后一天写验收：列出 10 项验收清单，8 项通过算过关

    现在开始问我第 1 个问题。
    """
}
