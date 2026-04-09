import Foundation
import IOKit.ps
import AppKit

@MainActor
final class PowerMonitor: ObservableObject {

    @Published private(set) var isOnBattery: Bool = false
    @Published private(set) var lastAutoStop: AutoStopEvent?

    struct AutoStopEvent: Equatable {
        let profile: String
        let timestamp: Date
        let reason: Reason

        enum Reason: String { case battery, sleep }
    }

    var onBatteryAutoStop: (@MainActor (String) async -> Void)?
    var onSleepAutoStop: (@MainActor ([String]) async -> Void)?
    var runningProfilesProvider: (@MainActor () -> [String])?

    @Published var autoStopOnBattery: Bool = false
    @Published var autoStopOnSleep: Bool = false

    private var powerSource: CFRunLoopSource?
    private var batteryHoldoffTask: Task<Void, Never>?
    private let holdoffSeconds: TimeInterval = 5 * 60
    private var sleepObserver: NSObjectProtocol?

    init() {
        updatePowerState()
        startObserving()
    }

    func invalidate() {
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
        }
        powerSource = nil
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
        sleepObserver = nil
        batteryHoldoffTask?.cancel()
        batteryHoldoffTask = nil
    }

    private func startObserving() {
        // NSWorkspace posts sleep notifications on its own notification center,
        // not NotificationCenter.default.
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWillSleep() }
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in monitor.handlePowerChange() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
    }

    @MainActor
    private func handleWillSleep() {
        guard autoStopOnSleep, let provider = runningProfilesProvider else { return }
        let running = provider()
        guard !running.isEmpty else { return }
        lastAutoStop = AutoStopEvent(profile: running.first ?? "", timestamp: Date(), reason: .sleep)
        Task { await onSleepAutoStop?(running) }
    }

    @MainActor
    private func handlePowerChange() {
        let wasOnBattery = isOnBattery
        updatePowerState()

        if isOnBattery && !wasOnBattery {
            armBatteryAutoStop()
        } else if !isOnBattery {
            batteryHoldoffTask?.cancel()
            batteryHoldoffTask = nil
        }
    }

    private func updatePowerState() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        var onBattery = false
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey] as? String,
               state == kIOPSBatteryPowerValue {
                onBattery = true
                break
            }
        }
        isOnBattery = onBattery
    }

    private func armBatteryAutoStop() {
        batteryHoldoffTask?.cancel()
        batteryHoldoffTask = Task { @MainActor [weak self, holdoffSeconds] in
            try? await Task.sleep(nanoseconds: UInt64(holdoffSeconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            guard self.isOnBattery, self.autoStopOnBattery else { return }
            guard let provider = self.runningProfilesProvider else { return }
            let running = provider()
            for profile in running {
                self.lastAutoStop = AutoStopEvent(profile: profile, timestamp: Date(), reason: .battery)
                await self.onBatteryAutoStop?(profile)
            }
        }
    }
}
