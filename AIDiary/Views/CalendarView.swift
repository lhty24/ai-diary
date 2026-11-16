import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var entries: [DiaryEntry]

    @State private var displayedMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var editorTarget: EditorTarget?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        monthCard
                        selectedDaySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = EditorTarget(
                            entry: nil,
                            date: initialDateForSelectedDay
                        )
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Write for the selected day")
                }
            }
            .navigationDestination(for: DiaryEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .sheet(item: $editorTarget) { target in
                EntryEditorView(entry: target.entry, initialDate: target.date)
            }
        }
    }

    // MARK: - Month grid

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSecondary)
                .accessibilityLabel("Previous month")

                Spacer()

                VStack(spacing: 2) {
                    Text(displayedMonth.formatted(.dateTime.month(.wide)))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(displayedMonth.formatted(.dateTime.year()))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkTertiary)
                }

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSecondary)
                .accessibilityLabel("Next month")
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }

            if !isDisplayingCurrentMonth {
                Button {
                    jumpToToday()
                } label: {
                    Text("Jump to today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .paperCard(cornerRadius: 22)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let dayEntries = entries(on: day)

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(isSelected ? Color.white : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Theme.accent)
                        } else if isToday {
                            Circle().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1.2)
                        }
                    }

                Circle()
                    .fill(dotColor(for: dayEntries))
                    .frame(width: 4, height: 4)
                    .opacity(dayEntries.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .long, time: .omitted))
        .accessibilityValue(dayEntries.isEmpty ? "No entries" : "\(dayEntries.count) entries")
    }

    // MARK: - Selected day

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.ink)

                Spacer()

                if selectedEntries.isEmpty {
                    Button("Write") {
                        editorTarget = EditorTarget(entry: nil, date: initialDateForSelectedDay)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
            }

            if selectedEntries.isEmpty {
                VStack(spacing: 8) {
                    Text("No entry for this day.")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("Sometimes a blank page is the invitation.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.paperElevated.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            } else {
                ForEach(selectedEntries) { entry in
                    NavigationLink(value: entry) {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Date helpers

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
            ?? displayedMonth
    }

    private var monthGrid: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in range {
            if let date = calendar.date(byAdding: .day, value: offset - 1, to: monthStart) {
                days.append(date)
            }
        }
        return days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var isDisplayingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private var initialDateForSelectedDay: Date {
        if calendar.isDateInToday(selectedDate) {
            return .now
        }
        return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: selectedDate)
            ?? selectedDate
    }

    private var selectedEntries: [DiaryEntry] {
        entries(on: selectedDate)
    }

    private func entries(on day: Date) -> [DiaryEntry] {
        entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func dotColor(for entries: [DiaryEntry]) -> Color {
        guard let mood = entries.first?.mood else { return Theme.inkTertiary }
        return Theme.moodColor(mood)
    }

    private func shiftMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: monthStart) else {
            return
        }
        displayedMonth = date
        if let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
            selectedDate = first
        }
    }

    private func jumpToToday() {
        let today = calendar.startOfDay(for: .now)
        displayedMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today
        selectedDate = today
    }
}