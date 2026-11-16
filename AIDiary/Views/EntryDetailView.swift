import SwiftUI
import SwiftData

struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: DiaryEntry

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metaRow

                    if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.title)
                            .font(.system(.title, design: .serif, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }

                    if let summary = entry.aiSummary?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !summary.isEmpty {
                        summaryCard(summary)
                    }

                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)

                    Text(entry.content)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !entry.tags.isEmpty {
                        tags
                    }

                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(entry.createdAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    entry.isFavorite.toggle()
                } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                }
                .foregroundStyle(entry.isFavorite ? Theme.favorite : Theme.ink)
                .accessibilityLabel(entry.isFavorite ? "Remove favorite" : "Favorite")

                ShareLink(item: exportText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share entry")

                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit entry", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EntryEditorView(entry: entry, initialDate: entry.createdAt)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                context.delete(entry)
                try? context.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.createdAt.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)

            if let mood = entry.mood {
                MoodBadge(mood: mood)
            }
        }
    }

    private func summaryCard(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "AI summary")
                Text(summary)
                    .font(.system(.subheadline, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accentSoft.opacity(0.7))
        )
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entry.tags, id: \.self) { tag in
                    TagBadge(tag: tag)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.wordCount) words")
            if entry.updatedAt.timeIntervalSince(entry.createdAt) > 60 {
                Text("Edited \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.inkTertiary)
        .padding(.top, 8)
    }

    private var exportText: String {
        MarkdownExporter.markdown(for: [entry])
    }
}