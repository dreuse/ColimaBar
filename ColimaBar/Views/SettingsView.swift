import SwiftUI

struct SettingsView: View {
    @StateObject private var prefs = Preferences.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            powerTab
                .tabItem { Label("Power", systemImage: "bolt") }
        }
        .frame(width: 420, height: 280)
    }

    private var generalTab: some View {
        Form {
            Section {
                Picker("Default runtime", selection: $prefs.defaultRuntime) {
                    ForEach(ColimaProfile.Runtime.allCases, id: \.self) { runtime in
                        Text(runtime.displayName).tag(runtime.rawValue)
                    }
                }
                Slider(
                    value: $prefs.pollInterval,
                    in: 2...30,
                    step: 1
                ) {
                    Text("Refresh interval")
                } minimumValueLabel: {
                    Text("2s").font(.caption2)
                } maximumValueLabel: {
                    Text("30s").font(.caption2)
                }
                HStack {
                    Text("Interval")
                    Spacer()
                    Text("\(Int(prefs.pollInterval)) seconds")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } header: {
                Text("General")
            }

            Section {
                Toggle("Compact mode", isOn: $prefs.compactMode)
            } header: {
                Text("Layout")
            } footer: {
                Text("Hides resource specs and container lists for a denser view.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle("Profile started (after long starts)", isOn: $prefs.notifyOnStart)
                Toggle("Profile failed to start", isOn: $prefs.notifyOnFailure)
                Toggle("Disk usage warnings", isOn: $prefs.notifyOnDisk)
            } header: {
                Text("Send notifications for")
            } footer: {
                Text("Short-lived events are never notified. Sound is always off.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var powerTab: some View {
        Form {
            Section {
                Toggle("Auto-stop profiles on battery", isOn: $prefs.batteryAutoStop)
                Toggle("Auto-stop profiles on sleep", isOn: $prefs.sleepAutoStop)
            } header: {
                Text("Battery & sleep")
            } footer: {
                Text("Battery auto-stop kicks in after 5 minutes on battery. Useful on laptops to preserve runtime.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
