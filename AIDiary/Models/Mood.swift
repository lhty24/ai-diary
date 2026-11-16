import Foundation

enum Mood: String, CaseIterable, Codable, Identifiable {
    case joyful
    case grateful
    case calm
    case tired
    case anxious
    case sad

    var id: String { rawValue }

    var label: String {
        switch self {
        case .joyful: return "Joyful"
        case .grateful: return "Grateful"
        case .calm: return "Calm"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        }
    }

    var emoji: String {
        switch self {
        case .joyful: return "😄"
        case .grateful: return "🙏"
        case .calm: return "😌"
        case .tired: return "😴"
        case .anxious: return "😟"
        case .sad: return "😢"
        }
    }
}