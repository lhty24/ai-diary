import SwiftUI
import SwiftData

@MainActor
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [DiaryEntry]

    @State private var apiKey = ""
    @State private var baseURLString = AIConfiguration.defaultBaseURLString
    @State private var model = AIConfiguration.defaultModel
    @State private var hasLoaded = false
    @State private var savedConfirmation = false
    @State private var testState: ConnectionTestState = .idle
    @State private var showingDeleteAll = false

    private enum ConnectionTestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                appSection
                aiSection
                privacySection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadSettings)
            .confirmationDialog(
                "Delete all entries?",
                isPresented: $showingDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete all \(entries.count) entries", role: .destructive) {
                    deleteAllEntries()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every entry from this device and cannot be undone. Export a copy first if you want to keep them.")
            }
        }
    }

    // MARK: - Sections

    private var appSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "book.pages")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accentSoft))

                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Diary")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("A quiet place for your days.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var aiSection: some View {
        Section {
            SecureField("API key", text: $apiKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Base URL", text: $baseURLString)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Model", text: $model)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button(action: saveAISettings) {
                HStack {
                    Text("Save AI settings")
                    Spacer()
                    if savedConfirmation {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }

            Button(action: testConnection) {
                HStack {
                    Text("Test connection")
                    Spacer()
                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    case .failure:
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .disabled(
                apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || testState == .testing
            )

            if case .success(let message) = testState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            if case .failure(let message) = testState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        } header: {
            Text("AI assistant")
        } footer: {
            Text("Bring your own key from any OpenAI-compatible provider (OpenAI, OpenRouter, LM Studio, and others). The key is stored in the iOS Keychain and is only sent to the base URL above.")
        }
        .listRowBackground(Theme.paperElevated)
    }

    private var privacySection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private by default")
                        .font(.subheadline.weight(.semibold))
                    Text("Entries are saved on this device. They are sent to your AI provider only when you run an AI action, and never automatically.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Theme.accent)
            }

            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No account required")
                        .font(.subheadline.weight(.semibold))
                    Text("There is no sign-in and no analytics. Everything starts and ends here.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            } icon: {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Theme.accent)
            }
        } header: {
            Text("Privacy")
        }
        .listRowBackground(Theme.paperElevated)
    }

    private var dataSection: some View {
        Section {
            ShareLink(
                item: exportText,
                subject: Text("AI Diary export"),
                message: Text("Exported from AI Diary")
            ) {
                Label("Export all entries as Markdown", systemImage: "square.and.arrow.up")
            }
            .disabled(entries.isEmpty)

            Button(role: .destructive) {
                showingDeleteAll = true
            } label: {
                Label("Delete all entries", systemImage: "trash")
            }
            .disabled(entries.isEmpty)

            HStack {
                Text("On this device")
                Spacer()
                Text("\(entries.count) entries · \(totalWords.formatted()) words")
                    .foregroundStyle(Theme.inkSecondary)
            }
            .font(.subheadline)
        } header: {
            Text("Your data")
        }
        .listRowBackground(Theme.paperElevated)
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .font(.subheadline)
        } header: {
            Text("About")
        } footer: {
            Text("Made for your eyes only.")
        }
        .listRowBackground(Theme.paperElevated)
    }

    // MARK: - Derived state

    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    private var exportText: String {
        MarkdownExporter.markdown(for: entries)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func loadSettings() {
        guard !hasLoaded else { return }
        baseURLString = AIConfiguration.storedBaseURLString
        model = AIConfiguration.storedModel
        apiKey = AIConfiguration.storedAPIKey
        hasLoaded = true
    }

    private func saveAISettings() {
        AIConfiguration.storedAPIKey = apiKey
        AIConfiguration.storedBaseURLString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        AIConfiguration.storedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        savedConfirmation = true
        testState = .idle

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            savedConfirmation = false
        }
    }

    private func testConnection() {
        let configuration = AIConfiguration(
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard configuration.isConfigured else {
            testState = .failure("Fill in the API key, base URL, and model first.")
            return
        }

        testState = .testing

        Task {
            do {
                let message = try await OpenAIService(configuration: configuration).testConnection()
                testState = .success(message)
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }

    private func deleteAllEntries() {
        for entry in entries {
            context.delete(entry)
        }
        try? context.save()
    }
}