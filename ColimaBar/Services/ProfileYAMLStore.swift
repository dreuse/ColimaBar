import Foundation
import AppKit

enum ProfileYAMLStoreError: LocalizedError {
    case profileNotFound(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .profileNotFound(let path):
            return "No colima.yaml found at \(path). Start the profile at least once first."
        case .writeFailed(let detail):
            return "Failed to write profile YAML: \(detail)"
        }
    }
}

struct ProfileYAMLStore {
    static func yamlURL(for profile: String) -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".colima", isDirectory: true)
            .appendingPathComponent(profile, isDirectory: true)
            .appendingPathComponent("colima.yaml")
    }

    static func read(profile: String) throws -> String {
        let url = yamlURL(for: profile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProfileYAMLStoreError.profileNotFound(url.path)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func write(profile: String, contents: String) throws {
        let url = yamlURL(for: profile)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ProfileYAMLStoreError.writeFailed(error.localizedDescription)
        }
    }

    /// Copies the profile's YAML to a user-chosen location via NSSavePanel.
    @MainActor
    static func exportViaSavePanel(profile: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(profile).colima.yaml"
        panel.allowedContentTypes = [.yaml]
        panel.canCreateDirectories = true
        panel.title = "Export Profile YAML"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let contents = try read(profile: profile)
            try contents.write(to: destination, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Imports a YAML file into an existing or new profile. Returns the chosen profile name.
    @MainActor
    static func importViaOpenPanel(intoProfile profile: String) -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.yaml]
        panel.allowsMultipleSelection = false
        panel.title = "Import Profile YAML"
        guard panel.runModal() == .OK, let source = panel.url else { return false }
        do {
            let contents = try String(contentsOf: source, encoding: .utf8)
            try write(profile: profile, contents: contents)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }
    }

    /// Opens the YAML file in the user's default editor via LaunchServices.
    @MainActor
    static func openInDefaultEditor(profile: String) throws {
        let url = yamlURL(for: profile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProfileYAMLStoreError.profileNotFound(url.path)
        }
        NSWorkspace.shared.open(url)
    }
}

import UniformTypeIdentifiers
extension UTType {
    static var yaml: UTType { UTType(filenameExtension: "yaml") ?? .plainText }
}
