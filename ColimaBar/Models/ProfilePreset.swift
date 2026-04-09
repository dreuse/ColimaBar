import Foundation

struct ProfilePreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var cpus: Int
    var memoryGB: Int
    var diskGB: Int
    var runtime: ColimaProfile.Runtime
    var vmType: ColimaProfile.VMType
    var kubernetes: Bool
    var isBuiltIn: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, cpus, memoryGB, diskGB, runtime, vmType, kubernetes, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.cpus = try container.decode(Int.self, forKey: .cpus)
        self.memoryGB = try container.decode(Int.self, forKey: .memoryGB)
        self.diskGB = try container.decode(Int.self, forKey: .diskGB)
        self.runtime = try container.decode(ColimaProfile.Runtime.self, forKey: .runtime)
        self.vmType = try container.decode(ColimaProfile.VMType.self, forKey: .vmType)
        self.kubernetes = try container.decodeIfPresent(Bool.self, forKey: .kubernetes) ?? false
        self.isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
    }

    init(
        id: UUID,
        name: String,
        cpus: Int,
        memoryGB: Int,
        diskGB: Int,
        runtime: ColimaProfile.Runtime,
        vmType: ColimaProfile.VMType,
        kubernetes: Bool = false,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.name = name
        self.cpus = cpus
        self.memoryGB = memoryGB
        self.diskGB = diskGB
        self.runtime = runtime
        self.vmType = vmType
        self.kubernetes = kubernetes
        self.isBuiltIn = isBuiltIn
    }

    static let webDev = ProfilePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Web dev",
        cpus: 2,
        memoryGB: 4,
        diskGB: 60,
        runtime: .docker,
        vmType: .platformDefault,
        isBuiltIn: true
    )

    static let k8sLab = ProfilePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Kubernetes lab",
        cpus: 4,
        memoryGB: 8,
        diskGB: 80,
        runtime: .containerd,
        vmType: .platformDefault,
        kubernetes: true,
        isBuiltIn: true
    )

    static let minimal = ProfilePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Minimal",
        cpus: 1,
        memoryGB: 2,
        diskGB: 20,
        runtime: .docker,
        vmType: .platformDefault,
        isBuiltIn: true
    )

    static let builtIns: [ProfilePreset] = [.webDev, .k8sLab, .minimal]
}

@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var customPresets: [ProfilePreset] = []

    private let storageKey = "profile.customPresets"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var all: [ProfilePreset] { ProfilePreset.builtIns + customPresets }

    func save(_ preset: ProfilePreset) {
        let updated = ProfilePreset(
            id: preset.id,
            name: preset.name,
            cpus: preset.cpus,
            memoryGB: preset.memoryGB,
            diskGB: preset.diskGB,
            runtime: preset.runtime,
            vmType: preset.vmType,
            kubernetes: preset.kubernetes,
            isBuiltIn: false
        )
        if let idx = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[idx] = updated
        } else {
            customPresets.append(updated)
        }
        persist()
    }

    func delete(_ preset: ProfilePreset) {
        guard !preset.isBuiltIn else { return }
        customPresets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ProfilePreset].self, from: data) else { return }
        customPresets = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customPresets) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
