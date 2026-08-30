import Foundation

enum CompositionTextNormalizer {
    static func normalize(
        _ raw: String,
        locale: String,
        semanticPairs: [(String, String)] = []
    ) -> String {
        var result = raw
        for (first, second) in semanticPairs {
            let left = canonical(first)
            let right = canonical(second)
            guard !left.isEmpty, left == right else { continue }
            if locale == "zh-Hans" {
                result = result.replacingOccurrences(
                    of: "\(first)与\(second)",
                    with: first
                )
                result = result.replacingOccurrences(
                    of: "\(first)和\(second)",
                    with: first
                )
            } else {
                result = result.replacingOccurrences(
                    of: "\(first) and \(second) are",
                    with: "\(first) is",
                    options: .caseInsensitive
                )
                result = result.replacingOccurrences(
                    of: "\(first) and \(second) have",
                    with: "\(first) has",
                    options: .caseInsensitive
                )
                result = result.replacingOccurrences(
                    of: "\(first) and \(second)",
                    with: first,
                    options: .caseInsensitive
                )
                result = result.replacingOccurrences(
                    of: "\(first) & \(second)",
                    with: first,
                    options: .caseInsensitive
                )
            }
        }

        if locale == "en" {
            result = result.replacingOccurrences(
                of: #"\ban\s+(?=[bcdfghjklmnpqrstvwxyz][a-z])"#,
                with: "a ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        result = result
            .replacingOccurrences(of: #"\s+([,.;:!?，。；：！？])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return removingConsecutiveDuplicateSentences(result, locale: locale)
    }

    private static func canonical(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: "", options: .regularExpression)
    }

    private static func removingConsecutiveDuplicateSentences(
        _ value: String,
        locale: String
    ) -> String {
        var sentences: [String] = []
        var current = ""
        let terminators: Set<Character> = [".", "!", "?", "。", "！", "？"]
        for character in value {
            current.append(character)
            if terminators.contains(character) {
                let candidate = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty,
                   canonical(candidate) != sentences.last.map(canonical)
                {
                    sentences.append(candidate)
                }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty,
           canonical(tail) != sentences.last.map(canonical)
        {
            sentences.append(tail)
        }
        return sentences.joined(separator: locale == "zh-Hans" ? "" : " ")
    }
}
