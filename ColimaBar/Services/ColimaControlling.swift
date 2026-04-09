import Foundation

protocol ColimaControlling: Sendable {
    func listProfiles() async throws -> [ColimaProfile]
    func start(profile: String) async throws
    func start(config: ProfileStartConfig) async throws
    func stop(profile: String) async throws
    func delete(profile: String) async throws
    func listContainers(for profile: ColimaProfile) async throws -> [Container]
    func currentContext() async -> String?
    func useContext(for profile: String) async throws

    func stopContainer(_ id: String, on profile: ColimaProfile) async throws
    func startContainer(_ id: String, on profile: ColimaProfile) async throws
    func restartContainer(_ id: String, on profile: ColimaProfile) async throws
    func logsSnapshot(container id: String, on profile: ColimaProfile, tail: Int) async throws -> String

    func currentKubeContext() async -> String?
    func useKubeContext(for profile: String) async throws
}

struct LiveColimaController: ColimaControlling {
    let colima: ColimaCLI
    let containers: ContainerCLI
    let dockerContext: DockerContextCLI
    let actions: ContainerActionsCLI
    let kubectl: KubectlContextCLI

    init?() {
        guard let colima = ColimaCLI() else { return nil }
        self.colima = colima
        self.containers = ContainerCLI(colima: colima)
        self.dockerContext = DockerContextCLI()
        self.actions = ContainerActionsCLI(colima: colima)
        self.kubectl = KubectlContextCLI()
    }

    func listProfiles() async throws -> [ColimaProfile] {
        try await colima.listProfiles()
    }

    func start(profile: String) async throws {
        try await colima.start(profile: profile)
    }

    func start(config: ProfileStartConfig) async throws {
        try await colima.start(config: config)
    }

    func stop(profile: String) async throws {
        try await colima.stop(profile: profile)
    }

    func delete(profile: String) async throws {
        try await colima.delete(profile: profile)
    }

    func listContainers(for profile: ColimaProfile) async throws -> [Container] {
        try await containers.listContainers(for: profile)
    }

    func currentContext() async -> String? {
        await dockerContext.currentContext()
    }

    func useContext(for profile: String) async throws {
        try await dockerContext.useContext(for: profile)
    }

    func stopContainer(_ id: String, on profile: ColimaProfile) async throws {
        try await actions.stop(container: id, on: profile)
    }

    func startContainer(_ id: String, on profile: ColimaProfile) async throws {
        try await actions.start(container: id, on: profile)
    }

    func restartContainer(_ id: String, on profile: ColimaProfile) async throws {
        try await actions.restart(container: id, on: profile)
    }

    func logsSnapshot(container id: String, on profile: ColimaProfile, tail: Int) async throws -> String {
        try await actions.logsSnapshot(container: id, on: profile, tail: tail)
    }

    func currentKubeContext() async -> String? {
        await kubectl.currentContext()
    }

    func useKubeContext(for profile: String) async throws {
        try await kubectl.useContext(for: profile)
    }
}
