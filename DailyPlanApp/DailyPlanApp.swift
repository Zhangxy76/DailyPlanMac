import SwiftUI

@main
struct DailyPlanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 只有一个常驻浮动窗口（在 AppDelegate 里建），这里不需要别的窗口
        Settings { EmptyView() }
    }
}
