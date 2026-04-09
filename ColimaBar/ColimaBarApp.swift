import SwiftUI
import AppKit
import Combine

@main
struct ColimaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup { EmptyView().frame(width: 0, height: 0) }
            .windowResizability(.contentSize)
    }
}

// NSHostingController that auto-updates preferredContentSize when SwiftUI
// content resizes. NSPopover observes this via KVO and resizes both directions.
final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let hostingView = view as? NSHostingView<Content> else { return }
        hostingView.sizingOptions.insert(.preferredContentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let appModel = AppModel()
    private let iconPulse = IconPulse()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ColimaBarNotifications.shared.requestAuthorizationIfNeeded()
        for window in NSApp.windows { window.close() }

        setupStatusItem()
        setupPopover()
        observeIconState()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        updateIcon()
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Left-click popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let rootView = MenuContentView().environmentObject(appModel)
        popover.contentViewController = PopoverHostingController(rootView: rootView)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            appModel.onAppear()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        appModel.onDisappear()
    }

    // MARK: - Right-click context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let startDefault = NSMenuItem(title: "Start Default", action: #selector(startDefaultAction), keyEquivalent: "")
        startDefault.target = self
        if let profile = appModel.profiles.first(where: { $0.name == "default" }),
           profile.status != .stopped {
            startDefault.isEnabled = false
        }
        menu.addItem(startDefault)

        let stopAll = NSMenuItem(title: "Stop All", action: #selector(stopAllAction), keyEquivalent: "")
        stopAll.target = self
        stopAll.isEnabled = appModel.runningCount > 0
        menu.addItem(stopAll)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit ColimaBar", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func startDefaultAction() { appModel.startDefaultIfStopped() }
    @objc private func stopAllAction() { appModel.stopAllRunning() }
    @objc private func refreshAction() { Task { await appModel.refresh() } }
    @objc private func quitAction() { NSApp.terminate(nil) }

    @objc func showPreferences() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ColimaBar Preferences"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Icon state observation

    private func observeIconState() {
        appModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.syncPulse(); self?.updateIcon() }
            }
            .store(in: &cancellables)

        iconPulse.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateIcon() }
            }
            .store(in: &cancellables)
    }

    private func syncPulse() {
        if appModel.iconState == .transitioning {
            iconPulse.start()
        } else {
            iconPulse.stop()
        }
    }

    private func updateIcon() {
        let state: IconState
        let base = appModel.iconState
        if base == .transitioning {
            state = iconPulse.isLit ? .anyRunning : .allStopped
        } else {
            state = base
        }
        statusItem?.button?.image = IconRenderer.menuBarIcon(
            state: state,
            runningCount: appModel.runningCount
        )
    }
}

@MainActor
final class IconPulse: ObservableObject {
    @Published private(set) var isLit: Bool = false
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.isLit.toggle() }
        }
    }

    func stop() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        isLit = false
    }
}
