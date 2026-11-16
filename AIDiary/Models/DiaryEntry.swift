import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var moodRaw: String?
    var tags: [String] = []
    var isFavorite: Bool = false
    var aiSummary: String?

    init(
        title: String = "",
        content: String = "",
        createdAt: Date = .now,
        mood: Mood? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = .now
        self.moodRaw = mood?.rawValue
        self.tags = tags
        self.isFavorite = false
        self.aiSummary = nil
    }

    var mood: Mood? {
        get { moodRaw.flatMap(Mood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !firstLine.isEmpty else { return "Untitled entry" }
        return firstLine.count > 48 ? String(firstLine.prefix(48)) + "…" : firstLine
    }

    var excerpt: String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
}

enum DiaryStats {
    static func currentStreak(
        in entries: [DiaryEntry],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}