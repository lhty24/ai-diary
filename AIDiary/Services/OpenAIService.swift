import Foundation

struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String

    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: "system", content: content)
    }

    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }
}

enum AIServiceError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case http(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your API key in Settings to use AI features."
        case .invalidURL:
            return "The API base URL looks invalid. Check it in Settings."
        case .invalidResponse:
            return "The AI service returned an unexpected response."
        case .http(let status, let message):
            return "AI service error \(status): \(message)"
        case .emptyResponse:
            return "The AI service returned an empty response."
        }
    }
}

struct OpenAIService: Sendable {
    let configuration: AIConfiguration

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
        let temperature: Double
    }

    private struct ChatChunkResponse: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta?
        }
        let choices: [Choice]
    }

    private struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message?
        }
        let choices: [Choice]
    }

    private struct ModelListResponse: Decodable {
        struct Model: Decodable {
            let id: String
        }
        let data: [Model]
    }

    func stream(
        messages: [ChatMessage],
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try JSONEncoder().encode(
                        ChatRequest(
                            model: configuration.model,
                            messages: messages,
                            stream: true,
                            temperature: temperature
                        )
                    )
                    let request = try makeRequest(
                        path: "chat/completions",
                        body: body,
                        accept: "text/event-stream"
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let message = try await Self.errorBody(from: bytes)
                        throw AIServiceError.http(status: http.statusCode, message: message)
                    }

                    var receivedContent = false
                    var wasCancelled = false
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            wasCancelled = true
                            break
                        }
                        if let delta = SSEParser.deltaContent(from: line), !delta.isEmpty {
                            receivedContent = true
                            continuation.yield(delta)
                        }
                    }

                    if !receivedContent && !wasCancelled {
                        throw AIServiceError.emptyResponse
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func complete(messages: [ChatMessage], temperature: Double = 0.3) async throws -> String {
        let body = try JSONEncoder().encode(
            ChatRequest(
                model: configuration.model,
                messages: messages,
                stream: false,
                temperature: temperature
            )
        )
        let request = try makeRequest(path: "chat/completions", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIServiceError.http(
                status: http.statusCode,
                message: SSEParser.errorMessage(from: String(decoding: data, as: UTF8.self))
            )
        }

        guard let decoded = try? JSONDecoder().decode(CompletionResponse.self, from: data),
              let content = decoded.choices.first?.message?.content?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return content
    }

    /// Checks `/models` first (free and fast). If the provider does not expose it,
    /// falls back to a very small completion so the key and model are both exercised.
    func testConnection() async throws -> String {
        do {
            let request = try makeRequest(path: "models", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               (200..<300).contains(http.statusCode) {
                if let list = try? JSONDecoder().decode(ModelListResponse.self, from: data) {
                    if list.data.contains(where: { $0.id == configuration.model }) {
                        return "Connected. \(configuration.model) is available."
                    }
                    if !list.data.isEmpty {
                        return "Connected. \(list.data.count) models available; \(configuration.model) was not listed."
                    }
                }
                return "Connected."
            }
        } catch {
            // Fall through to a completion request below.
        }

        _ = try await complete(
            messages: [.user("Reply with exactly: OK")],
            temperature: 0
        )
        return "Connected. \(configuration.model) responded."
    }

    private func makeRequest(
        path: String,
        method: String = "POST",
        body: Data? = nil,
        accept: String = "application/json"
    ) throws -> URLRequest {
        guard configuration.isConfigured else { throw AIServiceError.notConfigured }
        guard let url = configuration.endpoint(path) else { throw AIServiceError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    private static func errorBody(from bytes: URLSession.AsyncBytes) async throws -> String {
        var body = ""
        for try await line in bytes.lines {
            body += line
            if body.count > 8_000 { break }
        }
        return SSEParser.errorMessage(from: body)
    }
}