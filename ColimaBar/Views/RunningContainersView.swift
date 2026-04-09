import SwiftUI

struct RunningContainersView: View {
    let profile: ColimaProfile
    @EnvironmentObject var appModel: AppModel

    @State private var containers: [Container] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isLoading && !loaded {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading containers…").font(.caption).foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Retry")
                }
            } else if containers.isEmpty {
                Text("No running containers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(containers) { container in
                    containerRow(container)
                }
            }
        }
        .task(id: profile.status) {
            await reload()
        }
    }

    private func containerRow(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(container.isRunning ? Color.accentColor : Color.secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(container.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(container.image)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                actionCluster(for: container)
            }
            if !container.hostPorts.isEmpty {
                portsChips(for: container)
                    .padding(.leading, 19)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func actionCluster(for container: Container) -> some View {
        if appModel.isContainerBusy(container.id) {
            ProgressView().controlSize(.small)
        } else {
            HStack(spacing: 4) {
                Button {
                    do {
                        try TerminalLauncher.openShell(for: container, on: profile)
                    } catch {
                        appModel.reportError(error)
                    }
                } label: {
                    Image(systemName: "terminal")
                }
                .buttonStyle(.borderless)
                .help("Open shell")
                .disabled(!container.isRunning)

                Button {
                    ContainerLogsWindowController.show(
                        container: container,
                        profile: profile,
                        appModel: appModel
                    )
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(.borderless)
                .help("View logs")

                Menu {
                    if container.isRunning {
                        Button("Stop") {
                            appModel.stopContainer(container.id, on: profile)
                        }
                        Button("Restart") {
                            appModel.restartContainer(container.id, on: profile)
                        }
                    } else {
                        Button("Start") {
                            appModel.startContainer(container.id, on: profile)
                        }
                    }
                    Divider()
                    Button("Copy ID") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(container.id, forType: .string)
                    }
                    Button("Copy Name") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(container.name, forType: .string)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .font(.system(size: 11))
        }
    }

    private func portsChips(for container: Container) -> some View {
        HStack(spacing: 4) {
            ForEach(container.hostPorts, id: \.self) { port in
                Button {
                    TerminalLauncher.openURL("http://localhost:\(port)")
                } label: {
                    Text(":\(port)")
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open http://localhost:\(port)")
            }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false; loaded = true }
        switch await appModel.listContainers(for: profile) {
        case .success(let list):
            containers = list
            errorMessage = nil
        case .failure(let message):
            containers = []
            errorMessage = message
        }
    }
}
