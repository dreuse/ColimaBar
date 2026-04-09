import Foundation
import UserNotifications

@MainActor
final class ColimaBarNotifications {
    static let shared = ColimaBarNotifications()

    private let center = UNUserNotificationCenter.current()
    private var diskWarningLastSent: [String: Date] = [:]
    private let diskCooldown: TimeInterval = 6 * 60 * 60

    private init() {}

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notifyStartSucceeded(profile: String, duration: TimeInterval, context: String?) {
        // Short starts don't need a notification — users saw the spinner.
        guard duration >= 8 else { return }
        guard UserDefaults.standard.object(forKey: "pref.notifyOnStart") as? Bool ?? true else { return }
        let body: String
        if let context {
            body = "docker context switched to \(context)"
        } else {
            body = "Ready in \(Int(duration))s"
        }
        post(
            id: "start-success-\(profile)",
            title: "Colima `\(profile)` is ready",
            body: body
        )
    }

    func notifyStartFailed(profile: String, error: String) {
        guard UserDefaults.standard.object(forKey: "pref.notifyOnFailure") as? Bool ?? true else { return }
        let firstLine = error.split(whereSeparator: \.isNewline).first.map(String.init) ?? error
        post(
            id: "start-failed-\(profile)",
            title: "Colima `\(profile)` failed to start",
            body: firstLine
        )
    }

    func notifyDiskHigh(profile: String, percent: Int) {
        guard UserDefaults.standard.object(forKey: "pref.notifyOnDisk") as? Bool ?? true else { return }
        let now = Date()
        if let last = diskWarningLastSent[profile], now.timeIntervalSince(last) < diskCooldown {
            return
        }
        diskWarningLastSent[profile] = now
        post(
            id: "disk-high-\(profile)",
            title: "Colima `\(profile)` disk almost full",
            body: "Disk usage at \(percent)%. Prune images or increase the profile's disk size."
        )
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
