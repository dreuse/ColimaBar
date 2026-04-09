import Foundation

struct ProfileStartConfig {
    var name: String
    var cpus: Int
    var memoryGB: Int
    var diskGB: Int
    var runtime: ColimaProfile.Runtime
    var vmType: ColimaProfile.VMType
    var kubernetes: Bool = false

    var startArguments: [String] {
        var args: [String] = [
            "start",
            "-p", name,
            "--cpu", String(cpus),
            "--memory", String(memoryGB),
            "--disk", String(diskGB),
            "--runtime", runtime.rawValue,
            "--vm-type", vmType.rawValue
        ]
        if kubernetes { args.append("--kubernetes") }
        return args
    }

    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

struct ColimaCLI: Sendable {
    let executable: URL
    let runner = ProcessRunner.shared

    init?() {
        guard let url = BinaryResolver.locate("colima") else { return nil }
        self.executable = url
    }

    init(executable: URL) {
        self.executable = executable
    }

    func listProfiles() async throws -> [ColimaProfile] {
        let output = try await runner.runChecked(
            executableURL: executable,
            arguments: ["list", "--json"],
            timeout: 10
        )
        return ColimaProfile.decodeList(from: output)
    }

    func start(profile name: String) async throws {
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: ["start", "-p", name],
            timeout: 180
        )
    }

    func start(config: ProfileStartConfig) async throws {
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: config.startArguments,
            timeout: 300
        )
    }

    func stop(profile name: String) async throws {
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: ["stop", "-p", name],
            timeout: 120
        )
    }

    func delete(profile name: String) async throws {
        _ = try await runner.runChecked(
            executableURL: executable,
            arguments: ["delete", "-f", "-p", name],
            timeout: 120
        )
    }

    func nerdctl(profile name: String, arguments: [String]) async throws -> String {
        try await runner.runChecked(
            executableURL: executable,
            arguments: ["nerdctl", "-p", name, "--"] + arguments,
            timeout: 15
        )
    }
}
