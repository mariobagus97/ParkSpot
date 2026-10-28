#if DEBUG
import SwiftUI

/// A camera screen for the simulator, which has no camera at all: the same layout our overlay draws on the real
/// camera (the "location locked" chip, the hint, the shutter, Cancel), over a stand-in preview.
///
/// DEBUG only, and only shown when `UIImagePickerController` has no camera; release builds always show the
/// system camera.
struct MockCameraView: View {
    /// "Location locked · ±8 m"; nil hides the chip.
    let chipText: String?
    let onPhoto: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var isFlashing = false

    var body: some View {
        ZStack {
            preview
            VStack(spacing: 10) {
                if let chipText {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                        Text(verbatim: chipText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.text1)
                    }
                    .padding(.horizontal, 13)
                    .frame(minHeight: 30)
                    .background(Theme.black.opacity(0.6), in: Capsule())
                }
                Text("photo_hint")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Theme.text1)
                    .multilineTextAlignment(.center)
                    .shadow(color: Theme.black.opacity(0.7), radius: 3, y: 1)
                    .padding(.horizontal, 18)
                Spacer()
                HStack {
                    Button(action: onCancel) {
                        Text("cancel")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.text1)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        onPhoto(Self.photo())
                    } label: {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 72, height: 72)
                            .overlay { Circle().strokeBorder(Theme.black.opacity(0.25), lineWidth: 4) }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("take_photo"))

                    Spacer()

                    // Balance for the Cancel button, so the shutter stays centred.
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .padding(.top, 72)
        }
        .background(Theme.black)
        .opacity(isFlashing ? 0.4 : 1)
        .onAppear {
            // A shutter flash, so the flow feels like the real thing.
            withAnimation(.easeOut(duration: 0.08)) { isFlashing = true }
            withAnimation(.easeIn(duration: 0.18).delay(0.08)) { isFlashing = false }
        }
    }

    /// A believable stand-in preview: a lit garage with a pillar and a floor sign, no photo asset needed.
    private var preview: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2B2E33), Color(hex: 0x4B4E52), Color(hex: 0x26272A)],
                           startPoint: .top, endPoint: .bottom)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x6F7275), Color(hex: 0x8D9093), Color(hex: 0x6A6D70)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 72)
            VStack {
                Text(verbatim: "B2 · C4")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0xFFD43B), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 150)
                Spacer()
            }
            Text(verbatim: "simulator stand-in")
                .font(.caption2)
                .foregroundStyle(Theme.text1.opacity(0.35))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(12)
        }
        .ignoresSafeArea()
    }

    /// The photo the shutter hands back: the same stand-in, drawn at 1200 x 1600 so the save path is realistic.
    static func photo() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hex: 0x3B4150).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hex: 0x7C828C).setFill()
            context.fill(CGRect(x: size.width / 2 - 110, y: 180, width: 220, height: size.height - 360))
            UIColor(hex: 0xFFD43B).setFill()
            context.fill(CGRect(x: size.width / 2 - 90, y: 420, width: 180, height: 120))
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif
