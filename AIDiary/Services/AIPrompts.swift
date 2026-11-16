import Foundation

enum AIAction: String, CaseIterable, Identifiable {
    case polish
    case summarize
    case suggestTitle
    case suggestTags
    case reflect
    case continueWriting
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .polish: return "Polish"
        case .summarize: return "Summarize"
        case .suggestTitle: return "Find a title"
        case .suggestTags: return "Suggest tags"
        case .reflect: return "Reflect deeper"
        case .continueWriting: return "Keep writing"
        case .custom: return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .polish: return "Clarify the writing, keep the voice"
        case .summarize: return "One or two sentences to remember"
        case .suggestTitle: return "A short, evocative name"
        case .suggestTags: return "Themes worth returning to"
        case .reflect: return "Three gentle questions"
        case .continueWriting: return "Follow the thought further"
        case .custom: return "Ask for something specific"
        }
    }

    var systemImage: String {
        switch self {
        case .polish: return "wand.and.stars"
        case .summarize: return "text.alignleft"
        case .suggestTitle: return "textformat"
        case .suggestTags: return "tag"
        case .reflect: return "questionmark.bubble"
        case .continueWriting: return "square.and.pencil"
        case .custom: return "sparkles"
        }
    }
}

enum AIApplyAction {
    case replaceContent(String)
    case insertContent(String)
    case setTitle(String)
    case addTags([String])
    case setSummary(String)
}

struct AIEntryDraft {
    let title: String
    let content: String
    let mood: Mood?
    let date: Date
}

enum AIPrompts {
    static let baseSystem = """
    You are a warm, attentive journaling companion inside a private diary app. \
    You help the writer see their own words more clearly.

    Rules:
    - Preserve the writer's voice and first-person perspective.
    - Never invent events, people, or details that are not in the entry.
    - Be concise and skip preambles like "Sure" or "Here is".
    - Use plain text with no markdown headings, bullets, or bold unless explicitly requested.
    - Do not moralize or offer unsolicited advice.
    """

    static func messages(
        for action: AIAction,
        draft: AIEntryDraft,
        customInstruction: String = ""
    ) -> [ChatMessage] {
        let entryBlock = """
        Date: \(draft.date.formatted(date: .long, time: .omitted))
        Mood: \(draft.mood?.label ?? "not shared")
        Title: \(draft.title.isEmpty ? "(none)" : draft.title)

        Entry:
        \(draft.content)
        """

        let instruction: String
        switch action {
        case .polish:
            instruction = """
            Gently polish this diary entry. Improve clarity, flow, grammar, and paragraphing \
            while preserving the writer's voice, first-person perspective, meaning, and level of \
            detail. Do not add new events or opinions. Return only the revised entry text, with \
            no preamble and no markdown formatting.
            """
        case .summarize:
            instruction = """
            Write a one to two sentence summary of the entry in the writer's first-person voice. \
            Capture the emotional core without judgment. Return only the summary, with no quotes \
            and no preamble.
            """
        case .suggestTitle:
            instruction = """
            Suggest one short, evocative title for the entry, ideally two to six words. Return only \
            the title with no quotation marks, no period, and no explanation.
            """
        case .suggestTags:
            instruction = """
            Suggest three to five short, lowercase tags that capture the entry's themes, people, or \
            activities. Return only a comma-separated list, for example: work, family, reflection. \
            No explanation.
            """
        case .reflect:
            instruction = """
            Respond with three gentle, open-ended questions that help the writer reflect more deeply. \
            Number them 1 to 3. Do not give advice, analysis, or reassurance. Keep each question under \
            25 words. Return only the numbered questions.
            """
        case .continueWriting:
            instruction = """
            Continue the entry with two or three short paragraphs in the writer's same voice and \
            tense, following naturally from the last line. Do not repeat what was already written \
            and do not wrap things up with advice. Return only the continuation.
            """
        case .custom:
            instruction = """
            Follow the writer's instruction below as precisely as possible while respecting the base \
            rules. Instruction: \(customInstruction). Return only the result.
            """
        }

        return [
            .system(baseSystem + "\n\n" + instruction),
            .user(entryBlock)
        ]
    }

    static func parseTags(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",#\n;")
        var seen = Set<String>()
        var tags: [String] = []

        for raw in text.components(separatedBy: separators) {
            let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !tag.isEmpty, tag.count <= 24, seen.insert(tag).inserted else { continue }
            tags.append(tag)
            if tags.count == 5 { break }
        }
        return tags
    }
}