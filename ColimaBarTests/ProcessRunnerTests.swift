import XCTest
@testable import ColimaBar

final class ProcessRunnerTests: XCTestCase {

    private let sh = URL(fileURLWithPath: "/bin/sh")
    private let sleep = URL(fileURLWithPath: "/bin/sleep")
    private let ls = URL(fileURLWithPath: "/bin/ls")

    func testRunChecked_returnsStdoutOnSuccess() async throws {
        let out = try await ProcessRunner.shared.runChecked(
            executableURL: sh,
            arguments: ["-c", "echo hello"]
        )
        XCTAssertEqual(out.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testRunChecked_throwsNonZeroExitWithStderrInMessage() async {
        do {
            _ = try await ProcessRunner.shared.runChecked(
                executableURL: sh,
                arguments: ["-c", "echo boom >&2; exit 7"]
            )
            XCTFail("expected throw")
        } catch let error as ProcessRunnerError {
            guard case .nonZeroExit(_, let code, let stderr) = error else {
                return XCTFail("expected .nonZeroExit, got \(error)")
            }
            XCTAssertEqual(code, 7)
            XCTAssertTrue(stderr.contains("boom"))
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testRun_timesOutAndTerminatesChild() async {
        do {
            _ = try await ProcessRunner.shared.run(
                executableURL: sleep,
                arguments: ["10"],
                timeout: 0.3
            )
            XCTFail("expected timeout")
        } catch let error as ProcessRunnerError {
            guard case .timeout = error else {
                return XCTFail("expected .timeout, got \(error)")
            }
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testRun_capturesLargeStdoutWithoutDeadlock() async throws {
        // ~200 KB of stdout — previously would deadlock if pipes weren't drained concurrently.
        let result = try await ProcessRunner.shared.run(
            executableURL: sh,
            arguments: ["-c", "yes x | head -c 200000"]
        )
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertGreaterThanOrEqual(result.stdout.count, 199_000)
    }

    func testRun_capturesStdoutAndStderrIndependently() async throws {
        let result = try await ProcessRunner.shared.run(
            executableURL: sh,
            arguments: ["-c", "echo out; echo err >&2"]
        )
        XCTAssertTrue(result.stdout.contains("out"))
        XCTAssertTrue(result.stderr.contains("err"))
        XCTAssertEqual(result.exitCode, 0)
    }

    func testRun_respectsTaskCancellation() async {
        let task = Task {
            try await ProcessRunner.shared.run(
                executableURL: sleep,
                arguments: ["10"],
                timeout: 30
            )
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("expected cancellation to terminate the child and throw")
        } catch {
            // cancellation -> terminated child -> non-zero exit or cancellation error are both fine
        }
    }

    func testBinaryResolver_locatesExistingBinary() {
        let resolved = BinaryResolver.locate("ls")
        XCTAssertNotNil(resolved)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: resolved?.path ?? ""))
    }

    func testBinaryResolver_returnsNilForMissingBinary() {
        XCTAssertNil(BinaryResolver.locate("definitely-not-a-real-binary-xyz-12345"))
    }

    func testProcessResult_succeededReflectsExitCode() {
        XCTAssertTrue(ProcessResult(stdout: "", stderr: "", exitCode: 0).succeeded)
        XCTAssertFalse(ProcessResult(stdout: "", stderr: "", exitCode: 1).succeeded)
    }
}
