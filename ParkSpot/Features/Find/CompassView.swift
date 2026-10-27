import SwiftUI

/// The compass ring with the accent arrow. The arrow turns with the phone; the ring never moves.
struct CompassView: View {
    /// Cumulative rotation in degrees, already unwrapped by `FindViewModel`.
    let angle: Double

    private static let tickCount = 60

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface1.opacity(0.55))
            ForEach(0..<Self.tickCount, id: \.self) { index in
                let isMajor = index % 15 == 0
                Capsule()
                    .fill(isMajor ? Theme.text1 : Theme.text1.opacity(0.35))
                    .frame(width: isMajor ? 2.5 : 1.3, height: isMajor ? 14 : 8)
                    .offset(y: -92)
                    .rotationEffect(.degrees(Double(index) * 6))
            }
            Image(systemName: "location.north.fill")
                .font(.system(size: 96, weight: .black))
                .foregroundStyle(Theme.accent)
                .rotationEffect(.degrees(angle))
                .animation(.easeOut(duration: 0.2), value: angle)
        }
        .accessibilityHidden(true)
    }
}
