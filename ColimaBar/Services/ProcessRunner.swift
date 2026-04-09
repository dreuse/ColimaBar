import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }
}

enum ProcessRunnerError: LocalizedError, Equatable {
    case binaryNotFound(String)
    case timeout(String)
    case nonZeroExit(command: String, exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "Could not locate `\(name)` on disk. Install it via Homebrew and try again."
        case .timeout(let command):
            return "`\(command)` timed out."
        case .nonZeroExit(let command, let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "`\(command)` exited with code \(code)." + (trimmed.isEmpty ? "" : "\n\(trimmed)")
        }
    }
}

actor ProcessRunner {
    static let shared = ProcessRunner()

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        // GUI apps don't inherit a login shell's PATH, so child processes
        // (colima → lima/qemu/ssh) cannot find their helpers. Inject a sane one.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = Self.fallbackPath
        if let environment {
            for (key, value) in environment { env[key] = value }
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: ProcessResult.self) { group in
                group.addTask {
                    try process.run()
                    async let outData = Self.readToEnd(stdoutPipe.fileHandleForReading)
                    async let errData = Self.readToEnd(stderrPipe.fileHandleForReading)
                    let (out, err) = await (outData, errData)
                    process.waitUntilExit()
                    return ProcessResult(
                        stdout: String(data: out, encoding: .utf8) ?? "",
                        stderr: String(data: err, encoding: .utf8) ?? "",
                        exitCode: process.terminationStatus
                    )
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if process.isRunning { process.terminate() }
                    throw ProcessRunnerError.timeout(
                        executableURL.lastPathComponent + " " + arguments.joined(separator: " ")
                    )
                }

                let first = try await group.next()!
                group.cancelAll()
                return first
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    func runChecked(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval = 30
    ) async throws -> String {
        let result = try await run(
            executableURL: executableURL,
            arguments: arguments,
            timeout: timeout
        )
        guard result.succeeded else {
            throw ProcessRunnerError.nonZeroExit(
                command: executableURL.lastPathComponent + " " + arguments.joined(separator: " "),
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result.stdout
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let data = (try? handle.readToEnd()) ?? Data()
                continuation.resume(returning: data)
            }
        }
    }

    static let fallbackPath = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ].joined(separator: ":")
}

enum BinaryResolver {
    static let searchPaths: [String] = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        (NSHomeDirectory() as NSString).appendingPathComponent(".colima/bin"),
        "/usr/bin",
        "/bin"
    ]

    static func locate(_ name: String) -> URL? {
        let fm = FileManager.default
        for dir in searchPaths {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
