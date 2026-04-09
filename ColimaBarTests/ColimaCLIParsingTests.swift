import XCTest
@testable import ColimaBar

final class ColimaCLIParsingTests: XCTestCase {

    // MARK: - colima list --json

    func testParsesSingleRunningProfile() throws {
        let ndjson = #"""
        {"name":"default","status":"Running","arch":"aarch64","runtime":"docker","cpus":4,"memory":8589934592,"disk":64424509440,"address":"192.168.106.2"}
        """#
        let profiles = ColimaProfile.decodeList(from: ndjson)
        XCTAssertEqual(profiles.count, 1)
        let p = try XCTUnwrap(profiles.first)
        XCTAssertEqual(p.name, "default")
        XCTAssertEqual(p.status, .running)
        XCTAssertEqual(p.runtime, .docker)
        XCTAssertEqual(p.cpus, 4)
        XCTAssertEqual(p.memory, 8_589_934_592)
        XCTAssertEqual(p.disk, 64_424_509_440)
        XCTAssertEqual(p.memoryGB, 8.0, accuracy: 0.01)
        XCTAssertEqual(p.diskGB ?? 0, 60.0, accuracy: 0.5)
    }

    func testParsesMultipleProfilesFromNDJSON() {
        let ndjson = """
        {"name":"default","status":"Running","runtime":"docker","cpus":2,"memory":4294967296,"disk":64424509440}
        {"name":"work","status":"Stopped","runtime":"containerd","cpus":4,"memory":8589934592,"disk":107374182400}
        {"name":"playground","status":"Running","runtime":"docker","cpus":2,"memory":2147483648,"disk":32212254720}
        """
        let profiles = ColimaProfile.decodeList(from: ndjson)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles.map { $0.name }, ["default", "work", "playground"])
        XCTAssertEqual(profiles.map { $0.status }, [.running, .stopped, .running])
        XCTAssertEqual(profiles[1].runtime, .containerd)
    }

    func testHandlesUnknownStatusGracefully() {
        let ndjson = #"{"name":"broken","status":"SomethingNew","runtime":"docker"}"#
        let profiles = ColimaProfile.decodeList(from: ndjson)
        XCTAssertEqual(profiles.first?.status, .unknown)
    }

    func testSkipsMalformedLines() {
        let ndjson = """
        {"name":"good","status":"Running","runtime":"docker"}
        this is not json
        {"name":"also-good","status":"Stopped","runtime":"docker"}
        """
        let profiles = ColimaProfile.decodeList(from: ndjson)
        XCTAssertEqual(profiles.count, 2)
    }

    func testStatusPillStatusesAreDistinct() {
        let ndjson = """
        {"name":"a","status":"Running","runtime":"docker"}
        {"name":"b","status":"Stopped","runtime":"docker"}
        {"name":"c","status":"starting","runtime":"docker"}
        """
        let profiles = ColimaProfile.decodeList(from: ndjson)
        XCTAssertEqual(profiles.map(\.status), [.running, .stopped, .starting])
    }

    // MARK: - docker ps --format '{{json .}}'

    func testParsesDockerPsOutput() {
        // Shape emitted by `docker ps --format '{{json .}}'`. Fields are PascalCase.
        let ndjson = #"""
        {"ID":"abc123","Names":"sleepy_nobel","Image":"nginx:latest","Status":"Up 5 minutes","Ports":"0.0.0.0:8080->80/tcp"}
        {"ID":"def456","Names":"busy_hopper","Image":"redis:7","Status":"Up 2 hours","Ports":""}
        """#
        let containers = Container.decodeList(from: ndjson)
        XCTAssertEqual(containers.count, 2)
        XCTAssertEqual(containers[0].name, "sleepy_nobel")
        XCTAssertEqual(containers[0].image, "nginx:latest")
        XCTAssertEqual(containers[0].ports, "0.0.0.0:8080->80/tcp")
        XCTAssertNil(containers[1].ports) // empty string normalized to nil
    }

    func testParsesNerdctlPsOutput() {
        // nerdctl uses lowercase keys.
        let ndjson = #"""
        {"id":"xyz789","names":"peaceful_curie","image":"alpine:3.19","status":"Up 10 seconds","ports":""}
        """#
        let containers = Container.decodeList(from: ndjson)
        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].id, "xyz789")
        XCTAssertEqual(containers[0].image, "alpine:3.19")
    }

    // MARK: - ProfileStartConfig arguments

    func testProfileStartConfigBuildsExpectedArguments() {
        let config = ProfileStartConfig(
            name: "dev",
            cpus: 4,
            memoryGB: 8,
            diskGB: 80,
            runtime: .docker,
            vmType: .vz
        )
        XCTAssertEqual(
            config.startArguments,
            [
                "start",
                "-p", "dev",
                "--cpu", "4",
                "--memory", "8",
                "--disk", "80",
                "--runtime", "docker",
                "--vm-type", "vz"
            ]
        )
    }

    func testProfileStartConfigRespectsContainerdRuntime() {
        let config = ProfileStartConfig(
            name: "work",
            cpus: 2,
            memoryGB: 4,
            diskGB: 60,
            runtime: .containerd,
            vmType: .qemu
        )
        XCTAssertEqual(config.startArguments.dropFirst(9).first, "containerd")
        XCTAssertEqual(config.startArguments.last, "qemu")
    }

    // MARK: - DockerContextCLI context naming

    func testDockerContextNameForDefaultProfile() {
        XCTAssertEqual(DockerContextCLI.contextName(for: "default"), "colima")
    }

    func testDockerContextNameForNamedProfile() {
        XCTAssertEqual(DockerContextCLI.contextName(for: "work"), "colima-work")
        XCTAssertEqual(DockerContextCLI.contextName(for: "my-dev_1"), "colima-my-dev_1")
    }

    // MARK: - Legacy / loose decoder branches

    func testDecodesLegacyCpuSingularKey() {
        let ndjson = #"{"name":"legacy","status":"Running","runtime":"docker","cpu":6}"#
        let profile = ColimaProfile.decodeList(from: ndjson).first
        XCTAssertEqual(profile?.cpus, 6)
    }

    func testDecodesStringEncodedMemoryAndDisk() {
        let ndjson = #"{"name":"strmem","status":"Running","runtime":"docker","memory":"8589934592","disk":"64424509440"}"#
        let profile = ColimaProfile.decodeList(from: ndjson).first
        XCTAssertEqual(profile?.memory, 8_589_934_592)
        XCTAssertEqual(profile?.disk, 64_424_509_440)
    }

    func testDefaultsRuntimeToDockerWhenMissing() {
        let ndjson = #"{"name":"noruntime","status":"Running"}"#
        let profile = ColimaProfile.decodeList(from: ndjson).first
        XCTAssertEqual(profile?.runtime, .docker)
    }

    func testDecodeByteSizeReturnsNilForGarbageString() {
        let ndjson = #"{"name":"bad","status":"Running","runtime":"docker","memory":"not-a-number"}"#
        let profile = ColimaProfile.decodeList(from: ndjson).first
        XCTAssertNil(profile?.memory)
    }

    func testDecodesJSONArrayForm() {
        // Older (or future) colima versions may emit a single JSON array.
        let json = """
        [
          {"name":"a","status":"Running","runtime":"docker"},
          {"name":"b","status":"Stopped","runtime":"containerd"}
        ]
        """
        let profiles = ColimaProfile.decodeList(from: json)
        XCTAssertEqual(profiles.map(\.name), ["a", "b"])
        XCTAssertEqual(profiles.last?.runtime, .containerd)
    }

    // MARK: - Container normalization

    func testDropsDockerRowWhenRequiredFieldMissing() {
        let ndjson = #"{"ID":"a","Names":"n","Image":"i"}"#  // no Status
        XCTAssertEqual(Container.decodeList(from: ndjson).count, 0)
    }

    func testDropsNerdctlRowWhenIdMissing() {
        let ndjson = #"{"names":"n","image":"i","status":"Up"}"#
        XCTAssertEqual(Container.decodeList(from: ndjson).count, 0)
    }

    func testNerdctlPortsNormalizesEmptyStringToNil() {
        let ndjson = #"{"id":"x","names":"n","image":"i","status":"Up","ports":""}"#
        let container = Container.decodeList(from: ndjson).first
        XCTAssertNil(container?.ports)
    }

    // MARK: - ProfileStartConfig.isValidName

    func testNameValidationRejectsEmpty() {
        XCTAssertFalse(ProfileStartConfig.isValidName(""))
    }

    func testNameValidationRejectsSpaces() {
        XCTAssertFalse(ProfileStartConfig.isValidName("my dev"))
    }

    func testNameValidationRejectsSlashes() {
        XCTAssertFalse(ProfileStartConfig.isValidName("../evil"))
        XCTAssertFalse(ProfileStartConfig.isValidName("a/b"))
    }

    func testNameValidationRejectsUnicodeAndPunctuation() {
        XCTAssertFalse(ProfileStartConfig.isValidName("dev!"))
        XCTAssertFalse(ProfileStartConfig.isValidName("🚀"))
        XCTAssertFalse(ProfileStartConfig.isValidName("dev.main"))
    }

    func testNameValidationAcceptsAllowedCharacters() {
        XCTAssertTrue(ProfileStartConfig.isValidName("default"))
        XCTAssertTrue(ProfileStartConfig.isValidName("dev-1"))
        XCTAssertTrue(ProfileStartConfig.isValidName("my_profile_2"))
        XCTAssertTrue(ProfileStartConfig.isValidName("Mixed-Case_99"))
    }
}
