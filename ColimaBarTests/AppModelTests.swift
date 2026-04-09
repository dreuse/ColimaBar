import XCTest
@testable import ColimaBar

@MainActor
final class AppModelTests: XCTestCase {

    func testRefreshPopulatesProfilesOnSuccess() async {
        let fake = FakeColimaController()
        fake.profiles = [
            ColimaProfile(name: "default", status: .running),
            ColimaProfile(name: "work", status: .stopped)
        ]
        fake.activeContext = "colima"
        let model = AppModel(controller: fake)

        await model.refresh()

        XCTAssertEqual(model.profiles.map(\.name), ["default", "work"])
        XCTAssertEqual(model.activeContext, "colima")
        XCTAssertNil(model.lastError)
        XCTAssertFalse(model.isLoading)
    }

    func testRefreshSortsProfilesByName() async {
        let fake = FakeColimaController()
        fake.profiles = [
            ColimaProfile(name: "zeta", status: .running),
            ColimaProfile(name: "alpha", status: .stopped),
            ColimaProfile(name: "mid", status: .running)
        ]
        let model = AppModel(controller: fake)

        await model.refresh()

        XCTAssertEqual(model.profiles.map(\.name), ["alpha", "mid", "zeta"])
    }

    func testRefreshSurfacesErrorOnFailure() async {
        let fake = FakeColimaController()
        fake.listProfilesError = ProcessRunnerError.nonZeroExit(
            command: "colima list",
            exitCode: 2,
            stderr: "permission denied"
        )
        let model = AppModel(controller: fake)

        await model.refresh()

        XCTAssertNotNil(model.lastError)
        XCTAssertTrue(model.lastError?.contains("permission denied") ?? false)
    }

    func testRefreshClearsPreviousErrorOnSuccess() async {
        let fake = FakeColimaController()
        fake.listProfilesError = ProcessRunnerError.binaryNotFound("colima")
        let model = AppModel(controller: fake)

        await model.refresh()
        XCTAssertNotNil(model.lastError)

        fake.listProfilesError = nil
        fake.profiles = [ColimaProfile(name: "default", status: .running)]
        await model.refresh()

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.profiles.count, 1)
    }

    func testRefreshIsNoOpWhenMissingColima() async {
        let model = AppModel(controller: nil)
        XCTAssertTrue(model.missingColima)

        await model.refresh()

        XCTAssertTrue(model.profiles.isEmpty)
        XCTAssertFalse(model.isLoading)
    }

    func testSummaryReportsRunningCount() async {
        let fake = FakeColimaController()
        fake.profiles = [
            ColimaProfile(name: "a", status: .running),
            ColimaProfile(name: "b", status: .running),
            ColimaProfile(name: "c", status: .stopped)
        ]
        let model = AppModel(controller: fake)
        await model.refresh()

        XCTAssertEqual(model.runningCount, 2)
        XCTAssertEqual(model.stoppedCount, 1)
        if case .anyRunning(let count) = model.summary {
            XCTAssertEqual(count, 2)
        } else {
            XCTFail("expected .anyRunning")
        }
    }

    func testSummaryReportsAllStoppedWhenNothingRunning() async {
        let fake = FakeColimaController()
        fake.profiles = [ColimaProfile(name: "a", status: .stopped)]
        let model = AppModel(controller: fake)
        await model.refresh()

        if case .allStopped = model.summary {} else { XCTFail("expected .allStopped") }
    }

    func testStartProfileClearsInFlightOnSuccess() async {
        let fake = FakeColimaController()
        fake.profiles = [ColimaProfile(name: "dev", status: .stopped)]
        let model = AppModel(controller: fake)

        model.startProfile("dev")
        await waitForInFlightClear(model, name: "dev")

        XCTAssertFalse(model.isBusy("dev"))
        XCTAssertEqual(fake.startedProfiles, ["dev"])
        XCTAssertNil(model.lastError)
    }

    func testStartProfileSurfacesErrorAndClearsInFlightOnFailure() async {
        let fake = FakeColimaController()
        fake.startError = ProcessRunnerError.nonZeroExit(
            command: "colima start",
            exitCode: 1,
            stderr: "disk full"
        )
        let model = AppModel(controller: fake)

        model.startProfile("dev")
        await waitForInFlightClear(model, name: "dev")

        XCTAssertFalse(model.isBusy("dev"))
        XCTAssertNotNil(model.lastError)
        XCTAssertTrue(model.lastError?.contains("disk full") ?? false)
    }

    func testStopProfileCallsController() async {
        let fake = FakeColimaController()
        let model = AppModel(controller: fake)

        model.stopProfile("default")
        await waitForInFlightClear(model, name: "default")

        XCTAssertEqual(fake.stoppedProfiles, ["default"])
    }

    func testDeleteProfileCallsController() async {
        let fake = FakeColimaController()
        let model = AppModel(controller: fake)

        model.deleteProfile("old")
        await waitForInFlightClear(model, name: "old")

        XCTAssertEqual(fake.deletedProfiles, ["old"])
    }

    func testCreateProfilePassesConfigAndRefreshes() async throws {
        let fake = FakeColimaController()
        let model = AppModel(controller: fake)
        let config = ProfileStartConfig(
            name: "dev",
            cpus: 4,
            memoryGB: 8,
            diskGB: 80,
            runtime: .docker,
            vmType: .vz
        )

        fake.profiles = [ColimaProfile(name: "dev", status: .running)]
        try await model.createProfile(config)

        XCTAssertEqual(fake.startedConfigs.count, 1)
        XCTAssertEqual(fake.startedConfigs.first?.name, "dev")
        XCTAssertFalse(model.isBusy("dev"))
        XCTAssertEqual(model.profiles.map(\.name), ["dev"])
    }

    func testCreateProfileRethrowsAndSetsLastErrorOnFailure() async {
        let fake = FakeColimaController()
        fake.startError = ProcessRunnerError.nonZeroExit(
            command: "colima start",
            exitCode: 1,
            stderr: "bad config"
        )
        let model = AppModel(controller: fake)
        let config = ProfileStartConfig(
            name: "bad",
            cpus: 1,
            memoryGB: 1,
            diskGB: 10,
            runtime: .docker,
            vmType: .qemu
        )

        do {
            try await model.createProfile(config)
            XCTFail("expected throw")
        } catch {
            // expected
        }

        XCTAssertFalse(model.isBusy("bad"))
        XCTAssertNotNil(model.lastError)
    }

    func testSetActiveOnRunningProfileSwitchesContext() async {
        let fake = FakeColimaController()
        let profile = ColimaProfile(name: "work", status: .running)
        fake.profiles = [profile]
        fake.activeContext = "colima"
        let model = AppModel(controller: fake)
        await model.refresh()

        model.setActive(profile)
        await waitForInFlightClear(model, name: "work")

        XCTAssertEqual(fake.contextsSet, ["work"])
        XCTAssertEqual(fake.startedProfiles, [])
        XCTAssertEqual(model.activeContext, "colima-work")
    }

    func testSetActiveOnStoppedProfileStartsThenSwitches() async {
        let fake = FakeColimaController()
        let profile = ColimaProfile(name: "work", status: .stopped)
        fake.profiles = [profile]
        let model = AppModel(controller: fake)
        await model.refresh()

        model.setActive(profile)
        await waitForInFlightClear(model, name: "work")

        XCTAssertEqual(fake.startedProfiles, ["work"])
        XCTAssertEqual(fake.contextsSet, ["work"])
    }

    func testSetActiveClearsInFlightOnUseContextFailure() async {
        let fake = FakeColimaController()
        let profile = ColimaProfile(name: "work", status: .running)
        fake.profiles = [profile]
        fake.useContextError = ProcessRunnerError.nonZeroExit(
            command: "docker context use",
            exitCode: 1,
            stderr: "no such context"
        )
        let model = AppModel(controller: fake)
        await model.refresh()

        model.setActive(profile)
        await waitForInFlightClear(model, name: "work")

        XCTAssertFalse(model.isBusy("work"))
        XCTAssertNotNil(model.lastError)
    }

    func testListContainersReturnsSuccess() async {
        let fake = FakeColimaController()
        let profile = ColimaProfile(name: "default", status: .running)
        fake.containersByProfile["default"] = [
            Container(id: "abc", name: "web", image: "nginx", status: "Up", ports: nil)
        ]
        let model = AppModel(controller: fake)

        switch await model.listContainers(for: profile) {
        case .success(let list):
            XCTAssertEqual(list.map(\.name), ["web"])
        case .failure(let msg):
            XCTFail("expected success, got \(msg)")
        }
    }

    func testListContainersReturnsFailureOnError() async {
        let fake = FakeColimaController()
        let profile = ColimaProfile(name: "default", status: .running)
        fake.listContainersError = ProcessRunnerError.binaryNotFound("docker")
        let model = AppModel(controller: fake)

        switch await model.listContainers(for: profile) {
        case .success:
            XCTFail("expected failure")
        case .failure(let msg):
            XCTAssertTrue(msg.contains("docker"))
        }
    }

    func testDismissErrorClearsLastError() async {
        let fake = FakeColimaController()
        fake.listProfilesError = ProcessRunnerError.binaryNotFound("colima")
        let model = AppModel(controller: fake)
        await model.refresh()
        XCTAssertNotNil(model.lastError)

        model.dismissError()
        XCTAssertNil(model.lastError)
    }

    // MARK: - Helpers

    /// Profile ops run in a detached Task; wait until the busy state clears.
    private func waitForInFlightClear(_ model: AppModel, name: String, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while model.isBusy(name) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
