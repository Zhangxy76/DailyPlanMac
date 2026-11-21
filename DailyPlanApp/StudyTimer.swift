import SwiftUI
import AppKit
import UserNotifications

/// 计时器：和任务、计划都不挂钩。几个常用时长一点就开始，也能自定义分钟数；到点响一声并弹通知
final class StudyTimer: ObservableObject {
    static let shared = StudyTimer()

    /// 常用时长（分钟）
    static let presets = [15, 25, 45, 60]

    @Published private(set) var total: TimeInterval = 0       // 这次一共多久
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var running = false
    @Published private(set) var finished = false

    /// 上次自定义的分钟数，下次打开自定义时默认填它
    @Published var customMinutes: Int {
        didSet { UserDefaults.standard.set(customMinutes, forKey: "timerCustomMinutes") }
    }

    private var endDate: Date?
    private var ticker: Timer?
    private var askedPermission = false

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "timerCustomMinutes")
        customMinutes = saved > 0 ? saved : 30
    }

    /// 有没有一个计时（在走或暂停着）
    var active: Bool { total > 0 && !finished }

    func start(minutes: Int) {
        if !askedPermission {
            askedPermission = true
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        total = TimeInterval(minutes * 60)
        remaining = total
        finished = false
        resume()
    }

    func resume() {
        guard remaining > 0 else { return }
        endDate = Date().addingTimeInterval(remaining)
        running = true
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func pause() {
        tick()
        running = false
        ticker?.invalidate()
        endDate = nil
    }

    /// 结束这次计时，回到选时长的样子
    func stop() {
        running = false
        ticker?.invalidate()
        endDate = nil
        total = 0
        remaining = 0
        finished = false
    }

    private func tick() {
        guard running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 {
            running = false
            finished = true
            ticker?.invalidate()
            remind()
        }
    }

    private func remind() {
        NSSound(named: "Glass")?.play()
        let c = UNMutableNotificationContent()
        c.title = "时间到"
        c.body = "\(Int(total / 60)) 分钟计时结束"
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}

struct StudyTimerView: View {
    @ObservedObject var timer = StudyTimer.shared
    @State private var showCustom = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer").foregroundStyle(timer.running ? Color.accentColor : .secondary)
            if timer.finished {
                Text("时间到（\(Int(timer.total / 60)) 分钟）").font(.caption)
                Spacer()
                Button("再来一次") { timer.start(minutes: Int(timer.total / 60)) }
                Button("好") { timer.stop() }
            } else if timer.active {
                Text(format(timer.remaining)).font(.callout.monospacedDigit())
                Text("/ \(Int(timer.total / 60)) 分钟").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(timer.running ? "暂停" : "继续") { timer.running ? timer.pause() : timer.resume() }
                Button { timer.stop() } label: { Image(systemName: "xmark") }.help("结束这次计时")
            } else {
                Text("计时").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                ForEach(StudyTimer.presets, id: \.self) { m in
                    Button("\(m)") { timer.start(minutes: m) }
                        .help("计时 \(m) 分钟")
                }
                Text("分钟").font(.caption2).foregroundStyle(.secondary)
                Button("自定义") { showCustom = true }
                    .popover(isPresented: $showCustom, arrowEdge: .bottom) { CustomTimerForm { showCustom = false } }
            }
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .help("和任务不挂钩：点一个时长就开始，到点响一声并弹通知")
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
                         : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// 自定义时长：输入分钟数
struct CustomTimerForm: View {
    @ObservedObject var timer = StudyTimer.shared
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义计时").font(.headline)
            HStack {
                TextField("分钟", value: $timer.customMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Stepper("分钟", value: $timer.customMinutes, in: 1...600, step: 5)
            }
            HStack {
                Spacer()
                Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("开始") {
                    timer.customMinutes = min(max(timer.customMinutes, 1), 600)
                    timer.start(minutes: timer.customMinutes)
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
