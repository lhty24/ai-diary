import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var entries: [DiaryEntry]

    @State private var searchText = ""
    @State private var selectedMood: Mood?
    @State private var favoritesOnly = false
    @State private var editorTarget: EditorTarget?
    @State private var entryToDelete: DiaryEntry?
    @State private var showingDeleteConfirmation = false

    private struct MonthGroup: Identifiable {
        let month: Date
        let entries: [DiaryEntry]
        var id: Date { month }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        header
                        todayPrompt
                        if !entries.isEmpty {
                            filterBar
                        }
                        content
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openNewEntry()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("New entry")
                }
            }
            .searchable(text: $searchText, prompt: "Search entries, tags, or words")
            .navigationDestination(for: DiaryEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .sheet(item: $editorTarget) { target in
                EntryEditorView(entry: target.entry, initialDate: target.date)
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deletePendingEntry()
                }
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(greeting.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.inkTertiary)

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)

            if !entries.isEmpty {
                HStack(spacing: 18) {
                    StatBlock(
                        value: "\(entries.count)",
                        label: entries.count == 1 ? "entry" : "entries"
                    )
                    StatBlock(value: "\(streak)", label: "day streak")
                    StatBlock(value: totalWords.formatted(), label: "words")
                }
                .padding(.top, 2)
            }

            Text(
                entries.isEmpty
                    ? "A quiet place for your days."
                    : "Pick up where you left off, or start somewhere new."
            )
            .font(.system(.subheadline, design: .serif))
            .foregroundStyle(Theme.inkSecondary)
        }
    }

    @ViewBuilder
    private var todayPrompt: some View {
        if !entries.isEmpty && !hasEntryToday && !hasActiveFilters {
            Button {
                openNewEntry()
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("How is today going?")
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(Theme.ink)
                        Text("A few honest lines are enough.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedMood == nil && !favoritesOnly
                ) {
                    selectedMood = nil
                    favoritesOnly = false
                }

                ForEach(Mood.allCases) { mood in
                    FilterChip(
                        title: "\(mood.emoji) \(mood.label)",
                        isSelected: selectedMood == mood
                    ) {
                        selectedMood = selectedMood == mood ? nil : mood
                    }
                }

                FilterChip(
                    title: "Favorites",
                    systemImage: "heart.fill",
                    isSelected: favoritesOnly
                ) {
                    favoritesOnly.toggle()
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            emptyJournal
        } else if filteredEntries.isEmpty {
            noResults
        } else {
            ForEach(groupedEntries) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(group.month.formatted(.dateTime.month(.wide).year()))
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer()
                        Text("\(group.entries.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }

                    ForEach(group.entries) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                entry.isFavorite.toggle()
                            } label: {
                                Label(
                                    entry.isFavorite ? "Remove favorite" : "Favorite",
                                    systemImage: entry.isFavorite ? "heart.slash" : "heart"
                                )
                            }
                            Button {
                                editorTarget = EditorTarget(entry: entry, date: entry.createdAt)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                confirmDelete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyJournal: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent.opacity(0.7))

            Text("Your first page is waiting")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Write a few lines about today. No one else will read them unless you choose to share.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                openNewEntry()
            } label: {
                Label("Write today's entry", systemImage: "square.and.pencil")
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.inkTertiary)

            Text("No entries match")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.ink)

            Text("Try another word or clear your filters.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            Button("Clear filters") {
                searchText = ""
                selectedMood = nil
                favoritesOnly = false
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Derived state

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        case 18..<22: return "Good evening"
        default: return "Quiet hours"
        }
    }

    private var hasEntryToday: Bool {
        entries.contains { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var hasActiveFilters: Bool {
        selectedMood != nil
            || favoritesOnly
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var streak: Int {
        DiaryStats.currentStreak(in: entries)
    }

    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    private var filteredEntries: [DiaryEntry] {
        var result = entries

        if let selectedMood {
            result = result.filter { $0.mood == selectedMood }
        }
        if favoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { entry in
                entry.content.localizedCaseInsensitiveContains(query)
                    || entry.title.localizedCaseInsensitiveContains(query)
                    || entry.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
        return result
    }

    private var groupedEntries: [MonthGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { entry in
            calendar.date(
                from: calendar.dateComponents([.year, .month], from: entry.createdAt)
            ) ?? entry.createdAt
        }
        return groups.keys
            .sorted(by: >)
            .map { month in
                MonthGroup(
                    month: month,
                    entries: (groups[month] ?? []).sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    // MARK: - Actions

    private func openNewEntry() {
        editorTarget = EditorTarget(entry: nil, date: .now)
    }

    private func confirmDelete(_ entry: DiaryEntry) {
        entryToDelete = entry
        showingDeleteConfirmation = true
    }

    private func deletePendingEntry() {
        if let entry = entryToDelete {
            context.delete(entry)
            try? context.save()
        }
        entryToDelete = nil
    }
}