import Foundation

struct ContainerCLI: Sendable {
    let colima: ColimaCLI
    let docker: URL?
    let runner = ProcessRunner.shared

    init(colima: ColimaCLI) {
        self.colima = colima
        self.docker = BinaryResolver.locate("docker")
    }

    func listContainers(for profile: ColimaProfile) async throws -> [Container] {
        guard profile.status == .running else { return [] }

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
    }
}
