import SwiftUI

struct MoodBadge: View {
    let mood: Mood
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Text(mood.emoji)
                .font(compact ? .caption2 : .caption)
            Text(mood.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.moodColor(mood).opacity(0.16)))
    }
}

struct TagBadge: View {
    let tag: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkTertiary)
                .accessibilityLabel("Remove tag \(tag)")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.paperElevated))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
            .background(Capsule().fill(isSelected ? Theme.accentSoft : Theme.paperElevated))
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Theme.accent.opacity(0.4) : Theme.hairline,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MoodPicker: View {
    @Binding var selection: Mood?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    let isSelected = selection == mood
                    Button {
                        selection = isSelected ? nil : mood
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(
                                        isSelected
                                            ? Theme.moodColor(mood).opacity(0.22)
                                            : Theme.paperElevated
                                    )
                                )
                                .overlay(
                                    Circle().strokeBorder(
                                        isSelected ? Theme.moodColor(mood) : Theme.hairline,
                                        lineWidth: isSelected ? 1.5 : 1
                                    )
                                )
                            Text(mood.label)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.inkTertiary)
    }
}

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}