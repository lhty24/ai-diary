import Foundation

enum MarkdownExporter {
    static func markdown(for entries: [DiaryEntry]) -> String {
        guard !entries.isEmpty else {
            return "# AI Diary\n\nNo entries yet."
        }

        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        var lines: [String] = [
            "# AI Diary export",
            "",
            "_Exported \(Date.now.formatted(date: .long, time: .shortened)) · \(sorted.count) entries_",
            ""
        ]

        for entry in sorted {
            var meta = [entry.createdAt.formatted(date: .complete, time: .shortened)]
            if let mood = entry.mood {
                meta.append("Mood: \(mood.emoji) \(mood.label)")
            }
            meta.append("\(entry.wordCount) words")

            lines.append("## \(entry.displayTitle)")
            lines.append("")
            lines.append(meta.joined(separator: " · "))
            lines.append("")

            if let summary = entry.aiSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                lines.append("> **AI summary:** \(summary)")
                lines.append("")
            }

            lines.append(entry.content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")

            if !entry.tags.isEmpty {
                lines.append(entry.tags.map { "#\($0)" }.joined(separator: " "))
                lines.append("")
            }

            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}