import SwiftUI
import SwiftData

struct EditorTarget: Identifiable {
    let id = UUID()
    let entry: DiaryEntry?
    let date: Date
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entry: DiaryEntry?
    let initialDate: Date

    @State private var title: String
    @State private var content: String
    @State private var entryDate: Date
    @State private var mood: Mood?
    @State private var tags: [String]
    @State private var aiSummary: String?
    @State private var newTag = ""
    @State private var showingAIAssist = false
    @State private var showingDiscardConfirmation = false
    @State private var showingEmptyAlert = false

    init(entry: DiaryEntry?, initialDate: Date = .now) {
        self.entry = entry
        self.initialDate = initialDate
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _entryDate = State(initialValue: entry?.createdAt ?? initialDate)
        _mood = State(initialValue: entry?.mood)
        _tags = State(initialValue: entry?.tags ?? [])
        _aiSummary = State(initialValue: entry?.aiSummary)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        dateAndMood
                        titleField
                        contentEditor
                        tagsSection
                        if let aiSummary, !aiSummary.isEmpty {
                            summaryPreview(aiSummary)
                        }
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(entry == nil ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        attemptCancel()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAIAssist = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(isDraftEmpty)
                    .accessibilityLabel("AI writing assistant")

                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(isDraftEmpty)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            }
            .alert("Nothing to save yet", isPresented: $showingEmptyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Write a few words before saving your entry.")
            }
            .sheet(isPresented: $showingAIAssist) {
                AIAssistView(draft: currentDraft) { action in
                    apply(action)
                }
            }
        }
    }

    // MARK: - Sections

    private var dateAndMood: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "When")
                Spacer()
                DatePicker(
                    "Entry date",
                    selection: $entryDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.accent)
            }

            SectionLabel(text: "Mood")
            MoodPicker(selection: $mood)
        }
    }

    private var titleField: some View {
        TextField("Give this day a title (optional)", text: $title, axis: .vertical)
            .font(.system(.title2, design: .serif, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1...3)
            .textFieldStyle(.plain)
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Entry")

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("What happened, what did you notice, what do you want to remember?")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $content)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 240)
            }
            .padding(10)
            .paperCard(cornerRadius: 16)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Tags")

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagBadge(tag: tag) {
                                removeTag(tag)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 8) {
                TextField("Add a tag and press return", text: $newTag)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .onSubmit(addTag)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(cleanedNewTag.isEmpty)
                .accessibilityLabel("Add tag")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Capsule().fill(Theme.paperElevated))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    private func summaryPreview(_ summary: String) -> some View {
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

            Button {
                aiSummary = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove summary")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accentSoft.opacity(0.6))
        )
    }

    private var footer: some View {
        Text("\(wordCount) words · Stored on this device")
            .font(.caption2)
            .foregroundStyle(Theme.inkTertiary)
            .padding(.top, 4)
    }

    // MARK: - Derived state

    private var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var isDraftEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cleanedNewTag: String {
        newTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()
    }

    private var currentDraft: AIEntryDraft {
        AIEntryDraft(title: title, content: content, mood: mood, date: entryDate)
    }

    private var hasUnsavedChanges: Bool {
        guard let entry else {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || mood != nil
                || !tags.isEmpty
                || !newTag.isEmpty
        }

        return title != entry.title
            || content != entry.content
            || mood != entry.mood
            || tags != entry.tags
            || aiSummary != entry.aiSummary
            || abs(entryDate.timeIntervalSince(entry.createdAt)) > 1
    }

    // MARK: - Actions

    private func attemptCancel() {
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard !isDraftEmpty else {
            showingEmptyAlert = true
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry {
            entry.title = cleanTitle
            entry.content = content
            entry.createdAt = entryDate
            entry.mood = mood
            entry.tags = tags
            entry.aiSummary = aiSummary
            entry.updatedAt = .now
        } else {
            let newEntry = DiaryEntry(
                title: cleanTitle,
                content: content,
                createdAt: entryDate,
                mood: mood,
                tags: tags
            )
            newEntry.aiSummary = aiSummary
            context.insert(newEntry)
        }

        try? context.save()
        dismiss()
    }

    private func addTag() {
        let tag = cleanedNewTag
        guard !tag.isEmpty else { return }
        if !tags.contains(tag) {
            tags.append(tag)
        }
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func apply(_ action: AIApplyAction) {
        switch action {
        case .replaceContent(let text):
            content = text
        case .insertContent(let text):
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            content = trimmed.isEmpty ? text : trimmed + "\n\n" + text
        case .setTitle(let text):
            title = text
        case .setSummary(let text):
            aiSummary = text
        case .addTags(let newTags):
            for tag in newTags where !tags.contains(tag) {
                tags.append(tag)
            }
        }
    }
}