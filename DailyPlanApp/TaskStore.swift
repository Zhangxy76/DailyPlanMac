import Foundation

/// 今天临时任务 + 重复任务。都只存在 progress.json，不改 plans.json 和原计划；打勾不影响打卡。
extension PlanStore {

    /// 这天要显示的任务：临时任务 + 按规则出现的重复任务（去掉“只删今天”的）
    func tasks(_ plan: Plan, _ date: String) -> [TaskRow] {
        let b = book(plan)
        let day = b.days[date] ?? DayProgress()
        var rows = day.extraTasks.map { TaskRow(id: $0.id, title: $0.title, duration: $0.duration, done: $0.done, rule: nil) }
        for r in b.recurringTasks where r.occurs(on: date, planEnd: plan.endDate) {
            let o = day.overrides[r.id]
            if o?.deleted == true { continue }
            rows.append(TaskRow(id: r.id, title: o?.title ?? r.title, duration: o?.duration ?? r.duration,
                                done: day.recurringDone.contains(r.id), rule: r))
        }
        return rows
    }

    func addTask(_ plan: Plan, _ date: String, title: String, duration: String, frequency: Frequency) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let d = duration.trimmingCharacters(in: .whitespaces)
        mutate(plan) { b in
            if frequency.type == .once {
                b.days[date, default: DayProgress()].extraTasks.append(ExtraTask(id: TaskID.make(), title: t, duration: d))
            } else {
                b.recurringTasks.append(RecurringTask(id: TaskID.make(), title: t, duration: d,
                                                      frequency: frequency, startDate: date))
            }
        }
    }

    func toggleTask(_ plan: Plan, _ date: String, _ row: TaskRow) {
        mutate(plan) { b in
            var day = b.days[date] ?? DayProgress()
            if row.rule != nil {
                if let i = day.recurringDone.firstIndex(of: row.id) { day.recurringDone.remove(at: i) }
                else { day.recurringDone.append(row.id) }
            } else if let i = day.extraTasks.firstIndex(where: { $0.id == row.id }) {
                day.extraTasks[i].done.toggle()
            }
            b.days[date] = day
        }
    }

    /// 改任务。
    /// - 临时任务：直接改；频率改成重复的话，变成一条从这天开始的规则
    /// - 重复任务 + 只改今天：只在这天记一条改动
    /// - 重复任务 + 以后都改：旧规则在前一天结束，从这天起换成新规则（以前的日子不受影响）
    func editTask(_ plan: Plan, _ date: String, _ row: TaskRow, scope: TaskScope,
                  title: String, duration: String, frequency: Frequency) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let d = duration.trimmingCharacters(in: .whitespaces)
        mutate(plan) { b in
            var day = b.days[date] ?? DayProgress()
            if let rule = row.rule {
                if scope == .thisDay {
                    day.overrides[rule.id] = TaskOverride(title: t, duration: d, deleted: false)
                } else {
                    let wasDone = day.recurringDone.contains(rule.id)
                    day.recurringDone.removeAll { $0 == rule.id }
                    day.overrides[rule.id] = nil
                    Self.endRule(&b, rule.id, before: date)
                    if frequency.type == .once {
                        day.extraTasks.append(ExtraTask(id: TaskID.make(), title: t, duration: d, done: wasDone))
                    } else {
                        let keepAnchor = rule.frequency.type == .everyNDays && frequency.type == .everyNDays
                            && rule.frequency.everyN == frequency.everyN
                        let new = RecurringTask(id: TaskID.make(), title: t, duration: d, frequency: frequency,
                                                startDate: date,
                                                anchorDate: keepAnchor ? (rule.anchorDate ?? rule.startDate) : nil)
                        b.recurringTasks.append(new)
                        if wasDone { day.recurringDone.append(new.id) }
                    }
                }
            } else if let i = day.extraTasks.firstIndex(where: { $0.id == row.id }) {
                if frequency.type == .once {
                    day.extraTasks[i].title = t
                    day.extraTasks[i].duration = d
                } else {
                    let wasDone = day.extraTasks[i].done
                    day.extraTasks.remove(at: i)
                    let new = RecurringTask(id: TaskID.make(), title: t, duration: d, frequency: frequency, startDate: date)
                    b.recurringTasks.append(new)
                    if wasDone { day.recurringDone.append(new.id) }
                }
            }
            b.days[date] = day
        }
    }

    /// 删任务：重复任务按 scope，只删这一天或者从这天起都不再出现
    func deleteTask(_ plan: Plan, _ date: String, _ row: TaskRow, scope: TaskScope) {
        mutate(plan) { b in
            var day = b.days[date] ?? DayProgress()
            if let rule = row.rule {
                if scope == .thisDay {
                    day.overrides[rule.id] = TaskOverride(deleted: true)
                } else {
                    day.recurringDone.removeAll { $0 == rule.id }
                    day.overrides[rule.id] = nil
                    Self.endRule(&b, rule.id, before: date)
                }
            } else {
                day.extraTasks.removeAll { $0.id == row.id }
            }
            b.days[date] = day
        }
    }

    /// 规则在 date 的前一天结束；如果规则就是从 date 开始的，整条删掉
    private static func endRule(_ b: inout BookProgress, _ id: String, before date: String) {
        guard let i = b.recurringTasks.firstIndex(where: { $0.id == id }) else { return }
        if b.recurringTasks[i].startDate >= date {
            b.recurringTasks.remove(at: i)
        } else {
            b.recurringTasks[i].frequency.endDate = DateUtil.adding(days: -1, to: date)
        }
    }
}
