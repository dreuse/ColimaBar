import Foundation
@testable import ColimaBar

final class FakeColimaController: ColimaControlling, @unchecked Sendable {

    var profiles: [ColimaProfile] = []
    var activeContext: String? = "colima"
    var containersByProfile: [String: [Container]] = [:]

    var listProfilesError: Error?
    var startError: Error?
    var stopError: Error?
    var deleteError: Error?
    var useContextError: Error?
    var listContainersError: Error?
    var containerActionError: Error?
    var logsSnapshotError: Error?
    var logsText: String = ""

    private(set) var startedProfiles: [String] = []
    private(set) var startedConfigs: [ProfileStartConfig] = []
    private(set) var stoppedProfiles: [String] = []
    private(set) var deletedProfiles: [String] = []
    private(set) var contextsSet: [String] = []
    private(set) var stoppedContainers: [String] = []
    private(set) var startedContainers: [String] = []
    private(set) var restartedContainers: [String] = []

    func listProfiles() async throws -> [ColimaProfile] {
        if let listProfilesError { throw listProfilesError }
        return profiles
    }

    func start(profile: String) async throws {
        if let startError { throw startError }
        startedProfiles.append(profile)
    }

    func start(config: ProfileStartConfig) async throws {
        if let startError { throw startError }
        startedConfigs.append(config)
    }

    func stop(profile: String) async throws {
        if let stopError { throw stopError }
        stoppedProfiles.append(profile)
    }

    func delete(profile: String) async throws {
        if let deleteError { throw deleteError }
        deletedProfiles.append(profile)
    }

    func listContainers(for profile: ColimaProfile) async throws -> [Container] {
        if let listContainersError { throw listContainersError }
        return containersByProfile[profile.name] ?? []
    }

    func currentContext() async -> String? {
        activeContext
    }

    func useContext(for profile: String) async throws {
        if let useContextError { throw useContextError }
        contextsSet.append(profile)
        activeContext = DockerContextCLI.contextName(for: profile)
    }

    func stopContainer(_ id: String, on profile: ColimaProfile) async throws {
        if let containerActionError { throw containerActionError }
        stoppedContainers.append(id)
    }

    func startContainer(_ id: String, on profile: ColimaProfile) async throws {
        if let containerActionError { throw containerActionError }
        startedContainers.append(id)
    }

    func restartContainer(_ id: String, on profile: ColimaProfile) async throws {
        if let containerActionError { throw containerActionError }
        restartedContainers.append(id)
    }

    func logsSnapshot(container id: String, on profile: ColimaProfile, tail: Int) async throws -> String {
        if let logsSnapshotError { throw logsSnapshotError }
        return logsText
    }

    var currentKubeContextValue: String? = nil
    var useKubeContextError: Error?
    private(set) var kubeContextsSet: [String] = []

    func currentKubeContext() async -> String? {
        currentKubeContextValue
    }

    func useKubeContext(for profile: String) async throws {
        if let useKubeContextError { throw useKubeContextError }
        kubeContextsSet.append(profile)
        currentKubeContextValue = KubectlContextCLI.contextName(for: profile)
    }
}
