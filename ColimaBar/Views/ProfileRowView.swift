import SwiftUI

struct ProfileRowView: View {
    let profile: ColimaProfile
    let isActive: Bool
    @EnvironmentObject var appModel: AppModel
    @AppStorage("ui.compactMode") private var compactMode: Bool = false

    @State private var isExpanded = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                if !compactMode {
                    Divider().padding(.vertical, 6)
                    resourceSpecs
                    if profile.status == .running, let sample = appModel.resourceSamples[profile.name] {
                        Divider().padding(.vertical, 6)
                        expandedMeters(sample: sample)
                    }
                    if profile.status == .running {
                        Divider().padding(.vertical, 6)
                        RunningContainersView(profile: profile)
                    }
                }
                actionButtons
                    .padding(.top, 8)
            }
        }
        .padding(compactMode ? 8 : 10)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
        .animation(.easeInOut(duration: 0.18), value: profile.status)
        .confirmationDialog(
            "Delete profile \"\(profile.name)\"?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { appModel.deleteProfile(profile.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the Lima VM and its data. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                disclosureChevron
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(.system(.body, design: .default).weight(.semibold))
                            .lineLimit(1)
                        if isActive {
                            Text("active")
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                        if profile.kubernetes {
                            Image(systemName: "sailboat")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.blue)
                                .help("Kubernetes enabled")
                        }
                    }
                    StatusPill(status: profile.status)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if profile.status == .running, let sample = appModel.resourceSamples[profile.name] {
                compactMeters(sample: sample)
            }
            if appModel.isBusy(profile.name) {
                ProgressView().controlSize(.small)
            } else {
                quickAction
            }
        }
    }

    private func compactMeters(sample: ResourceSample) -> some View {
        HStack(spacing: 3) {
            ResourceMeter(label: "", percent: sample.cpuPercent)
            ResourceMeter(label: "", percent: sample.memoryPercent)
            ResourceMeter(label: "", percent: sample.diskPercent)
        }
        .frame(width: 80)
        .help(String(format: "CPU %.0f%% · RAM %.0f%% · Disk %.0f%%",
                     sample.cpuPercent, sample.memoryPercent, sample.diskPercent))
    }

    private func expandedMeters(sample: ResourceSample) -> some View {
        VStack(spacing: 4) {
            ResourceMeter(label: "CPU", percent: sample.cpuPercent, detail: String(format: "%.0f%%", sample.cpuPercent), compact: false)
            ResourceMeter(label: "RAM", percent: sample.memoryPercent, detail: String(format: "%.1f / %.0f GB", sample.memoryUsedGB, sample.memoryTotalGB), compact: false)
            ResourceMeter(label: "DISK", percent: sample.diskPercent, detail: String(format: "%.0f / %.0f GB", sample.diskUsedGB, sample.diskTotalGB), compact: false)
        }
    }

    private var disclosureChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .frame(width: 10)
    }

    @ViewBuilder
    private var quickAction: some View {
        switch profile.status {
        case .running:
            Button {
                appModel.stopProfile(profile.name)
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .help("Stop \(profile.name)")
        case .stopped, .unknown:
            Button {
                appModel.startProfile(profile.name)
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .tint(.green)
            .help("Start \(profile.name)")
        case .starting, .stopping:
            ProgressView().controlSize(.small)
        }
    }

    private var resourceSpecs: some View {
        let sample = appModel.resourceSamples[profile.name]
        return VStack(alignment: .leading, spacing: 4) {
            if let sample {
                HStack(spacing: 12) {
                    specItem(icon: "cpu", text: String(format: "%.1f / %d", Double(profile.cpus ?? 0) * sample.cpuPercent / 100, profile.cpus ?? 0))
                    specItem(icon: "memorychip", text: String(format: "%.1f / %.0f GB", sample.memoryUsedGB, sample.memoryTotalGB))
                    specItem(icon: "internaldrive", text: String(format: "%.0f / %.0f GB", sample.diskUsedGB, sample.diskTotalGB))
                }
            } else {
                HStack(spacing: 12) {
                    specItem(icon: "cpu", text: profile.cpus.map { "\($0) CPU" } ?? "—")
                    specItem(icon: "memorychip", text: profile.memoryGB.map { String(format: "%.0f GB", $0) } ?? "—")
                    specItem(icon: "internaldrive", text: profile.diskGB.map { String(format: "%.0f GB", $0) } ?? "—")
                }
            }
            HStack(spacing: 12) {
                specItem(icon: "shippingbox", text: profile.runtime.displayName)
                if let arch = profile.arch {
                    specItem(icon: "cpu.fill", text: arch)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func specItem(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).monospacedDigit()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if !isActive {
                Button {
                    appModel.setActive(profile)
                } label: {
                    Label("Set Active", systemImage: "checkmark.circle")
                }
            }
            if profile.kubernetes && profile.status == .running {
                let kubeName = KubectlContextCLI.contextName(for: profile.name)
                if appModel.activeKubeContext != kubeName {
                    Button {
                        appModel.useKubeContext(for: profile.name)
                    } label: {
                        Label("Use kubectl", systemImage: "sailboat")
                    }
                }
            }
            Spacer()
            Menu {
                Button("Edit YAML in editor") {
                    do {
                        try ProfileYAMLStore.openInDefaultEditor(profile: profile.name)
                    } catch {
                        appModel.reportError(error)
                    }
                }
                Button("Export YAML…") {
                    ProfileYAMLStore.exportViaSavePanel(profile: profile.name)
                }
                Button("Import YAML…") {
                    _ = ProfileYAMLStore.importViaOpenPanel(intoProfile: profile.name)
                }
                Divider()
                Button("Delete profile…", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(profile.status != .stopped || appModel.isBusy(profile.name))
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isActive ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.03))
    }
}
