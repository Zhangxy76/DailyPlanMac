import AppKit
import SwiftUI
import ServiceManagement
import Combine

/// 窗口模式
enum WindowMode: String {
    case pinned    // 钉住：一直在最前面（.floating）
    case normal    // 取消钉住：普通窗口，点别的 App 会藏到后面
    case desktop   // 桌面模式：贴在桌面背景上，被别的窗口盖住
}

final class WindowSettings: ObservableObject {
    static let shared = WindowSettings()

    @Published var pinned: Bool {
        didSet { UserDefaults.standard.set(pinned, forKey: "pinned"); changed.send() }
    }
    @Published var desktopMode: Bool {
        didSet { UserDefaults.standard.set(desktopMode, forKey: "desktopMode"); changed.send() }
    }
    /// 在程序坞显示图标（默认显示；关掉就只在菜单栏，像小组件一样）
    /// 书架顶部显示“今天要做”汇总（所有在学的书的今天）
    @Published var showTodaySummary: Bool {
        didSet { UserDefaults.standard.set(showTodaySummary, forKey: "showTodaySummary") }
    }
    @Published var showInDock: Bool {
        didSet { UserDefaults.standard.set(showInDock, forKey: "showInDock"); dockChanged.send() }
    }
    let changed = PassthroughSubject<Void, Never>()
    let dockChanged = PassthroughSubject<Void, Never>()

    var mode: WindowMode { desktopMode ? .desktop : (pinned ? .pinned : .normal) }

    private init() {
        UserDefaults.standard.register(defaults: ["pinned": true, "desktopMode": false, "showInDock": true,
                                                  "showTodaySummary": true])
        showTodaySummary = UserDefaults.standard.bool(forKey: "showTodaySummary")
        pinned = UserDefaults.standard.bool(forKey: "pinned")
        showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        desktopMode = UserDefaults.standard.bool(forKey: "desktopMode")
    }
}

/// 开机启动（macOS 13+ 的 SMAppService）
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("DailyPlan 开机启动设置失败：\(error.localizedDescription)")
        }
    }
}

/// 能接收键盘输入的浮动面板
final class PlanPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    var panel: PlanPanel!
    private var statusItem: NSStatusItem!
    private var bag = Set<AnyCancellable>()
    private var extraWindows: [NSWindow] = []
    /// 单独弹出的书窗口：书 id → 窗口
    private var bookPanels: [UUID: PlanPanel] = [:]
    private var allPanels: [PlanPanel] { [panel].compactMap { $0 } + bookPanels.values }
    private var dayTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        applyDock(show: false)
        makePanel()
        makeStatusItem()
        restoreBookWindows()

        // 书被删了 → 关掉它的单独窗口
        PlanStore.shared.$plans
            .receive(on: RunLoop.main)
            .sink { [weak self] plans in
                let ids = Set(plans.map(\.id))
                for id in self?.bookPanels.keys.filter({ !ids.contains($0) }) ?? [] { self?.closeBookWindow(id) }
            }
            .store(in: &bag)

        WindowSettings.shared.changed
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyMode() }
            .store(in: &bag)
        WindowSettings.shared.dockChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyDock(show: true) }
            .store(in: &bag)

        // 默认开机启动；每次启动都按当前 App 位置重新登记（挪到“应用程序”后也能跟着走）
        if !UserDefaults.standard.bool(forKey: "loginItemUserDisabled") {
            LoginItem.set(true)
        }

        // 过了零点自动换到新的一天
        dayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            PlanStore.shared.refreshToday()
        }
        #if DEBUG
        // 调试用：-snapshot /path.png [-snapshotTab 1] 把窗口存成图片后退出
        if let path = UserDefaults.standard.string(forKey: "snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let v = self?.panel.contentView,
                      let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                // 单独的书窗口存成 path-book1.png …
                for (i, p) in (self?.bookPanels.values.map { $0 } ?? []).enumerated() {
                    guard let bv = p.contentView, let r = bv.bitmapImageRepForCachingDisplay(in: bv.bounds) else { continue }
                    bv.cacheDisplay(in: bv.bounds, to: r)
                    try? r.representation(using: .png, properties: [:])?
                        .write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-book\(i + 1).png")))
                }
                NSApp.terminate(nil)
            }
        }
        #endif
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            PlanStore.shared.refreshToday()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    // MARK: - 浮动窗口

    private func makePanel() {
        panel = makeFloatingPanel(title: "每日计划", autosave: "DailyPlanPanel", offset: 0,
                                  root: ContentView())
        applyMode()
        panel.orderFrontRegardless()
    }

    /// 浮动窗口的公共做法：主窗口和每本书的单独窗口都用它
    private func makeFloatingPanel<V: View>(title: String, autosave: String, offset: CGFloat, root: V) -> PlanPanel {
        let size = NSSize(width: 360, height: 520)
        let p = PlanPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        p.title = title
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false          // 切到别的 App 时不藏起来
        p.isReleasedWhenClosed = false
        p.minSize = NSSize(width: 300, height: 360)
        p.delegate = self
        p.contentView = NSHostingView(
            rootView: root
                .environmentObject(PlanStore.shared)
                .environmentObject(WindowSettings.shared))

        // 位置：记住用户拖到的位置；第一次默认放右上角（单独窗口往左错开，不叠在主窗口上）
        if !p.setFrameUsingName(autosave) {
            if let screen = NSScreen.main {
                let v = screen.visibleFrame
                p.setFrameOrigin(NSPoint(x: v.maxX - size.width - 16 - offset, y: v.maxY - size.height - 16))
            }
        }
        p.setFrameAutosaveName(autosave)
        return p
    }

    // MARK: - 每本书单独一个窗口

    private static let openBooksKey = "openBookWindows"

    func openBookWindow(_ id: UUID) {
        if let p = bookPanels[id] {
            NSApp.activate(ignoringOtherApps: true)
            p.makeKeyAndOrderFront(nil)
            return
        }
        guard let plan = PlanStore.shared.plans.first(where: { $0.id == id }) else { return }
        let p = makeFloatingPanel(title: plan.name, autosave: "DailyPlanBook-\(id.uuidString)",
                                  offset: CGFloat(bookPanels.count + 1) * 376,
                                  root: BookWindowView(planID: id))
        bookPanels[id] = p
        applyMode(to: p)
        p.orderFrontRegardless()
        saveOpenBooks()
    }

    func closeBookWindow(_ id: UUID) {
        guard let p = bookPanels.removeValue(forKey: id) else { return }
        p.delegate = nil
        p.close()
        saveOpenBooks()
    }

    private func saveOpenBooks() {
        UserDefaults.standard.set(bookPanels.keys.map(\.uuidString), forKey: Self.openBooksKey)
    }

    /// 上次开着的单独窗口，重启后接着开
    private func restoreBookWindows() {
        let ids = (UserDefaults.standard.stringArray(forKey: Self.openBooksKey) ?? []).compactMap(UUID.init)
        for id in ids { openBookWindow(id) }
    }

    func applyMode() {
        for p in allPanels { applyMode(to: p) }
        rebuildMenu()
    }

    /// 钉住 / 普通 / 桌面模式对所有窗口（主窗口 + 单独的书窗口）一起生效
    private func applyMode(to panel: PlanPanel) {
        switch WindowSettings.shared.mode {
        case .pinned:
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .normal:
            panel.level = .normal
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .desktop:
            // 贴在桌面上：放在 Finder 桌面图标那层的上面一层（还能点、能打字），
            // 但仍低于所有普通窗口，打开别的窗口会盖住它。
            // 不能用 desktopWindow + 1：那一层在桌面图标下面，点击会被 Finder 的图标层接走，窗口就点不动了。
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
        if panel.isVisible { panel.orderFrontRegardless() }
    }

    /// 程序坞图标：.regular = 程序坞 + ⌘Tab 里都有；.accessory = 只在菜单栏
    func applyDock(show: Bool) {
        let policy: NSApplication.ActivationPolicy = WindowSettings.shared.showInDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
        if show, panel != nil {
            // 切换后系统可能把 App 挪到后台，把窗口叫回来
            DispatchQueue.main.async { self.showPanel() }
        }
        rebuildMenu()
    }

    func togglePanel() {
        if panel.isVisible && (panel.isKeyWindow || WindowSettings.shared.mode != .normal) {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    func showPanel() {
        PlanStore.shared.refreshToday()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    // 点关闭按钮只是藏起来，菜单栏图标能再叫出来
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { panel.orderOut(nil); return false }
        // 单独的书窗口：真关掉，下次启动不再自动打开
        if let id = bookPanels.first(where: { $0.value === sender })?.key {
            closeBookWindow(id)
            return false
        }
        return true
    }

    // MARK: - 菜单栏图标

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "每日计划")
            b.target = self
            b.action = #selector(statusClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private var menu = NSMenu()

    private func rebuildMenu() {
        menu = NSMenu()
        guard panel != nil else { return }
        let show = NSMenuItem(title: panel?.isVisible == true ? "隐藏窗口" : "显示窗口",
                              action: #selector(menuToggle), keyEquivalent: "")
        menu.addItem(show)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "开机启动", action: #selector(menuLogin), keyEquivalent: "")
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let pin = NSMenuItem(title: "钉住（一直在最前面）", action: #selector(menuPin), keyEquivalent: "")
        pin.state = WindowSettings.shared.pinned ? .on : .off
        pin.isEnabled = !WindowSettings.shared.desktopMode
        menu.addItem(pin)

        let dock = NSMenuItem(title: "在程序坞显示", action: #selector(menuDock), keyEquivalent: "")
        dock.state = WindowSettings.shared.showInDock ? .on : .off
        menu.addItem(dock)

        let desk = NSMenuItem(title: "桌面模式（贴在桌面上）", action: #selector(menuDesktop), keyEquivalent: "")
        desk.state = WindowSettings.shared.desktopMode ? .on : .off
        menu.addItem(desk)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRight {
            rebuildMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil      // 用完拿掉，左键还是显示 / 隐藏
        } else {
            togglePanel()
        }
    }

    @objc private func menuToggle() { togglePanel() }
    @objc private func menuLogin() {
        let on = !LoginItem.isEnabled
        UserDefaults.standard.set(!on, forKey: "loginItemUserDisabled")
        LoginItem.set(on)
        rebuildMenu()
    }
    @objc private func menuPin() { WindowSettings.shared.pinned.toggle() }
    @objc private func menuDock() { WindowSettings.shared.showInDock.toggle() }
    @objc private func menuDesktop() { WindowSettings.shared.desktopMode.toggle() }

    // MARK: - 导入 / 编辑用的独立窗口

    func openWindow<V: View>(title: String, size: NSSize, @ViewBuilder content: (_ close: @escaping () -> Void) -> V) {
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        w.level = .floating      // 不被常驻窗口挡住
        let close: () -> Void = { [weak self, weak w] in
            w?.close()
            self?.extraWindows.removeAll { $0 === w }
        }
        w.contentView = NSHostingView(rootView: content(close)
            .environmentObject(PlanStore.shared)
            .environmentObject(WindowSettings.shared))
        w.center()
        extraWindows.append(w)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
