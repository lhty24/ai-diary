import SwiftUI

struct EntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            dateBadge

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.displayTitle)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if entry.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.favorite)
                    }
                }

                if !entry.excerpt.isEmpty {
                    Text(entry.excerpt)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    if let mood = entry.mood {
                        MoodBadge(mood: mood, compact: true)
                    }
                    if !entry.tags.isEmpty {
                        Text(entry.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("\(entry.wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkTertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(entry.createdAt.formatted(.dateTime.day()))
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(entry.createdAt.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.inkTertiary)
        }
        .frame(width: 42, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accentSoft.opacity(0.7))
        )
    }
}