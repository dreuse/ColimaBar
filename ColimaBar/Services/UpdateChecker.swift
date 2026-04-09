import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var isUpdating = false
    @Published private(set) var updateError: String?

    private let currentVersion: String
    private let repo = "dreuse/ColimaBar"
    private let runner = ProcessRunner.shared

    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdate() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            if isNewer(remote: remote, local: currentVersion) {
                availableVersion = remote
            } else {
                availableVersion = nil
            }
        } catch {
            // Network failures are silent — update check is best-effort.
        }
    }

    func performUpdate() {
        guard let brew = BinaryResolver.locate("brew") else {
            updateError = "Homebrew not found. Download the update manually from GitHub."
            return
        }

        isUpdating = true
        updateError = nil

        Task {
            do {
                _ = try await runner.runChecked(
                    executableURL: brew,
                    arguments: ["upgrade", "--cask", "colimabar"],
                    timeout: 120
                )
                relaunch()
            } catch {
                isUpdating = false
                updateError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func relaunch() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait 1s for the current process to exit, then open the new bundle.
        task.arguments = ["-c", "sleep 1 && open '\(bundlePath)'"]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
