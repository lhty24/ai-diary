import Foundation

struct AIConfiguration: Equatable, Sendable {
    var baseURLString: String
    var model: String
    var apiKey: String

    static let defaultBaseURLString = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o-mini"

    private enum StorageKey {
        static let baseURLString = "ai.baseURLString"
        static let model = "ai.model"
    }

    static var storedBaseURLString: String {
        get { UserDefaults.standard.string(forKey: StorageKey.baseURLString) ?? defaultBaseURLString }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.baseURLString) }
    }

    static var storedModel: String {
        get { UserDefaults.standard.string(forKey: StorageKey.model) ?? defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: StorageKey.model) }
    }

    static var storedAPIKey: String {
        get { KeychainStore.load() ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainStore.delete()
            } else {
                KeychainStore.save(trimmed)
            }
        }
    }

    static var stored: AIConfiguration {
        AIConfiguration(
            baseURLString: storedBaseURLString,
            model: storedModel,
            apiKey: storedAPIKey
        )
    }

    static func active() -> AIConfiguration? {
        let configuration = stored
        return configuration.isConfigured ? configuration : nil
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && normalizedBaseURL != nil
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Accepts a base URL such as `https://api.openai.com/v1`, and is also
    /// forgiving if the user pasted a full chat-completions endpoint.
    var normalizedBaseURL: URL? {
        var text = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        while text.hasSuffix("/") { text.removeLast() }
        for suffix in ["/chat/completions", "/completions", "/models"] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
            break
        }
        while text.hasSuffix("/") { text.removeLast() }
        return URL(string: text)
    }

    func endpoint(_ path: String) -> URL? {
        guard let base = normalizedBaseURL else { return nil }
        return base.appendingPathComponent(path)
    }
}