import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var profiles: [ColimaProfile] = []
    @Published private(set) var activeContext: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var missingColima: Bool = false
    @Published private(set) var inFlightProfileOps: Set<String> = []
    @Published private(set) var showBatteryOptIn: Bool = false
    @Published private(set) var resourceSamples: [String: ResourceSample] = [:]
    @Published private(set) var activeKubeContext: String?
    @Published private(set) var allContainers: [String: [Container]] = [:]
    @Published var searchQuery: String = ""

    struct SearchHit: Identifiable, Hashable {
        let profile: String
        let container: Container
        var id: String { "\(profile)/\(container.id)" }
    }

    var searchHits: [SearchHit] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for (profileName, containers) in allContainers {
            for container in containers
            where container.name.lowercased().contains(query)
                || container.image.lowercased().contains(query)
                || container.id.lowercased().hasPrefix(query) {
                hits.append(SearchHit(profile: profileName, container: container))
            }
        }
        return hits.sorted { $0.container.name < $1.container.name }
    }

    let powerMonitor: PowerMonitor

    @AppStorage("battery.optInPrompted") private var batteryOptInPrompted = false

    private let controller: ColimaControlling?
    private var refreshTimer: Timer?
    private var refreshInFlight = false
    private var preferencesObserver: NSObjectProtocol?

    init(controller: ColimaControlling? = LiveColimaController(), powerMonitor: PowerMonitor? = nil) {
        self.controller = controller
        self.powerMonitor = powerMonitor ?? PowerMonitor()
        self.missingColima = (controller == nil)
        configurePowerMonitor()
        observePreferences()
    }

    deinit {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    private func observePreferences() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyPreferences() }
        }
    }

    private func applyPreferences() {
        let defaults = UserDefaults.standard
        powerMonitor.autoStopOnBattery = defaults.bool(forKey: "battery.autoStopEnabled")
        powerMonitor.autoStopOnSleep = defaults.bool(forKey: "battery.sleepAutoStopEnabled")
        let interval = defaults.double(forKey: "pref.pollInterval")
        if interval > 0 && refreshTimer != nil {
            startPolling(interval: interval)
        }
    }

    private func configurePowerMonitor() {
        let defaults = UserDefaults.standard
        powerMonitor.autoStopOnBattery = defaults.bool(forKey: "battery.autoStopEnabled")
        powerMonitor.autoStopOnSleep = defaults.bool(forKey: "battery.sleepAutoStopEnabled")
        powerMonitor.runningProfilesProvider = { [weak self] in
            self?.profiles.filter { $0.status == .running }.map(\.name) ?? []
        }
        powerMonitor.onBatteryAutoStop = { [weak self] profile in
            self?.stopProfile(profile)
        }
        powerMonitor.onSleepAutoStop = { [weak self] running in
            for name in running { self?.stopProfile(name) }
        }
    }

    func evaluateBatteryOptInBanner() {
        if batteryOptInPrompted { return }
        guard powerMonitor.isOnBattery, runningCount > 0 else { return }
        showBatteryOptIn = true
    }

    func acceptBatteryAutoStop() {
        UserDefaults.standard.set(true, forKey: "battery.autoStopEnabled")
        UserDefaults.standard.set(true, forKey: "battery.sleepAutoStopEnabled")
        powerMonitor.autoStopOnBattery = true
        powerMonitor.autoStopOnSleep = true
        batteryOptInPrompted = true
        showBatteryOptIn = false
    }

    func dismissBatteryOptIn() {
        batteryOptInPrompted = true
        showBatteryOptIn = false
    }

    var runningCount: Int { profiles.filter { $0.status == .running }.count }
    var stoppedCount: Int { profiles.filter { $0.status == .stopped }.count }

    enum Summary {
        case missingColima
        case anyRunning(count: Int)
        case allStopped
        case error
    }

    var summary: Summary {
        if missingColima { return .missingColima }
        if lastError != nil && profiles.isEmpty { return .error }
        return runningCount > 0 ? .anyRunning(count: runningCount) : .allStopped
    }

    var hasTransitioningProfile: Bool {
        profiles.contains { $0.status == .starting || $0.status == .stopping }
            || !inFlightProfileOps.isEmpty
    }

    var iconState: IconState {
        if missingColima || (lastError != nil && profiles.isEmpty) { return .error }
        if hasTransitioningProfile { return .transitioning }
        return runningCount > 0 ? .anyRunning : .allStopped
    }

    func isBusy(_ profileName: String) -> Bool {
        inFlightProfileOps.contains(profileName)
    }

    func onAppear() {
        guard !missingColima else { return }
        Task { await refresh() }
        startPolling()
    }

    func onDisappear() {
        stopPolling()
    }

    private func startPolling(interval: TimeInterval? = nil) {
        stopPolling()
        let stored = UserDefaults.standard.double(forKey: "pref.pollInterval")
        let effective = interval ?? (stored > 0 ? stored : 5.0)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: effective, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    private func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        guard let controller else { missingColima = true; return }
        guard !refreshInFlight else { return }
        refreshInFlight = true
        isLoading = true
        defer {
            refreshInFlight = false
            isLoading = false
        }

        // Profile list is the critical path — context lookups are best-effort
        // because docker/kubectl contexts may not exist during start/stop transitions.
        do {
            let list = try await controller.listProfiles()
            self.profiles = list.sorted { $0.name < $1.name }
            self.lastError = nil
        } catch {
            self.lastError = Self.describe(error)
        }

        self.activeContext = await controller.currentContext()
        self.activeKubeContext = await controller.currentKubeContext()

        evaluateBatteryOptInBanner()
        Task { await self.sampleResources() }
        Task { await self.indexAllContainers() }
    }

    func useKubeContext(for profile: String) {
        Task {
            do {
                try await controller?.useKubeContext(for: profile)
                await refresh()
            } catch {
                lastError = Self.describe(error)
            }
        }
    }

    func sampleResources() async {
        let running = profiles.filter { $0.status == .running }
        for profile in running {
            if let sample = await ResourceSampler.shared.sample(for: profile) {
                resourceSamples[profile.name] = sample
                if sample.diskPercent >= 90 {
                    ColimaBarNotifications.shared.notifyDiskHigh(
                        profile: profile.name,
                        percent: Int(sample.diskPercent)
                    )
                }
            }
        }
        let runningNames = Set(running.map(\.name))
        resourceSamples = resourceSamples.filter { runningNames.contains($0.key) }
    }

    func indexAllContainers() async {
        guard let controller else { return }
        var index: [String: [Container]] = [:]
        for profile in profiles where profile.status == .running {
            if let list = try? await controller.listContainers(for: profile) {
                index[profile.name] = list
            }
        }
        allContainers = index
    }

    func startProfile(_ name: String) {
        let startedAt = Date()
        runProfileOp(name, notifyOnSuccess: { [weak self] in
            let duration = Date().timeIntervalSince(startedAt)
            ColimaBarNotifications.shared.notifyStartSucceeded(
                profile: name,
                duration: duration,
                context: self?.activeContext
            )
        }, notifyOnFailure: { message in
            ColimaBarNotifications.shared.notifyStartFailed(profile: name, error: message)
        }) { [controller] in
            try await controller?.start(profile: name)
        }
    }

    func stopProfile(_ name: String) {
        runProfileOp(name) { [controller] in
            try await controller?.stop(profile: name)
        }
    }

    func deleteProfile(_ name: String) {
        runProfileOp(name) { [controller] in
            try await controller?.delete(profile: name)
        }
    }

    func createProfile(_ config: ProfileStartConfig) async throws {
        guard let controller else { throw ProcessRunnerError.binaryNotFound("colima") }
        inFlightProfileOps.insert(config.name)
        let startedAt = Date()
        do {
            try await controller.start(config: config)
            inFlightProfileOps.remove(config.name)
            await refresh()
            ColimaBarNotifications.shared.notifyStartSucceeded(
                profile: config.name,
                duration: Date().timeIntervalSince(startedAt),
                context: activeContext
            )
        } catch {
            inFlightProfileOps.remove(config.name)
            let description = Self.describe(error)
            lastError = description
            ColimaBarNotifications.shared.notifyStartFailed(profile: config.name, error: description)
            await refresh()
            throw error
        }
    }

    func setActive(_ profile: ColimaProfile) {
        runProfileOp(profile.name) { [controller] in
            if profile.status != .running {
                try await controller?.start(profile: profile.name)
            }
            try await controller?.useContext(for: profile.name)
        }
    }

    @Published private(set) var inFlightContainerOps: Set<String> = []

    enum ContainerListResult {
        case success([Container])
        case failure(String)
    }

    func isContainerBusy(_ id: String) -> Bool {
        inFlightContainerOps.contains(id)
    }

    func stopContainer(_ id: String, on profile: ColimaProfile) {
        runContainerOp(id) { [controller] in
            try await controller?.stopContainer(id, on: profile)
        }
    }

    func startContainer(_ id: String, on profile: ColimaProfile) {
        runContainerOp(id) { [controller] in
            try await controller?.startContainer(id, on: profile)
        }
    }

    func restartContainer(_ id: String, on profile: ColimaProfile) {
        runContainerOp(id) { [controller] in
            try await controller?.restartContainer(id, on: profile)
        }
    }

    enum LogsResult {
        case success(String)
        case failure(String)
    }

    func fetchLogs(container id: String, on profile: ColimaProfile, tail: Int = 500) async -> LogsResult {
        guard let controller else { return .failure("colima not found") }
        do {
            let text = try await controller.logsSnapshot(container: id, on: profile, tail: tail)
            return .success(text)
        } catch {
            return .failure(Self.describe(error))
        }
    }

    private func runContainerOp(
        _ id: String,
        _ work: @escaping @Sendable () async throws -> Void
    ) {
        inFlightContainerOps.insert(id)
        Task { @MainActor in
            do {
                try await work()
            } catch {
                self.lastError = Self.describe(error)
            }
            self.inFlightContainerOps.remove(id)
        }
    }

    func listContainers(for profile: ColimaProfile) async -> ContainerListResult {
        guard let controller else { return .failure("colima not found") }
        do {
            let containers = try await controller.listContainers(for: profile)
            return .success(containers)
        } catch {
            return .failure(Self.describe(error))
        }
    }

    func dismissError() {
        lastError = nil
    }

    func reportError(_ error: Error) {
        lastError = Self.describe(error)
    }

    func stopAllRunning() {
        for profile in profiles where profile.status == .running {
            stopProfile(profile.name)
        }
    }

    func startDefaultIfStopped() {
        if let defaultProfile = profiles.first(where: { $0.name == "default" }),
           defaultProfile.status != .running {
            startProfile("default")
        } else if profiles.contains(where: { $0.name == "default" }) {
            return
        } else {
            // No default profile — create a bare one with sensible defaults.
            let config = ProfileStartConfig(
                name: "default",
                cpus: 2,
                memoryGB: 4,
                diskGB: 60,
                runtime: .docker,
                vmType: .platformDefault
            )
            Task { try? await createProfile(config) }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func runProfileOp(
        _ name: String,
        timeoutSeconds: TimeInterval = 300,
        notifyOnSuccess: (@MainActor () -> Void)? = nil,
        notifyOnFailure: (@MainActor (String) -> Void)? = nil,
        _ work: @escaping @Sendable () async throws -> Void
    ) {
        inFlightProfileOps.insert(name)
        Task { @MainActor in
            var succeeded = false
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await work() }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        throw ProcessRunnerError.timeout("profile operation on \(name)")
                    }
                    try await group.next()
                    group.cancelAll()
                }
                succeeded = true
            } catch {
                let description = Self.describe(error)
                self.lastError = description
                notifyOnFailure?(description)
            }
            self.inFlightProfileOps.remove(name)
            await self.refresh()
            if succeeded { notifyOnSuccess?() }
        }
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
