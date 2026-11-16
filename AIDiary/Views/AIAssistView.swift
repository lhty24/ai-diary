import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct AIAssistView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: AIEntryDraft
    let onApply: (AIApplyAction) -> Void

    @State private var activeAction: AIAction?
    @State private var customInstruction = ""
    @State private var result = ""
    @State private var errorMessage: String?
    @State private var isStreaming = false
    @State private var generationTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro

                        if configuration == nil {
                            missingKeyNote
                        }

                        actionGrid
                        customField
                        resultSection
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("AI assist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                generationTask?.cancel()
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Work with your words, not instead of them.")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Nothing leaves your device until you tap an action, and a result is only applied when you choose.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var missingKeyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key.horizontal")
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Add an API key to use AI features")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("Open Settings, enter your OpenAI-compatible API key, base URL, and model, then come back.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accentSoft)
        )
    }

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Quick actions")

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AIAction.allCases.filter { $0 != .custom }) { action in
                    Button {
                        run(action: action)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: action.systemImage)
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                            Text(action.title)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(action.subtitle)
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.paperElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    activeAction == action ? Theme.accent : Theme.hairline,
                                    lineWidth: activeAction == action ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isStreaming || configuration == nil)
                    .opacity(configuration == nil ? 0.55 : 1)
                }
            }
        }
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Ask for something specific")

            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "e.g. Make this warmer without changing the facts",
                    text: $customInstruction,
                    axis: .vertical
                )
                .font(.subheadline)
                .lineLimit(1...3)
                .textFieldStyle(.plain)

                Button {
                    run(
                        action: .custom,
                        instruction: customInstruction
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canRunCustom ? Theme.accent : Theme.inkTertiary)
                .disabled(!canRunCustom)
                .accessibilityLabel("Run custom instruction")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.paperElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if isStreaming || !result.isEmpty || errorMessage != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: activeAction?.title ?? "Result")
                    Spacer()
                    if isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(result.isEmpty ? "…" : result)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.paperElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )

                if !isStreaming {
                    actionButtons
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if errorMessage != nil {
            Button("Try again") {
                retry()
            }
            .buttonStyle(AccentButtonStyle())
        } else if !cleanedResult.isEmpty {
            HStack(spacing: 10) {
                Button(primaryLabel) {
                    applyPrimary()
                }
                .buttonStyle(AccentButtonStyle())

                if showsInsertion {
                    Button("Insert below") {
                        applyInsertion()
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 10) {
                Button {
                    copyResult()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button("Try again") {
                    retry()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    // MARK: - Derived state

    private var configuration: AIConfiguration? {
        AIConfiguration.active()
    }

    private var canRunCustom: Bool {
        !isStreaming
            && configuration != nil
            && !customInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cleanedResult: String {
        result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var primaryLabel: String {
        switch activeAction {
        case .polish?, .custom?: return "Replace entry"
        case .summarize?: return "Save as summary"
        case .suggestTitle?: return "Use as title"
        case .suggestTags?: return "Add tags"
        case .continueWriting?: return "Append"
        case .reflect?: return "Insert questions"
        case .none: return "Use result"
        }
    }

    private var showsInsertion: Bool {
        switch activeAction {
        case .continueWriting?, .reflect?, .custom?: return true
        default: return false
        }
    }

    // MARK: - Actions

    private func run(action: AIAction, instruction: String = "") {
        guard let configuration else { return }

        generationTask?.cancel()
        activeAction = action
        result = ""
        errorMessage = nil
        isStreaming = true

        let messages = AIPrompts.messages(
            for: action,
            draft: draft,
            customInstruction: instruction
        )
        let service = OpenAIService(configuration: configuration)

        generationTask = Task {
            do {
                for try await delta in service.stream(messages: messages) {
                    if Task.isCancelled { return }
                    result += delta
                }
                isStreaming = false
            } catch {
                if Task.isCancelled {
                    isStreaming = false
                    return
                }
                errorMessage = error.localizedDescription
                isStreaming = false
            }
        }
    }

    private func retry() {
        guard let action = activeAction else { return }
        run(
            action: action,
            instruction: customInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func applyPrimary() {
        guard !cleanedResult.isEmpty, let action = activeAction else { return }

        switch action {
        case .polish, .custom:
            onApply(.replaceContent(cleanedResult))
        case .summarize:
            onApply(.setSummary(cleanedResult))
        case .suggestTitle:
            let trimmed = cleanedResult.trimmingCharacters(
                in: CharacterSet(charactersIn: "\"'“”‘’.")
            )
            onApply(.setTitle(trimmed))
        case .suggestTags:
            onApply(.addTags(AIPrompts.parseTags(cleanedResult)))
        case .reflect:
            onApply(.insertContent("Questions to sit with:\n" + cleanedResult))
        case .continueWriting:
            onApply(.insertContent(cleanedResult))
        }
        dismiss()
    }

    private func applyInsertion() {
        guard !cleanedResult.isEmpty else { return }
        onApply(.insertContent(cleanedResult))
        dismiss()
    }

    private func copyResult() {
        #if canImport(UIKit)
        UIPasteboard.general.string = cleanedResult
        #endif
    }
}