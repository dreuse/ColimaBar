import SwiftUI

struct ResourceMeter: View {
    let label: String
    let percent: Double
    var detail: String? = nil
    var compact: Bool = true

    private var tint: Color {
        switch percent {
        case 90...:  return .red
        case 70..<90: return .orange
        default:      return .secondary
        }
    }

    var body: some View {
        if compact {
            bar
                .frame(width: 36, height: 3)
        } else {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                bar
                    .frame(height: 4)
                Text(detail ?? "\(Int(percent))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * min(percent, 100) / 100))
            }
        }
    }
}

#Preview("Light") {
    VStack(spacing: 10) {
        ResourceMeter(label: "CPU", percent: 32, compact: false)
        ResourceMeter(label: "RAM", percent: 78, compact: false)
        ResourceMeter(label: "DISK", percent: 94, compact: false)
        HStack {
            ResourceMeter(label: "", percent: 45)
            ResourceMeter(label: "", percent: 82)
            ResourceMeter(label: "", percent: 12)
        }
    }
    .padding()
    .frame(width: 280)
    .preferredColorScheme(.light)
}
