import Foundation
import AppKit

enum TerminalLauncher {
    static func openShell(for container: Container, on profile: ColimaProfile) throws {
        let command: String
        switch profile.runtime {
        case .docker:
            guard let dockerPath = BinaryResolver.locate("docker")?.path else {
                throw ProcessRunnerError.binaryNotFound("docker")
            }
            let context = DockerContextCLI.contextName(for: profile.name)
            command = [
                shellQuote(dockerPath),
                "--context", shellQuote(context),
                "exec", "-it",
                shellQuote(container.id),
                "sh", "-lc",
                shellQuote("command -v bash >/dev/null && exec bash || exec sh")
            ].joined(separator: " ")
        case .containerd:
            guard let colimaPath = BinaryResolver.locate("colima")?.path else {
                throw ProcessRunnerError.binaryNotFound("colima")
            }
            command = [
                shellQuote(colimaPath),
                "nerdctl",
                "-p", shellQuote(profile.name),
                "--",
                "exec", "-it",
                shellQuote(container.id),
                "sh"
            ].joined(separator: " ")
        }

        let script = """
        #!/bin/sh
        clear
        printf 'ColimaBar — exec into %s\\n' \(shellQuote(container.name))
        \(command)
        """

        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ColimaBar", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let scriptURL = tmpDir.appendingPathComponent("exec-\(sanitize(container.id)).command")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        NSWorkspace.shared.open(scriptURL)
    }

    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
