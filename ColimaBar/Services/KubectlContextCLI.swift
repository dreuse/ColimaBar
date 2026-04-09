import Foundation

struct KubectlContextCLI: Sendable {
    let executable: URL?
    let runner = ProcessRunner.shared

    init() {
        self.executable = BinaryResolver.locate("kubectl")
    }

    static func contextName(for profile: String) -> String {
        profile == "default" ? "colima" : "colima-\(profile)"
    }

    func currentContext() async -> String? {
        guard let executable else { return nil }
        let output = try? await runner.runChecked(
            executableURL: executable,
            arguments: ["config", "current-context"],
            timeout: 5
        )
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func useContext(for profile: String) async throws {
        guard let executable else {
            throw ProcessRunnerError.binaryNotFound("kubectl")
        }
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: ["config", "use-context", Self.contextName(for: profile)],
            timeout: 10
        )
    }

    func listPods(profile: String) async throws -> [KubePod] {
        guard let executable else {
            throw ProcessRunnerError.binaryNotFound("kubectl")
        }
        let output = try await runner.runChecked(
            executableURL: executable,
            arguments: [
                "--context", Self.contextName(for: profile),
                "get", "pods", "--all-namespaces",
                "-o", "json"
            ],
            timeout: 10
        )
        return KubePod.decodeList(from: output)
    }
}

struct KubePod: Identifiable, Hashable, Sendable {
    let namespace: String
    let name: String
    let phase: String
    let ready: String

    var id: String { "\(namespace)/\(name)" }

    static func decodeList(from json: String) -> [KubePod] {
        guard let data = json.data(using: .utf8),
              let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = top["items"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let metadata = item["metadata"] as? [String: Any],
                  let name = metadata["name"] as? String,
                  let namespace = metadata["namespace"] as? String,
                  let status = item["status"] as? [String: Any],
                  let phase = status["phase"] as? String else { return nil }

            let containerStatuses = status["containerStatuses"] as? [[String: Any]] ?? []
            let total = containerStatuses.count
            let ready = containerStatuses.filter { ($0["ready"] as? Bool) == true }.count
            return KubePod(
                namespace: namespace,
                name: name,
                phase: phase,
                ready: "\(ready)/\(total)"
            )
        }
    }
}
