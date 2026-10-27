import SwiftUI

/// "Camera's off" and its sibling screens: an icon, what happened, and the way to fix it in Settings.
/// The caller decides what "Not now" does; this view only reports the tap.
struct PermissionView: View {
    let titleKey: String
    let bodyKey: String
    let onNotNow: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // SF Symbols has no "camera.slash": a camera with a line through it.
                Image(systemName: "camera")
                    .font(.title)
                    .foregroundStyle(Theme.text2)
                    .overlay { Slash().stroke(Theme.text2, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)) }
                    .frame(width: 76, height: 76)
                    .background(Theme.surface2, in: Circle())
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(titleKey))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.text1)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(LocalizedStringKey(bodyKey))
                    .font(.subheadline)
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                PillButton("open_settings", action: openSettings)
                PillButton("not_now", style: .outline, action: onNotNow)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// A diagonal from the top left to the bottom right of its frame.
private struct Slash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview("Camera denied") {
    PermissionView(titleKey: "cam_t", bodyKey: "cam_b") {}
        .preferredColorScheme(.dark)
}
