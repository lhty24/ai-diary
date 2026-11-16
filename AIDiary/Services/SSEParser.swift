import Foundation

enum SSEParser {
    /// Extracts a streaming delta from one server-sent-event line.
    /// Returns nil for comments, blank lines, `[DONE]`, and malformed chunks.
    static func deltaContent(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }

        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]" else { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }
        guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { return nil }
        return chunk.choices.first?.delta?.content
    }

    static func errorMessage(from body: String) -> String {
        let fallback = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = fallback.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallback.isEmpty ? "Unknown error" : String(fallback.prefix(300))
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let message = json["message"] as? String {
            return message
        }
        return fallback.isEmpty ? "Unknown error" : String(fallback.prefix(300))
    }

    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta?
        }
        let choices: [Choice]
    }
}