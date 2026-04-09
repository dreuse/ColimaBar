import Foundation

struct ContainerCLI: Sendable {
    let colima: ColimaCLI
    let docker: URL?
    let runner = ProcessRunner.shared

    init(colima: ColimaCLI) {
        self.colima = colima
        self.docker = BinaryResolver.locate("docker")
    }

    private static func isTransientDockerError(_ stderr: String) -> Bool {
        let transient = [
            "context not found",
            "not running",
            "Cannot connect",
            "connection refused",
            "Is the docker daemon running",
            "error during connect",
            "No such file or directory",
        ]
        let lower = stderr.lowercased()
        return transient.contains { lower.contains($0.lowercased()) }
    }

    func listContainers(for profile: ColimaProfile) async throws -> [Container] {
        guard profile.status == .running else { return [] }

        do {
            switch profile.runtime {
            case .docker:
                guard let docker else {
                    throw ProcessRunnerError.binaryNotFound("docker")
                }
                let output = try await runner.runChecked(
                    executableURL: docker,
                    arguments: [
                        "--context", DockerContextCLI.contextName(for: profile.name),
                        "ps",
                        "--format", "{{json .}}"
                    ],
                    timeout: 10
                )
                return Container.decodeList(from: output)

            case .containerd:
                let output = try await colima.nerdctl(
                    profile: profile.name,
                    arguments: ["ps", "--format", "{{json .}}"]
                )
                return Container.decodeList(from: output)
            }
        } catch let error as ProcessRunnerError {
            // Docker context gets torn down before colima reports the profile
            // as stopped — treat "context not found" as empty, not an error.
            if case .nonZeroExit(_, _, let stderr) = error,
               Self.isTransientDockerError(stderr) {
                return []
            }
            throw error
        }
    }
}
