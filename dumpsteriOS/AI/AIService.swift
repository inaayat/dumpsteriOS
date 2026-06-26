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
        let headings = DocHeadingExtractor.extractHeadings(from: existingContent)

        if headings.isEmpty && existingContent.isEmpty {
            // Empty doc — just categorize the bullets under a heading
            let session = LanguageModelSession(instructions: """
                You receive new bullets to organize. Group them under short ## headings by topic.
                Keep each bullet concise — one clean sentence. Do not add extra content.
                Return ONLY markdown with ## headings and bullet points.
                """)
            let prompt = bullets.map { "• \($0)" }.joined(separator: "\n")
            let response = try await session.respond(to: prompt)
            return response.content
        }

        // Ask AI which heading each bullet belongs under
        let session = LanguageModelSession(instructions: """
            You are given a list of existing category headings from a document, and new bullets to place.
            For each bullet, respond with EXACTLY one line in this format:
            HEADING: bullet text

            Where HEADING is either an existing heading from the list (use exact text), or a NEW heading you create if none fit.
            Do not modify the bullet text. Just assign each one to a heading.
            If you create a new heading, keep it short (2-4 words).
            """)

        var prompt = "EXISTING HEADINGS:\n"
        prompt += headings.isEmpty ? "(none yet)" : headings.joined(separator: "\n")
        prompt += "\n\nBULLETS TO PLACE:\n"
        prompt += bullets.map { "• \($0)" }.joined(separator: "\n")

        let response = try await session.respond(to: prompt)

        // Parse AI response and insert bullets into the actual doc
        return insertBulletsAtHeadings(existingContent: existingContent, aiResponse: response.content, originalBullets: bullets)
    }

    private static func insertBulletsAtHeadings(existingContent: String, aiResponse: String, originalBullets: [String]) -> String {
        var doc = existingContent
        var newSections: [String: [String]] = [:]

        // Parse "HEADING: bullet text" lines from AI response
        for line in aiResponse.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colonRange = trimmed.range(of: ": ", options: .literal) else { continue }
            let heading = String(trimmed[trimmed.startIndex..<colonRange.lowerBound])
                .replacingOccurrences(of: "## ", with: "")
                .replacingOccurrences(of: "# ", with: "")
                .trimmingCharacters(in: .whitespaces)
            let bullet = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !heading.isEmpty, !bullet.isEmpty else { continue }

            // Try to find this heading in the existing doc
            let lines = doc.components(separatedBy: "\n")
            let headingIndex = lines.firstIndex { line in
                let clean = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                return clean.lowercased() == heading.lowercased()
            }

            if let idx = headingIndex {
                // Find the end of this section (next heading or end of doc)
                var insertAt = idx + 1
                while insertAt < lines.count && !lines[insertAt].hasPrefix("#") {
                    insertAt += 1
                }
                // Insert bullet before the next heading (or at end)
                var mutableLines = lines
                mutableLines.insert("• \(bullet)", at: insertAt)
                doc = mutableLines.joined(separator: "\n")
            } else {
                // New heading — collect for appending at end
                newSections[heading, default: []].append(bullet)
            }
        }

        // Append new sections at end
        for (heading, bullets) in newSections {
            doc += "\n\n## \(heading)\n"
            doc += bullets.map { "• \($0)" }.joined(separator: "\n")
        }

        // Fallback: if parsing failed, just append the original bullets
        if doc == existingContent {
            let bulletLines = originalBullets.map { "• \($0)" }.joined(separator: "\n")
            doc += doc.isEmpty ? bulletLines : "\n\(bulletLines)"
        }

        return doc
    }

    // MARK: - Synthesize Master Doc

    enum AIError: LocalizedError {
        case documentTooLarge

        var errorDescription: String? {
            switch self {
            case .documentTooLarge:
                return "Document too large for on-device AI. Use #save to add bullets individually — they'll be placed under the right category automatically."
            }
        }
    }

    static func synthesizeMasterDoc(existingContent: String, bullets: String) async throws -> String {
        let maxChars = 6000
        let totalLength = existingContent.count + bullets.count
        if totalLength > maxChars {
            throw AIError.documentTooLarge
        }

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

        var prompt = ""
        if !existingContent.isEmpty { prompt += "EXISTING DOCUMENT:\n\(existingContent)\n\n" }
        prompt += "BULLETS TO INTEGRATE:\n\(bullets)"

        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Suggest Heading for Item

    static func rewriteBullet(_ text: String, forHeading heading: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite a rough note into one clear, concise sentence for a document section.
            Rules:
            - Fix grammar, remove filler words, expand abbreviations
            - Keep it short — one sentence, no more
            - Don't add new information or context
            - Match the tone of a professional knowledge doc
            - Respond with ONLY the rewritten sentence, nothing else
            """)
        let prompt = "Section: \(heading)\nNote: \(text)"
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func suggestHeading(for text: String, existingHeadings: [String]) async throws -> String {
        let session = LanguageModelSession(instructions: "You categorize a note under an existing heading. Respond with ONLY the heading name, nothing else.")
        let prompt = "HEADINGS:\n\(existingHeadings.joined(separator: "\n"))\n\nNOTE: \(text)\n\nWhich heading does this belong under? Respond with just the heading name, or 'NEW: [name]' if none fit."
        let response = try await session.respond(to: prompt)
        let suggested = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return suggested.hasPrefix("NEW: ") ? String(suggested.dropFirst(5)) : suggested
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
