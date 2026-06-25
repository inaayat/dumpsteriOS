import Foundation

enum VoiceTagProcessor {

    static func process(_ rawTranscription: String) -> String {
        let existingTags = (try? Queries.getAllTags())?.map { $0.name.lowercased() } ?? []
        let magicTags: Set<String> = ["action", "brainstorm", "resource", "prio", "backlog", "save", "delete"]

        var result = rawTranscription
        let pattern = #"(?i)\b(?:hashtag|hash tag)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Process from end to start so ranges stay valid
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }

            let afterHashtag = result[matchRange.upperBound...]
                .drop(while: { $0 == " " })

            let remainingWords = String(afterHashtag)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            let (tagName, wordsConsumed) = resolveTag(
                from: remainingWords,
                existingTags: existingTags,
                magicTags: magicTags
            )

            guard !tagName.isEmpty, wordsConsumed > 0 else { continue }

            // Find the range to replace: "hashtag" + space + consumed words
            let consumedText = remainingWords[0..<wordsConsumed].joined(separator: " ")
            let fullPatternStart = matchRange.lowerBound
            var fullPatternEnd = matchRange.upperBound

            // Advance past space between "hashtag" and the consumed words
            if let spaceRange = result[fullPatternEnd...].range(of: consumedText, options: .caseInsensitive) {
                fullPatternEnd = spaceRange.upperBound
            } else {
                // Fallback: advance by the consumed words length + leading space
                let afterMatch = result[fullPatternEnd...]
                let trimmed = afterMatch.prefix(consumedText.count + 1)
                fullPatternEnd = trimmed.endIndex
            }

            let replacement = "#\(tagName)"
            result.replaceSubrange(fullPatternStart..<fullPatternEnd, with: replacement)
        }

        // Clean up extra spaces
        result = result.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        return result
    }

    private static func resolveTag(
        from words: [String],
        existingTags: [String],
        magicTags: Set<String>
    ) -> (name: String, wordsConsumed: Int) {
        guard !words.isEmpty else { return ("", 0) }

        // First word alone might be a magic tag
        let firstWord = words[0].lowercased()
        if magicTags.contains(firstWord) {
            return (firstWord, 1)
        }

        // Build candidate tag by progressively consuming words
        // "dash" becomes a literal hyphen joining adjacent words
        // Try to match against existing tags (longest match wins)
        var bestMatch = ""
        var bestConsumed = 0

        var candidateParts: [String] = []
        var consumed = 0

        for word in words {
            let lower = word.lowercased()

            // Stop at another "hashtag" trigger
            if lower == "hashtag" || lower == "hash" { break }

            if lower == "dash" {
                // "dash" is a separator, not a word in the tag
                if !candidateParts.isEmpty {
                    candidateParts[candidateParts.count - 1] += "-"
                }
                consumed += 1
                continue
            }

            // If previous part ended with a dash, append to it
            if let last = candidateParts.last, last.hasSuffix("-") {
                candidateParts[candidateParts.count - 1] += lower
            } else {
                candidateParts.append(lower)
            }
            consumed += 1

            // Check if current candidate matches an existing tag
            let candidate = candidateParts.joined(separator: "-")
            if existingTags.contains(candidate) {
                bestMatch = candidate
                bestConsumed = consumed
            }
        }

        // If we found an existing tag match, use it
        if !bestMatch.isEmpty {
            return (bestMatch, bestConsumed)
        }

        // No existing tag match — use just the first word(s) up to next natural break
        // Take the first word or first "dash"-connected sequence
        candidateParts = []
        consumed = 0
        for word in words {
            let lower = word.lowercased()
            if lower == "hashtag" || lower == "hash" { break }
            if lower == "dash" {
                if !candidateParts.isEmpty {
                    candidateParts[candidateParts.count - 1] += "-"
                }
                consumed += 1
                continue
            }

            if let last = candidateParts.last, last.hasSuffix("-") {
                candidateParts[candidateParts.count - 1] += lower
                consumed += 1
            } else if candidateParts.isEmpty {
                candidateParts.append(lower)
                consumed += 1
            } else {
                // Second unconnected word — stop here
                break
            }
        }

        let tag = candidateParts.joined(separator: "-")
        return (tag, consumed)
    }
}
