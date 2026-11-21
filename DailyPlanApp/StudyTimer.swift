import SwiftUI
import AppKit
import UserNotifications

/// 2.5 小时计时：40 分钟学 + 30 分钟逻辑 + 60 分钟动手 + 20 分钟复盘，每段到点提醒
final class StudyTimer: ObservableObject {
    static let shared = StudyTimer()

    struct Phase { let name: String; let minutes: Int }
    let phases = [
        Phase(name: "学知识点", minutes: 40),
        Phase(name: "学计算机逻辑", minutes: 30),
        Phase(name: "动手（项目 + 力扣）", minutes: 60),
        Phase(name: "复盘", minutes: 20),
    ]

    @Published private(set) var index = 0
    @Published private(set) var remaining: TimeInterval = 40 * 60
    @Published private(set) var running = false
    @Published private(set) var started = false

    private var endDate: Date?
    private var ticker: Timer?

    private init() { remaining = TimeInterval(phases[0].minutes * 60) }

    var phase: Phase { phases[index] }
    var finished: Bool { started && index == phases.count - 1 && remaining <= 0 }

    func start() {
        if !started {
            started = true
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        guard !finished else { return }
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

    func reset() {
        pause()
        index = 0
        started = false
        remaining = TimeInterval(phases[0].minutes * 60)
    }

    func skip() { advance(notify: false) }

    private func tick() {
        guard running, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 { advance(notify: true) }
    }

    private func advance(notify: Bool) {
        let done = phase.name
        if index + 1 < phases.count {
            index += 1
            remaining = TimeInterval(phase.minutes * 60)
            if notify { remind("“\(done)”时间到", "下一段：\(phase.name) \(phase.minutes) 分钟") }
            if running { endDate = Date().addingTimeInterval(remaining) }
        } else {
            remaining = 0
            running = false
            ticker?.invalidate()
            if notify { remind("今天 2.5 小时完成", "记得打勾") }
        }
    }

    private func remind(_ title: String, _ body: String) {
        NSSound(named: "Glass")?.play()
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}

struct StudyTimerView: View {
    @ObservedObject var timer = StudyTimer.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer").foregroundStyle(.secondary)
            if timer.started {
                VStack(alignment: .leading, spacing: 1) {
                    Text(timer.finished ? "今天 2.5 小时完成" : "\(timer.index + 1)/\(timer.phases.count) \(timer.phase.name)")
                        .font(.caption)
                    if !timer.finished {
                        Text(format(timer.remaining)).font(.callout.monospacedDigit())
                    }
                }
            } else {
                Text("2.5 小时计时").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !timer.finished {
                Button(timer.running ? "暂停" : (timer.started ? "继续" : "开始")) {
                    timer.running ? timer.pause() : timer.start()
                }
                if timer.started {
                    Button { timer.skip() } label: { Image(systemName: "forward.end") }.help("跳到下一段")
                }
            }
            if timer.started {
                Button { timer.reset() } label: { Image(systemName: "arrow.counterclockwise") }.help("重来")
            }
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .help("40 分钟学 + 30 分钟逻辑 + 60 分钟动手 + 20 分钟复盘，每段到点提醒")
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
