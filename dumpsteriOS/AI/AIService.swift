import Foundation
import FoundationModels

@available(iOS 26.0, *)
struct AIService {

    // MARK: - Availability Check

    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    // MARK: - Insert Bullets Into Doc

    static func insertBulletsIntoDoc(existingContent: String, bullets: [String]) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You integrate new notes into an existing document. For each new bullet:
            1. Find the most relevant existing heading/section to place it under
            2. Expand the bullet into a full insight — complete sentences, connect to other content
            3. If no existing heading fits, create a new section heading (## Title)
            4. Prefix each newly inserted line with "→ " so the user can see what was added

            Rules:
            - Preserve ALL existing content exactly as-is
            - Only ADD new content, never modify or remove existing lines
            - Place new content logically within the section
            - Use professional, clear language
            - Return ONLY the full updated document
            """)

        var prompt = "EXISTING DOCUMENT:\n"
        prompt += existingContent.isEmpty ? "(empty document)" : existingContent
        prompt += "\n\nNEW BULLETS TO INSERT:\n"
        prompt += bullets.map { "• \($0)" }.joined(separator: "\n")

        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Synthesize Master Doc

    static func synthesizeMasterDoc(existingContent: String, bullets: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You sort and lightly clean up a list of personal notes. Your job is to:
            1. Group bullets under short, logical category headings (## Heading) based on their topic
            2. Fix spelling errors and make incomplete or unclear phrases into clean, readable sentences
            3. Remove exact duplicates

            What you must NOT do:
            - Do not add new content, explanations, or elaborations that weren't in the original bullets
            - Do not expand a short note into a paragraph
            - Do not repeat the same word, theme, or idea across multiple bullets
            - Do not change the meaning or substance of any bullet
            - Do not add introductory text, summaries, or conclusions

            Keep each bullet concise. Output Markdown with ## headings and bullet points.
            Return ONLY the sorted document — no preamble, no commentary.
            """)

        // On-device models have ~4K token context. Limit input to ~6000 chars.
        let maxChars = 6000
        var content = existingContent
        var bulletText = bullets

        let totalLength = content.count + bulletText.count
        if totalLength > maxChars {
            // Prioritize bullets (the new content to sort), trim existing
            let bulletBudget = min(bulletText.count, maxChars / 2)
            let contentBudget = maxChars - bulletBudget
            if content.count > contentBudget {
                content = String(content.prefix(contentBudget)) + "\n[...truncated]"
            }
            if bulletText.count > bulletBudget {
                bulletText = String(bulletText.prefix(bulletBudget))
            }
        }

        var prompt = ""
        if !content.isEmpty { prompt += "EXISTING DOCUMENT:\n\(content)\n\n" }
        prompt += "BULLETS TO INTEGRATE:\n\(bulletText)"

        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Analyze Dump

    struct AnalyzeResult {
        var proposedItems: [ProposedItem]
        var suggestedTags: [SuggestedTag]
    }

    struct ProposedItem: Identifiable {
        let id = UUID()
        var text: String
        var category: Category
        let tags: [String]
        let originalText: String
    }

    struct SuggestedTag {
        let bulletText: String
        let tag: String
    }

    static func analyzeDump(content: String) async throws -> AnalyzeResult {
        let session = LanguageModelSession(instructions: """
            You analyze a daily brain-dump (bullet-pointed thoughts). You do two things:

            1. EXTRACT ITEMS: For each meaningful bullet, propose it as an item:
            - text: a CLEAR, professional rewrite — full sentence, no filler words, no shorthand
            - category: "action" (concrete task), "brainstorm" (idea/observation), or "resource" (URL/reference)
            - tags: 1-3 short topic tags (lowercase, use exact project/system names)
            - original_text: the exact source bullet text

            2. SUGGEST TAGS: For bullets without a #tag, suggest what tag should be appended.

            Respond with ONLY valid JSON:
            {
              "items": [{"text": "...", "category": "action", "tags": ["tag1"], "original_text": "..."}],
              "suggested_tags": [{"bullet": "exact bullet text", "tag": "suggested-tag"}]
            }

            Rules:
            - Don't create items from trivial/filler bullets
            - Preserve existing #hashtags as tags
            - Return empty arrays if nothing applies
            """)

        let response = try await session.respond(to: content)
        return parseAnalyzeResponse(response.content)
    }

    // MARK: - Parsing

    private static func parseAnalyzeResponse(_ raw: String) -> AnalyzeResult {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AnalyzeResult(proposedItems: [], suggestedTags: [])
        }

        let items: [ProposedItem] = ((obj["items"] as? [[String: Any]]) ?? []).compactMap { item -> ProposedItem? in
            guard let text = item["text"] as? String,
                  let categoryStr = item["category"] as? String else { return nil }
            let category: Category
            switch categoryStr {
            case "action": category = .action
            case "resource": category = .resource
            default: category = .brainstorm
            }
            let tags = (item["tags"] as? [String])?.map { $0.lowercased() } ?? []
            let originalText = item["original_text"] as? String ?? text
            return ProposedItem(text: text, category: category, tags: tags, originalText: originalText)
        }

        let suggestedTags: [SuggestedTag] = ((obj["suggested_tags"] as? [[String: Any]]) ?? []).compactMap { st in
            guard let bullet = st["bullet"] as? String,
                  let tag = st["tag"] as? String else { return nil }
            return SuggestedTag(bulletText: bullet, tag: tag.lowercased())
        }

        return AnalyzeResult(proposedItems: items, suggestedTags: suggestedTags)
    }

    private static func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: "\n")
            s = lines.dropFirst().joined(separator: "\n")
            if let end = s.range(of: "```") { s = String(s[s.startIndex..<end.lowerBound]) }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
