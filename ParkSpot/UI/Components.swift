import SwiftUI

// Shared pieces of the v3 look: pill buttons, chips, circles, cover art and the floor plate.
// Every colour comes from `Theme`; the one exception is plain black, which the design uses on the accent and
// as the floor plate.

/// Uppercase pill with 1.6 pt tracking, 48 pt tall.
struct PillButton: View {
    enum Style { case primary, dark, outline }

    private let key: String
    private let style: Style
    private let systemImage: String?
    private let action: () -> Void

    init(_ key: String, style: Style = .primary, systemImage: String? = nil, action: @escaping () -> Void) {
        self.key = key
        self.style = style
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(LocalizedStringKey(key))
                    .multilineTextAlignment(.center)
            }
            .font(.footnote.weight(.bold))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 16)
            .background(background, in: Capsule())
            .overlay {
                if style == .outline { Capsule().strokeBorder(Theme.text3, lineWidth: 1) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary: .black
        case .dark, .outline: Theme.text1
        }
    }

    private var background: Color {
        switch style {
        case .primary: Theme.accent
        case .dark: Theme.surface2
        case .outline: .clear
        }
    }
}

/// A filter or floor chip: 30 pt of visual height inside a 44 pt hit target.
struct Chip: View {
    private let label: Text
    private let isOn: Bool
    private let action: () -> Void

    /// A chip labelled with copy.
    init(_ key: String, isOn: Bool, action: @escaping () -> Void) {
        label = Text(LocalizedStringKey(key))
        self.isOn = isOn
        self.action = action
    }

    /// A chip labelled with text that is not copy (a floor such as "B2").
    init(verbatim text: String, isOn: Bool, action: @escaping () -> Void) {
        label = Text(verbatim: text)
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isOn ? Color.black : Theme.text1)
                .padding(.horizontal, 13)
                .frame(minWidth: 40, minHeight: 30)
                .background(isOn ? Theme.accent : Theme.surface2, in: Capsule())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The photo of a spot, or a gradient in its colour when the file is missing or still unknown.
struct CoverArt: View {
    private static let thumbnailPixels = 320

    private let photos: PhotoStoring
    private let fileName: String?
    private let tint: Int?
    private let cornerRadius: CGFloat
    @State private var image: UIImage?

    init(photos: PhotoStoring, fileName: String?, tint: Int?, cornerRadius: CGFloat = 6) {
        self.photos = photos
        self.fileName = fileName
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        // The colour layer sizes the view (square when unconstrained); the photo only fills it.
        placeholder
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
            .task(id: fileName) {
                guard let fileName else {
                    image = nil
                    return
                }
                image = photos.thumbnail(named: fileName, maxPixel: Self.thumbnailPixels)
            }
    }

    private var placeholder: some View {
        let base = UInt32(truncatingIfNeeded: tint ?? Int(Theme.Hex.surface3))
        return LinearGradient(colors: [Color(hex: Self.mix(base, with: 0xFFFFFF, amount: 0.15)),
                                       Color(hex: Self.mix(base, with: 0x000000, amount: 0.30))],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
            .aspectRatio(1, contentMode: .fit)
    }

    /// `amount` of `other` blended into `base`, both 0xRRGGBB.
    private static func mix(_ base: UInt32, with other: UInt32, amount: Double) -> UInt32 {
        [16, 8, 0].reduce(UInt32(0)) { result, shift in
            let a = Double((base >> UInt32(shift)) & 0xFF)
            let b = Double((other >> UInt32(shift)) & 0xFF)
            let channel = UInt32((a * (1 - amount) + b * amount).rounded())
            return result | channel << UInt32(shift)
        }
    }
}

/// A 44 pt round icon button. The label is copy, because an icon alone says nothing to VoiceOver.
struct CircleIconButton: View {
    private let systemImage: String
    private let labelKey: String
    private let filled: Bool
    private let action: () -> Void

    init(systemImage: String, labelKey: String, filled: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.labelKey = labelKey
        self.filled = filled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.text1)
                .frame(width: 44, height: 44)
                .background(filled ? Theme.surface2 : Color.black.opacity(0.35), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }
}

/// The floor on a black plate, in heavy accent type, like a sign in the car park.
struct FloorBadge: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(verbatim: text)
            .font(.title2.weight(.black))
            .foregroundStyle(Theme.accent)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// The accent circle with a black "P". Decoration only.
struct PMark: View {
    var body: some View {
        Text(verbatim: "P")
            .font(.subheadline.weight(.black))
            .foregroundStyle(.black)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .frame(width: 32, height: 32)
            .background(Theme.accent, in: Circle())
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Components") {
    VStack(alignment: .leading, spacing: 12) {
        PillButton("done") {}
        PillButton("cancel", style: .outline) {}
        PillButton("open_settings", style: .dark, systemImage: "gearshape") {}
        HStack {
            Chip(verbatim: "B2", isOn: true) {}
            Chip(verbatim: "G", isOn: false) {}
            Chip("done", isOn: false) {}
        }
        HStack(spacing: 16) {
            CircleIconButton(systemImage: "xmark", labelKey: "cancel") {}
            CircleIconButton(systemImage: "map", labelKey: "cancel", filled: true) {}
            FloorBadge("B2")
            PMark()
            CoverArt(photos: PreviewPhotos(), fileName: nil, tint: 0x3B5B7A)
                .frame(width: 64, height: 64)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

/// A photo store with no photos, so previews show the placeholder art.
@MainActor final class PreviewPhotos: PhotoStoring {
    func save(_ image: UIImage) throws -> String { "preview.jpg" }
    func image(named: String) -> UIImage? { nil }
    func thumbnail(named: String, maxPixel: Int) -> UIImage? { nil }
    func delete(named: String) {}
}
#endif
