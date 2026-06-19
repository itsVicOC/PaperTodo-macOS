import AppKit

struct PaperPalette {
    let paper: NSColor
    let border: NSColor
    let text: NSColor
    let weakText: NSColor
    let active: NSColor
    let hover: NSColor
}
enum PaperTheme {
    static func palette(for scheme: String, dark: Bool) -> PaperPalette {
        switch scheme {
        case "ink":
            return dark
                ? PaperPalette(paper: color(0x191B1F), border: color(0x3D424A), text: color(0xECEFF4), weakText: color(0xA8B0BA), active: color(0x8AB4F8), hover: color(0x2A3038))
                : PaperPalette(paper: color(0xF6F7F9), border: color(0xCBD1D9), text: color(0x1C2026), weakText: color(0x69717D), active: color(0x2D6CDF), hover: color(0xE8ECF2))
        case "forest":
            return dark
                ? PaperPalette(paper: color(0x17231D), border: color(0x365044), text: color(0xE8F2EC), weakText: color(0x9AB4A6), active: color(0x72D39A), hover: color(0x22342B))
                : PaperPalette(paper: color(0xF4F8F1), border: color(0xBBCDB4), text: color(0x203024), weakText: color(0x687B67), active: color(0x3A8C54), hover: color(0xE7F0E2))
        case "sunset":
            return dark
                ? PaperPalette(paper: color(0x241A21), border: color(0x5A3C50), text: color(0xF8ECEF), weakText: color(0xC39EAA), active: color(0xFF9EB5), hover: color(0x352630))
                : PaperPalette(paper: color(0xFFF5F4), border: color(0xE4B9B6), text: color(0x392423), weakText: color(0x8D6764), active: color(0xD85D72), hover: color(0xF8E5E3))
        default:
            return dark
                ? PaperPalette(paper: color(0x201C16), border: color(0x4F4436), text: color(0xF3ECDF), weakText: color(0xB8AA94), active: color(0xE7B969), hover: color(0x31291F))
                : PaperPalette(paper: color(0xFFF8E8), border: color(0xD8C49A), text: color(0x332A1D), weakText: color(0x816F54), active: color(0xB5792A), hover: color(0xF4E7CB))
        }
    }

    static func color(_ hex: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
