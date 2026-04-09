import Foundation

struct DockerContextCLI: Sendable {
    let executable: URL?
    let runner = ProcessRunner.shared

    init() {
        self.executable = BinaryResolver.locate("docker")
    }

    static func contextName(for profile: String) -> String {
        profile == "default" ? "colima" : "colima-\(profile)"
    }

    func currentContext() async -> String? {
        guard let executable else { return nil }
        let output = try? await runner.runChecked(
            executableURL: executable,
            arguments: ["context", "show"],
            timeout: 5
        )
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func useContext(for profile: String) async throws {
        guard let executable else {
            throw ProcessRunnerError.binaryNotFound("docker")
        }
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: ["context", "use", Self.contextName(for: profile)],
            timeout: 10
        )
    }
}
