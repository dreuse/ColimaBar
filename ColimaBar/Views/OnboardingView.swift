import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var selectedPreset: ProfilePreset = .webDev
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: IconRenderer.colorIcon(size: 48))
                .resizable()
                .frame(width: 48, height: 48)
            Text("Welcome to ColimaBar")
                .font(.headline)
            Text("Create your first Colima profile to get started. Pick a preset and we'll handle the rest.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Preset", selection: $selectedPreset) {
                ForEach(ProfilePreset.builtIns, id: \.id) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            presetSummary

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                startWithPreset()
            } label: {
                if isCreating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Starting…")
                    }
                } else {
                    Label("Create default profile", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreating)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var presetSummary: some View {
        HStack(spacing: 14) {
            summaryItem("cpu", "\(selectedPreset.cpus) CPU")
            summaryItem("memorychip", "\(selectedPreset.memoryGB) GB RAM")
            summaryItem("internaldrive", "\(selectedPreset.diskGB) GB")
            if selectedPreset.kubernetes {
                summaryItem("sailboat", "k8s")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func summaryItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text).monospacedDigit()
        }
    }

    private func startWithPreset() {
        let config = ProfileStartConfig(
            name: "default",
            cpus: selectedPreset.cpus,
            memoryGB: selectedPreset.memoryGB,
            diskGB: selectedPreset.diskGB,
            runtime: selectedPreset.runtime,
            vmType: selectedPreset.vmType,
            kubernetes: selectedPreset.kubernetes
        )
        isCreating = true
        errorMessage = nil
        Task {
            do {
                try await appModel.createProfile(config)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCreating = false
        }
    }
}
