import SwiftUI
import AppKit

@MainActor
final class ContainerLogsWindowController {
    private static var windows: [String: NSWindow] = [:]

    static func show(container: Container, profile: ColimaProfile, appModel: AppModel) {
        let key = "\(profile.name)/\(container.id)"
        if let existing = windows[key] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = ContainerLogsView(container: container, profile: profile)
            .environmentObject(appModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Logs — \(container.name)"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = WindowDelegate(key: key)
        window.delegate = delegate
        delegates[key] = delegate

        windows[key] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static var delegates: [String: WindowDelegate] = [:]

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        let key: String
        init(key: String) { self.key = key }

        func windowWillClose(_ notification: Notification) {
            windows.removeValue(forKey: key)
            delegates.removeValue(forKey: key)
        }
    }
}

struct ContainerLogsView: View {
    let container: Container
    let profile: ColimaProfile
    @EnvironmentObject var appModel: AppModel

    @State private var logs: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 480, minHeight: 300)
        .task { await reload() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(container.name)
                    .font(.headline)
                Text("\(profile.name) · \(container.image)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await reload() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(logs, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(logs.isEmpty)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                Text(errorMessage)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Retry") { Task { await reload() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && logs.isEmpty {
            ProgressView("Loading logs…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if logs.isEmpty {
            Text("Waiting for output…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(Color.primary.opacity(0.03))
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        switch await appModel.fetchLogs(container: container.id, on: profile) {
        case .success(let text):
            logs = text
            errorMessage = nil
        case .failure(let message):
            errorMessage = message
        }
    }
}
