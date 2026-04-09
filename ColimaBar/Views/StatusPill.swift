import SwiftUI

struct StatusPill: View {
    let status: ColimaProfile.Status

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
        .accessibilityLabel("Status: \(label)")
    }

    private var symbol: String {
        switch status {
        case .running:  return "circle.fill"
        case .stopped:  return "circle"
        case .starting, .stopping: return "arrow.triangle.2.circlepath"
        case .unknown:  return "questionmark.circle"
        }
    }

    private var label: String {
        switch status {
        case .running:  return "Running"
        case .stopped:  return "Stopped"
        case .starting: return "Starting"
        case .stopping: return "Stopping"
        case .unknown:  return "Unknown"
        }
    }

    private var tint: Color {
        switch status {
        case .running:  return .green
        case .stopped:  return .secondary
        case .starting, .stopping: return .orange
        case .unknown:  return .gray
        }
    }
}

#Preview("Light") {
    VStack(alignment: .leading, spacing: 8) {
        StatusPill(status: .running)
        StatusPill(status: .stopped)
        StatusPill(status: .starting)
        StatusPill(status: .unknown)
    }
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: 8) {
        StatusPill(status: .running)
        StatusPill(status: .stopped)
        StatusPill(status: .starting)
        StatusPill(status: .unknown)
    }
    .padding()
    .preferredColorScheme(.dark)
}
