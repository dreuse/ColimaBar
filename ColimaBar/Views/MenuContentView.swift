import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingNewProfile = false

    private var startDefaultDisabled: Bool {
        if appModel.isBusy("default") { return true }
        guard let defaultProfile = appModel.profiles.first(where: { $0.name == "default" }) else {
            return false
        }
        return defaultProfile.status != .stopped
    }


    var body: some View {
        VStack(spacing: 0) {
            if appModel.missingColima {
                missingColimaView
            } else {
                header
                Divider()
                searchField
                if !appModel.searchQuery.isEmpty {
                    searchResults
                } else {
                    content
                }
                Divider()
                footer
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
        .sheet(isPresented: $showingNewProfile) {
            NewProfileSheet()
                .environmentObject(appModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: IconRenderer.colorIcon(size: 32))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("ColimaBar")
                    .font(.headline)
                HStack(spacing: 6) {
                    summaryChip
                    if let context = appModel.activeContext {
                        Text("· \(context)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Button {
                Task { await appModel.refresh() }
            } label: {
                if appModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r")
            .help("Refresh")
        }
        .padding(12)
    }

    private var summaryChip: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(appModel.runningCount) running · \(appModel.stoppedCount) stopped")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !appModel.resourceSamples.isEmpty {
                aggregateResourceRow
            }
        }
    }

    private var aggregateResourceRow: some View {
        let samples = Array(appModel.resourceSamples.values)
        let avgCPU = samples.map(\.cpuPercent).reduce(0, +) / max(1, Double(samples.count))
        let avgMem = samples.map(\.memoryPercent).reduce(0, +) / max(1, Double(samples.count))
        let maxDisk = samples.map(\.diskPercent).max() ?? 0
        return HStack(spacing: 8) {
            resourceLabel("CPU", percent: avgCPU)
            resourceLabel("RAM", percent: avgMem)
            resourceLabel("Disk", percent: maxDisk)
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func resourceLabel(_ label: String, percent: Double) -> some View {
        HStack(spacing: 2) {
            Text(label)
            Text(String(format: "%.0f%%", percent))
                .foregroundStyle(percent >= 90 ? .red : percent >= 70 ? .orange : .secondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search containers…", text: $appModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.caption)
            if !appModel.searchQuery.isEmpty {
                Button {
                    appModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appModel.searchHits.isEmpty {
                Text("No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(appModel.searchHits) { hit in
                    searchHitRow(hit)
                }
            }
        }
        .padding(10)
    }

    private func searchHitRow(_ hit: AppModel.SearchHit) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(hit.container.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(hit.profile) · \(hit.container.image)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(hit.container.status)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(6)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let error = appModel.lastError, appModel.profiles.isEmpty {
            errorState(error)
        } else if appModel.profiles.isEmpty {
            if appModel.isLoading {
                loadingState
            } else {
                emptyState
            }
        } else {
            profileList
        }
    }

    private var profileList: some View {
        VStack(spacing: 6) {
            if let version = appModel.updateChecker.availableVersion {
                updateBanner(version: version)
            }
            if appModel.showBatteryOptIn {
                batteryOptInBanner
            }
            if let error = appModel.lastError {
                errorBanner(error)
            }
            ForEach(appModel.profiles) { profile in
                ProfileRowView(
                    profile: profile,
                    isActive: isActive(profile)
                )
                .environmentObject(appModel)
            }
        }
        .padding(12)
    }

    private var batteryOptInBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bolt.slash.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("On battery")
                    .font(.caption.weight(.semibold))
                Text("Auto-stop Colima when you unplug or sleep the Mac?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button("Enable") { appModel.acceptBatteryAutoStop() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Not now") { appModel.dismissBatteryOptIn() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
    }

    private func isActive(_ profile: ColimaProfile) -> Bool {
        guard let ctx = appModel.activeContext else { return false }
        return ctx == DockerContextCLI.contextName(for: profile.name)
    }

    private func updateBanner(version: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("v\(version) available")
                    .font(.caption.weight(.semibold))
                if let error = appModel.updateChecker.updateError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    appModel.updateChecker.performUpdate()
                } label: {
                    if appModel.updateChecker.isUpdating {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Updating…")
                        }
                    } else {
                        Text("Update & Restart")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appModel.updateChecker.isUpdating)
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Loading profiles…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private var emptyState: some View {
        OnboardingView()
            .environmentObject(appModel)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Retry") {
                Task { await appModel.refresh() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                appModel.dismissError()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                showingNewProfile = true
            } label: {
                Label("New Profile", systemImage: "plus")
            }
            .keyboardShortcut("n")
            .help("Create a new profile (⌘N)")

            Button {
                appModel.startDefaultIfStopped()
            } label: {
                Label("Start Default", systemImage: "play.fill")
            }
            .help("Start the `default` profile")
            .disabled(startDefaultDisabled)

            Button {
                appModel.stopAllRunning()
            } label: {
                Label("Stop All", systemImage: "stop.fill")
            }
            .help("Stop every running profile")
            .disabled(appModel.runningCount == 0)

            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.caption2)
                .foregroundStyle(.quaternary)
            Button {
                appModel.quit()
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
        .padding(10)
    }

    // MARK: - Missing Colima state

    private var missingColimaView: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Colima not found")
                .font(.headline)
            Text("ColimaBar couldn't locate the `colima` executable. Install it via Homebrew:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("brew install colima")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString("brew install colima", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }
            Button("Quit") { appModel.quit() }
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Light") {
    MenuContentView()
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MenuContentView()
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}
