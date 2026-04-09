import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var downloadURL: URL?
    @Published private(set) var isUpdating = false
    @Published private(set) var updateError: String?

    private let currentVersion: String
    private let repo = "dreuse/ColimaBar"

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

            var zipURL: URL?
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String, name.hasSuffix(".zip"),
                       let urlStr = asset["browser_download_url"] as? String {
                        zipURL = URL(string: urlStr)
                        break
                    }
                }
            }

            if isNewer(remote: remote, local: currentVersion) {
                availableVersion = remote
                downloadURL = zipURL
            } else {
                availableVersion = nil
                downloadURL = nil
            }
        } catch {
            // Best-effort; silent on failure.
        }
    }

    func performUpdate() {
        guard let downloadURL else {
            updateError = "No download URL found. Check GitHub releases manually."
            return
        }

        isUpdating = true
        updateError = nil

        Task {
            do {
                let appPath = Bundle.main.bundlePath
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ColimaBarUpdate-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                // Download the zip
                let (zipData, _) = try await URLSession.shared.data(from: downloadURL)
                let zipPath = tempDir.appendingPathComponent("ColimaBar.zip")
                try zipData.write(to: zipPath)

                // Unzip via ditto (preserves code signatures)
                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-x", "-k", zipPath.path, tempDir.path]
                try ditto.run()
                ditto.waitUntilExit()
                guard ditto.terminationStatus == 0 else {
                    throw UpdateError.unzipFailed
                }

                let newApp = tempDir.appendingPathComponent("ColimaBar.app")
                guard FileManager.default.fileExists(atPath: newApp.path) else {
                    throw UpdateError.appNotFoundInZip
                }

                // Replace the running app via a shell script that waits for us to exit
                let script = """
                sleep 1
                rm -rf '\(appPath)'
                cp -R '\(newApp.path)' '\(appPath)'
                open '\(appPath)'
                rm -rf '\(tempDir.path)'
                """
                let shell = Process()
                shell.executableURL = URL(fileURLWithPath: "/bin/sh")
                shell.arguments = ["-c", script]
                try shell.run()

                NSApplication.shared.terminate(nil)
            } catch {
                isUpdating = false
                updateError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
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

private enum UpdateError: LocalizedError {
    case unzipFailed
    case appNotFoundInZip

    var errorDescription: String? {
        switch self {
        case .unzipFailed: return "Failed to unzip the update."
        case .appNotFoundInZip: return "ColimaBar.app not found in the downloaded archive."
        }
    }
}
