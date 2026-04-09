import Foundation

struct ResourceSample: Equatable, Sendable {
    let cpuPercent: Double  // 0...100
    let memoryPercent: Double
    let diskPercent: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64
    let diskUsedBytes: UInt64
    let diskTotalBytes: UInt64
    let capturedAt: Date

    var memoryUsedGB: Double { Double(memoryUsedBytes) / 1_073_741_824 }
    var memoryTotalGB: Double { Double(memoryTotalBytes) / 1_073_741_824 }
    var diskUsedGB: Double { Double(diskUsedBytes) / 1_073_741_824 }
    var diskTotalGB: Double { Double(diskTotalBytes) / 1_073_741_824 }
}

/// CPU delta requires two /proc/stat snapshots, so the prior reading is cached
/// per profile between calls.
actor ResourceSampler {
    static let shared = ResourceSampler()

    private let runner = ProcessRunner.shared
    private var lastCPUTotals: [String: (total: UInt64, idle: UInt64)] = [:]
    private var lastSample: [String: ResourceSample] = [:]

    func sample(for profile: ColimaProfile) async -> ResourceSample? {
        guard profile.status == .running else {
            lastCPUTotals.removeValue(forKey: profile.name)
            return nil
        }
        guard let colima = BinaryResolver.locate("colima") else { return nil }

        let script = "cat /proc/stat | head -n 1; free -b | awk '/^Mem:/ {print $2, $3}'; df -B1 / | awk 'NR==2 {print $2, $3}'"

        do {
            let output = try await runner.runChecked(
                executableURL: colima,
                arguments: ["ssh", "-p", profile.name, "--", "sh", "-c", script],
                timeout: 8
            )
            let parsed = parse(output: output, profileName: profile.name)
            if let parsed { lastSample[profile.name] = parsed }
            return parsed ?? lastSample[profile.name]
        } catch {
            return lastSample[profile.name]
        }
    }

    func clearCache(for profileName: String) {
        lastCPUTotals.removeValue(forKey: profileName)
        lastSample.removeValue(forKey: profileName)
    }

    func parse(output: String, profileName: String) -> ResourceSample? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count >= 3 else { return nil }

        // /proc/stat first line: cpu  user nice system idle iowait irq softirq steal guest guest_nice
        let cpuFields = lines[0].split(separator: " ", omittingEmptySubsequences: true)
        guard cpuFields.count >= 5, cpuFields[0] == "cpu" else { return nil }
        let numbers = cpuFields.dropFirst().compactMap { UInt64($0) }
        guard numbers.count >= 4 else { return nil }
        let idle = numbers[3]
        let total = numbers.reduce(0, +)

        let cpuPercent: Double
        if let previous = lastCPUTotals[profileName],
           total >= previous.total,
           idle >= previous.idle {
            let totalDelta = total - previous.total
            let idleDelta = idle - previous.idle
            cpuPercent = totalDelta > 0
                ? max(0, min(100, Double(totalDelta - idleDelta) / Double(totalDelta) * 100))
                : 0
        } else {
            // First sample, or counter wrapped / VM rebooted — reset baseline.
            cpuPercent = 0
        }
        lastCPUTotals[profileName] = (total, idle)

        // Memory
        let memFields = lines[1].split(separator: " ", omittingEmptySubsequences: true)
        guard memFields.count >= 2,
              let memTotal = Double(memFields[0]),
              let memUsed = Double(memFields[1]),
              memTotal > 0 else { return nil }
        let memPercent = memUsed / memTotal * 100

        // Disk
        let diskFields = lines[2].split(separator: " ", omittingEmptySubsequences: true)
        guard diskFields.count >= 2,
              let diskTotal = Double(diskFields[0]),
              let diskUsed = Double(diskFields[1]),
              diskTotal > 0 else { return nil }
        let diskPercent = diskUsed / diskTotal * 100

        return ResourceSample(
            cpuPercent: cpuPercent,
            memoryPercent: memPercent,
            diskPercent: diskPercent,
            memoryUsedBytes: UInt64(memUsed),
            memoryTotalBytes: UInt64(memTotal),
            diskUsedBytes: UInt64(diskUsed),
            diskTotalBytes: UInt64(diskTotal),
            capturedAt: Date()
        )
    }
}
