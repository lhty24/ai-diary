import SwiftUI

enum Theme {
    static let accent = dynamic(light: 0xB6603C, dark: 0xE0966B)
    static let accentSoft = dynamic(light: 0xF2E0D2, dark: 0x38271E)
    static let paper = dynamic(light: 0xF6F0E5, dark: 0x141210)
    static let paperElevated = dynamic(light: 0xFFFAF1, dark: 0x1F1D19)
    static let ink = dynamic(light: 0x2B2620, dark: 0xF1EADB)
    static let inkSecondary = dynamic(light: 0x7C7263, dark: 0xA79D8C)
    static let inkTertiary = dynamic(light: 0xA99E8C, dark: 0x6F6759)
    static let hairline = dynamic(light: 0xE5DAC7, dark: 0x332F28)
    static let favorite = dynamic(light: 0xC0912F, dark: 0xE5BC63)
    static let danger = dynamic(light: 0xB3453A, dark: 0xE68074)

    static func moodColor(_ mood: Mood?) -> Color {
        switch mood {
        case .joyful?: return dynamic(light: 0xD99A2B, dark: 0xE9B84F)
        case .grateful?: return dynamic(light: 0x9A8B3E, dark: 0xC0B66A)
        case .calm?: return dynamic(light: 0x5F8A72, dark: 0x89B79C)
        case .tired?: return dynamic(light: 0x7C7AA0, dark: 0xA5A2C7)
        case .anxious?: return dynamic(light: 0xB17343, dark: 0xD99A6A)
        case .sad?: return dynamic(light: 0x6C82A0, dark: 0x94AAC7)
        case nil: return inkSecondary
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #else
        return Color(white: 0.5)
        #endif
    }
}

#if canImport(UIKit)
import UIKit

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

#if canImport(AppKit)
import AppKit

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

struct PaperBackground: View {
    var body: some View {
        ZStack {
            Theme.paper
            RadialGradient(
                colors: [Theme.accent.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            LinearGradient(
                colors: [.clear, Theme.accent.opacity(0.04)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func paperBackground() -> some View {
        background { PaperBackground() }
    }

    func paperCard(cornerRadius: CGFloat = 20) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.paperElevated)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

extension Font {
    static var diaryBody: Font {
        .system(.body, design: .serif)
    }

    static func diary(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}