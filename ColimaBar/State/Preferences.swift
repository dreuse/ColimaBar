import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    @AppStorage("pref.pollInterval") var pollInterval: Double = 5.0
    @AppStorage("pref.defaultRuntime") var defaultRuntime: String = ColimaProfile.Runtime.docker.rawValue
    @AppStorage("pref.notifyOnStart") var notifyOnStart: Bool = true
    @AppStorage("pref.notifyOnFailure") var notifyOnFailure: Bool = true
    @AppStorage("pref.notifyOnDisk") var notifyOnDisk: Bool = true
    @AppStorage("battery.autoStopEnabled") var batteryAutoStop: Bool = false
    @AppStorage("battery.sleepAutoStopEnabled") var sleepAutoStop: Bool = false
    @AppStorage("ui.compactMode") var compactMode: Bool = false

    var runtime: ColimaProfile.Runtime {
        ColimaProfile.Runtime(rawValue: defaultRuntime) ?? .docker
    }
}
