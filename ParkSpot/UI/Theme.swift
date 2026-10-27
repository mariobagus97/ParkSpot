import SwiftUI

/// The only source of colour in the app. Hex values are the design tokens from the PRD.
enum Theme {
    enum Hex {
        static let bg: UInt32 = 0x121212
        static let surface1: UInt32 = 0x181818
        static let surface2: UInt32 = 0x1F1F1F
        static let surface3: UInt32 = 0x252525
        static let text1: UInt32 = 0xFFFFFF
        static let text2: UInt32 = 0xB3B3B3
        static let text3: UInt32 = 0x7C7C7C
        static let line: UInt32 = 0x4D4D4D
        static let accent: UInt32 = 0x1ED760
        static let warning: UInt32 = 0xFFA42B
        static let negative: UInt32 = 0xF3727F
        static let info: UInt32 = 0x539DF5
        static let black: UInt32 = 0x000000
    }

    static let bg = Color(hex: Hex.bg)
    static let surface1 = Color(hex: Hex.surface1)
    static let surface2 = Color(hex: Hex.surface2)
    static let surface3 = Color(hex: Hex.surface3)
    static let text1 = Color(hex: Hex.text1)
    static let text2 = Color(hex: Hex.text2)
    static let text3 = Color(hex: Hex.text3)
    static let line = Color(hex: Hex.line)
    static let accent = Color(hex: Hex.accent)
    static let warning = Color(hex: Hex.warning)
    static let negative = Color(hex: Hex.negative)
    static let info = Color(hex: Hex.info)
    /// Text on the accent, the floor plate and the camera overlay. A token, so no view reaches for `Color.black`.
    static let black = Color(hex: Hex.black)
}

extension Color {
    /// sRGB colour from a 0xRRGGBB value.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
