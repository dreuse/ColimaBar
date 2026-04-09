import Foundation

struct ContainerActionsCLI: Sendable {
    let colima: ColimaCLI
    let docker: URL?
    let runner = ProcessRunner.shared

    init(colima: ColimaCLI) {
        self.colima = colima
        self.docker = BinaryResolver.locate("docker")
    }

    func stop(container id: String, on profile: ColimaProfile) async throws {
        try await runAction(["stop", id], on: profile)
    }

    func start(container id: String, on profile: ColimaProfile) async throws {
        try await runAction(["start", id], on: profile)
    }

    func restart(container id: String, on profile: ColimaProfile) async throws {
        try await runAction(["restart", id], on: profile)
    }

    func streamLogs(
        container id: String,
        on profile: ColimaProfile,
        follow: Bool = true
    ) async throws -> String {
        var args = ["logs"]
        if follow { args.append("--tail=200") }
        args.append(id)
        return try await runOutput(args, on: profile, timeout: follow ? 5 : 10)
    }

    func logsSnapshot(container id: String, on profile: ColimaProfile, tail: Int = 500) async throws -> String {
        try await runOutput(["logs", "--tail", String(tail), id], on: profile, timeout: 15)
    }

    private func runAction(_ args: [String], on profile: ColimaProfile) async throws {
        _ = try await runOutput(args, on: profile, timeout: 30)
    }

    private func runOutput(
        _ args: [String],
        on profile: ColimaProfile,
        timeout: TimeInterval
    ) async throws -> String {
        switch profile.runtime {
        case .docker:
            guard let docker else { throw ProcessRunnerError.binaryNotFound("docker") }
            return try await runner.runChecked(
                executableURL: docker,
                arguments: ["--context", DockerContextCLI.contextName(for: profile.name)] + args,
                timeout: timeout
            )
        case .containerd:
            return try await colima.nerdctl(profile: profile.name, arguments: args)
        }
    }
}
