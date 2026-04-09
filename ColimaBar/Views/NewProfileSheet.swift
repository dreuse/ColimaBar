import SwiftUI

struct NewProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModel: AppModel
    @StateObject private var presetStore = PresetStore()

    @State private var name: String = ""
    @State private var cpus: Int = 2
    @State private var memoryGB: Int = 4
    @State private var diskGB: Int = 60
    @State private var runtime: ColimaProfile.Runtime = .docker
    @State private var vmType: ColimaProfile.VMType = .platformDefault
    @State private var kubernetes: Bool = false
    @State private var selectedPresetID: UUID?

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var hostCPUCount: Int { ProcessInfo.processInfo.activeProcessorCount }
    private var hostRAMGB: Int { max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)) }

    private var nameIsValid: Bool {
        ProfileStartConfig.isValidName(name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 380)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: IconRenderer.colorIcon(size: 28))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("New Profile").font(.headline)
                Text("Create a new Colima instance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Preset") {
                Picker("", selection: $selectedPresetID) {
                    Text("Custom").tag(UUID?.none)
                    Section("Built-in") {
                        ForEach(ProfilePreset.builtIns) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }
                    if !presetStore.customPresets.isEmpty {
                        Section("Saved") {
                            ForEach(presetStore.customPresets) { preset in
                                Text(preset.name).tag(Optional(preset.id))
                            }
                        }
                    }
                }
                .labelsHidden()
                .onChange(of: selectedPresetID) { id in
                    guard let id, let preset = presetStore.all.first(where: { $0.id == id }) else { return }
                    apply(preset: preset)
                }
            }

            field("Name") {
                TextField("e.g. dev", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }
            if !name.isEmpty && !nameIsValid {
                Text("Use letters, numbers, dashes, or underscores only.")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            field("CPUs") {
                Stepper(value: $cpus, in: 1...max(1, hostCPUCount)) {
                    Text("\(cpus)").monospacedDigit()
                }
            }

            field("Memory") {
                Stepper(value: $memoryGB, in: 1...max(2, hostRAMGB)) {
                    Text("\(memoryGB) GB").monospacedDigit()
                }
            }

            field("Disk") {
                Stepper(value: $diskGB, in: 10...200, step: 10) {
                    Text("\(diskGB) GB").monospacedDigit()
                }
            }

            field("Runtime") {
                Picker("", selection: $runtime) {
                    ForEach(ColimaProfile.Runtime.allCases, id: \.self) { runtime in
                        Text(runtime.displayName).tag(runtime)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            field("VM Type") {
                Picker("", selection: $vmType) {
                    ForEach(ColimaProfile.VMType.allCases, id: \.self) { vm in
                        Text(vm.displayName).tag(vm)
                    }
                }
                .labelsHidden()
            }

            field("Kubernetes") {
                Toggle("Enable Kubernetes", isOn: $kubernetes)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            if isSubmitting {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Starting \(name)… this can take a minute")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Save Preset") { saveCurrentAsPreset() }
                .disabled(isSubmitting)
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(isSubmitting)
            Button("Create") { submit() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!nameIsValid || isSubmitting)
        }
        .padding(14)
    }

    private func apply(preset: ProfilePreset) {
        cpus = preset.cpus
        memoryGB = preset.memoryGB
        diskGB = preset.diskGB
        runtime = preset.runtime
        vmType = preset.vmType
        kubernetes = preset.kubernetes
    }

    private func saveCurrentAsPreset() {
        let preset = ProfilePreset(
            id: UUID(),
            name: name.isEmpty ? "Saved \(Date().timeIntervalSince1970)" : name,
            cpus: cpus,
            memoryGB: memoryGB,
            diskGB: diskGB,
            runtime: runtime,
            vmType: vmType,
            isBuiltIn: false
        )
        presetStore.save(preset)
        selectedPresetID = preset.id
    }

    private func submit() {
        guard nameIsValid else { return }
        let config = ProfileStartConfig(
            name: name,
            cpus: cpus,
            memoryGB: memoryGB,
            diskGB: diskGB,
            runtime: runtime,
            vmType: vmType,
            kubernetes: kubernetes
        )
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await appModel.createProfile(config)
                isSubmitting = false
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

#Preview("Light") {
    NewProfileSheet()
        .environmentObject(AppModel())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NewProfileSheet()
        .environmentObject(AppModel())
        .preferredColorScheme(.dark)
}
