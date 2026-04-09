import Foundation

struct ColimaProfile: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let status: Status
    let arch: String?
    let runtime: Runtime
    let cpus: Int?
    let memory: UInt64?
    let disk: UInt64?
    let address: String?
    let kubernetes: Bool

    var id: String { name }

    enum Status: String, Codable, Hashable, Sendable {
        case running = "Running"
        case stopped = "Stopped"
        case starting
        case stopping
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            switch raw.lowercased() {
            case "running": self = .running
            case "stopped": self = .stopped
            case "starting": self = .starting
            case "stopping": self = .stopping
            default: self = .unknown
            }
        }
    }

    enum Runtime: String, Codable, Hashable, CaseIterable, Sendable {
        case docker
        case containerd

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Runtime(rawValue: raw.lowercased()) ?? .docker
        }

        var displayName: String {
            switch self {
            case .docker: return "Docker"
            case .containerd: return "containerd"
            }
        }
    }

    enum VMType: String, Codable, Hashable, CaseIterable, Sendable {
        case vz
        case qemu

        var displayName: String {
            switch self {
            case .vz: return "Apple Virtualization (vz)"
            case .qemu: return "QEMU"
            }
        }

        static var platformDefault: VMType {
            #if arch(arm64)
            return .vz
            #else
            return .qemu
            #endif
        }
    }

    /// Accepts either a JSON array or NDJSON (one profile per line) since
    /// colima has shipped both shapes across versions.
    static func decodeList(from raw: String) -> [ColimaProfile] {
        let decoder = JSONDecoder()
        if let data = raw.data(using: .utf8),
           let array = try? decoder.decode([ColimaProfile].self, from: data) {
            return array
        }
        return raw
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(ColimaProfile.self, from: data)
            }
    }

    private enum CodingKeys: String, CodingKey {
        case name, status, arch, runtime, cpus, cpu, memory, disk, address, kubernetes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decode(Status.self, forKey: .status)
        self.arch = try container.decodeIfPresent(String.self, forKey: .arch)
        self.runtime = try container.decodeIfPresent(Runtime.self, forKey: .runtime) ?? .docker
        self.cpus = try container.decodeIfPresent(Int.self, forKey: .cpus)
            ?? container.decodeIfPresent(Int.self, forKey: .cpu)
        self.memory = try Self.decodeByteSize(container, key: .memory)
        self.disk = try Self.decodeByteSize(container, key: .disk)
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.kubernetes = try container.decodeIfPresent(Bool.self, forKey: .kubernetes) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(status.rawValue, forKey: .status)
        try container.encodeIfPresent(arch, forKey: .arch)
        try container.encode(runtime.rawValue, forKey: .runtime)
        try container.encodeIfPresent(cpus, forKey: .cpus)
        try container.encodeIfPresent(memory, forKey: .memory)
        try container.encodeIfPresent(disk, forKey: .disk)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(kubernetes, forKey: .kubernetes)
    }

    private static func decodeByteSize(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> UInt64? {
        if let n = try? container.decodeIfPresent(UInt64.self, forKey: key) { return n }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return UInt64(s) }
        return nil
    }
}

extension ColimaProfile {
    init(
        name: String,
        status: Status,
        arch: String? = "aarch64",
        runtime: Runtime = .docker,
        cpus: Int? = 2,
        memory: UInt64? = 4 * 1024 * 1024 * 1024,
        disk: UInt64? = 60 * 1024 * 1024 * 1024,
        address: String? = nil,
        kubernetes: Bool = false
    ) {
        self.name = name
        self.status = status
        self.arch = arch
        self.runtime = runtime
        self.cpus = cpus
        self.memory = memory
        self.disk = disk
        self.address = address
        self.kubernetes = kubernetes
    }

    var memoryGB: Double? { memory.map { Double($0) / 1_073_741_824 } }
    var diskGB: Double? { disk.map { Double($0) / 1_073_741_824 } }
}
