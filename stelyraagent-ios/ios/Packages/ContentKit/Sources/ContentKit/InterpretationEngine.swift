import Foundation

public enum InterpretationEngineError: Error, Equatable, CustomStringConvertible {
    case localeMismatch(expected: String, actual: String)
    case missingRule(technique: InterpretationTechnique, cardID: String)
    case duplicateRule(technique: InterpretationTechnique, cardID: String)
    case duplicateEntryID(String)
    case missingBinding(ruleID: String, binding: String)
    case unresolvedPlaceholder(ruleID: String, placeholder: String)
    case emptyOutput(ruleID: String)
    case invalidLength(ruleID: String, field: String, actual: Int, expected: ClosedRange<Int>)

    public var description: String {
        switch self {
        case let .localeMismatch(expected, actual):
            "Content locale \(actual) does not match requested locale \(expected)."
        case let .missingRule(technique, cardID):
            "No composition rule for \(technique.rawValue).\(cardID)."
        case let .duplicateRule(technique, cardID):
            "Duplicate composition rule for \(technique.rawValue).\(cardID)."
        case let .duplicateEntryID(id):
            "Duplicate corpus entry ID: \(id)."
        case let .missingBinding(ruleID, binding):
            "Rule \(ruleID) cannot resolve required binding \(binding)."
        case let .unresolvedPlaceholder(ruleID, placeholder):
            "Rule \(ruleID) left unresolved placeholder \(placeholder)."
        case let .emptyOutput(ruleID):
            "Rule \(ruleID) produced empty summary or detail."
        case let .invalidLength(ruleID, field, actual, expected):
            "Rule \(ruleID) produced \(field) length \(actual), expected \(expected)."
        }
    }
}

public struct InterpretationEngine: Sendable {
    private struct Match: Sendable {
        let entry: CorpusEntry
        let signal: InterpretationSignal
        let score: Double
    }

    private let pack: InterpretationContentPack
    private let rulesByKey: [String: CompositionRule]
    private let allowedStatuses: Set<String>

    public init(
        pack: InterpretationContentPack,
        allowedStatuses: Set<String> = ["approved"]
    ) throws {
        self.pack = pack
        self.allowedStatuses = allowedStatuses
        var entryIDs = Set<String>()
        for entry in pack.entries {
            guard entryIDs.insert(entry.id).inserted else {
                throw InterpretationEngineError.duplicateEntryID(entry.id)
            }
        }

        var rules: [String: CompositionRule] = [:]
        for rule in pack.rules {
            let key = Self.ruleKey(technique: rule.technique, cardID: rule.cardID)
            guard rules[key] == nil else {
                throw InterpretationEngineError.duplicateRule(
                    technique: rule.technique,
                    cardID: rule.cardID
                )
            }
            rules[key] = rule
        }
        rulesByKey = rules
    }

    public func interpret(_ context: InterpretationContext) throws -> InterpretationResult {
        guard context.locale == pack.locale else {
            throw InterpretationEngineError.localeMismatch(
                expected: context.locale,
                actual: pack.locale
            )
        }
        let key = Self.ruleKey(technique: context.technique, cardID: context.cardID)
        guard let rule = rulesByKey[key] else {
            throw InterpretationEngineError.missingRule(
                technique: context.technique,
                cardID: context.cardID
            )
        }

        var replacements = context.values.reduce(into: [String: String]()) {
            $0["context.\($1.key)"] = $1.value
        }
        replacements["context.preset"] = context.preset ?? ""
        var evidenceIDs: [String] = []
        var usedEntryIDs = Set<String>()
        var usedGroups = Set<String>()

        for binding in rule.bindings {
            let matches = matches(
                query: binding.query,
                context: context,
                excludingEntryIDs: usedEntryIDs,
                excludingGroups: usedGroups
            )
            guard !matches.isEmpty || !binding.required else {
                throw InterpretationEngineError.missingBinding(
                    ruleID: rule.id,
                    binding: binding.name
                )
            }

            for (index, match) in matches.enumerated() {
                let prefix = "\(binding.name).\(index + 1)"
                replacements["\(prefix).summary"] = render(
                    match.entry.summary,
                    context: context,
                    signal: match.signal
                )
                replacements["\(prefix).detail"] = render(
                    match.entry.detail,
                    context: context,
                    signal: match.signal
                )
                replacements["\(prefix).entryID"] = match.entry.id
                replacements["\(prefix).signalID"] = match.signal.id
                for (name, value) in match.signal.values {
                    replacements["\(prefix).signal.\(name)"] = value
                }
                evidenceIDs.append(match.entry.id)
                usedEntryIDs.insert(match.entry.id)
                if let group = match.entry.deduplicationGroup {
                    usedGroups.insert(group)
                }
            }
        }

        let summary = render(rule.summaryTemplate, replacements: replacements)
        let detail = render(rule.detailTemplate, replacements: replacements)
        try validateOutput(summary: summary, detail: detail, rule: rule)

        return InterpretationResult(
            summary: summary,
            detail: detail,
            evidenceIDs: evidenceIDs,
            ruleID: rule.id,
            contentVersion: pack.contentVersion
        )
    }

    public func validateCoverage(
        requiredCards: [InterpretationTechnique: Set<String>]
    ) throws {
        for (technique, cardIDs) in requiredCards {
            for cardID in cardIDs {
                let key = Self.ruleKey(technique: technique, cardID: cardID)
                guard rulesByKey[key] != nil else {
                    throw InterpretationEngineError.missingRule(
                        technique: technique,
                        cardID: cardID
                    )
                }
            }
        }
    }

    private func matches(
        query: CorpusQuery,
        context: InterpretationContext,
        excludingEntryIDs: Set<String>,
        excludingGroups: Set<String>
    ) -> [Match] {
        let candidates = pack.entries.filter {
            $0.locale == context.locale
                && allowedStatuses.contains($0.status)
                && query.layers.contains($0.layer)
                && !excludingEntryIDs.contains($0.id)
                && ($0.deduplicationGroup.map { !excludingGroups.contains($0) } ?? true)
        }

        var matches: [Match] = []
        for signal in context.signals {
            if let ranks = query.signalRanks, !ranks.contains(signal.rank) {
                continue
            }
            if let tags = query.requiredTags, !tags.isSubset(of: signal.tags) {
                continue
            }
            for entry in candidates {
                guard let specificity = matchScore(
                    selector: entry.selector,
                    context: context,
                    signal: signal
                ) else {
                    continue
                }
                let score = Double(entry.priority) * 1_000
                    + Double(specificity) * 100
                    + signal.strength * 10
                    - Double(signal.rank)
                matches.append(Match(entry: entry, signal: signal, score: score))
            }
        }

        var selected: [Match] = []
        var localEntries = excludingEntryIDs
        var localGroups = excludingGroups
        for match in matches.sorted(by: deterministicOrder) {
            guard !localEntries.contains(match.entry.id) else { continue }
            if let group = match.entry.deduplicationGroup, localGroups.contains(group) {
                continue
            }
            selected.append(match)
            localEntries.insert(match.entry.id)
            if let group = match.entry.deduplicationGroup {
                localGroups.insert(group)
            }
            if selected.count == max(1, query.limit) {
                break
            }
        }
        return selected
    }

    private func matchScore(
        selector: CorpusSelector,
        context: InterpretationContext,
        signal: InterpretationSignal
    ) -> Int? {
        var specificity = 0
        guard matches(selector.techniques, context.technique, specificity: &specificity),
              matches(selector.cardIDs, context.cardID, specificity: &specificity),
              matches(selector.pointIDs, signal.pointID, specificity: &specificity),
              matches(selector.referencePointIDs, signal.referencePointID, specificity: &specificity),
              matches(selector.signIDs, signal.signID, specificity: &specificity),
              matches(selector.houses, signal.house, specificity: &specificity),
              matches(selector.aspectIDs, signal.aspectID, specificity: &specificity),
              matches(selector.phaseIDs, signal.phaseID, specificity: &specificity),
              matches(selector.tones, signal.tone, specificity: &specificity),
              matches(selector.presets, context.preset, specificity: &specificity)
        else {
            return nil
        }
        if let tags = selector.requiredTags {
            guard tags.isSubset(of: signal.tags) else { return nil }
            specificity += tags.count
        }
        return specificity
    }

    private func matches<T: Hashable>(
        _ allowed: Set<T>?,
        _ actual: T?,
        specificity: inout Int
    ) -> Bool {
        guard let allowed else { return true }
        guard let actual, allowed.contains(actual) else { return false }
        specificity += 1
        return true
    }

    private func matches<T: Hashable>(
        _ allowed: Set<T>?,
        _ actual: T,
        specificity: inout Int
    ) -> Bool {
        guard let allowed else { return true }
        guard allowed.contains(actual) else { return false }
        specificity += 1
        return true
    }

    private func deterministicOrder(_ lhs: Match, _ rhs: Match) -> Bool {
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        if lhs.signal.rank != rhs.signal.rank { return lhs.signal.rank < rhs.signal.rank }
        if lhs.entry.id != rhs.entry.id { return lhs.entry.id < rhs.entry.id }
        return lhs.signal.id < rhs.signal.id
    }

    private func render(
        _ template: String,
        context: InterpretationContext,
        signal: InterpretationSignal
    ) -> String {
        var replacements = context.values.reduce(into: [String: String]()) {
            $0["context.\($1.key)"] = $1.value
        }
        for (key, value) in signal.values {
            replacements["signal.\(key)"] = value
        }
        replacements["signal.id"] = signal.id
        replacements["signal.pointID"] = signal.pointID ?? ""
        replacements["signal.referencePointID"] = signal.referencePointID ?? ""
        replacements["signal.signID"] = signal.signID ?? ""
        replacements["signal.house"] = signal.house.map(String.init) ?? ""
        replacements["signal.aspectID"] = signal.aspectID ?? ""
        replacements["signal.phaseID"] = signal.phaseID ?? ""
        let rendered = render(template, replacements: replacements)
        let semanticPairs = [
            (
                signal.values["consumerFirst"] ?? signal.values["pointName"] ?? "",
                signal.values["consumerSecond"] ?? signal.values["referenceName"] ?? ""
            ),
        ]
        return CompositionTextNormalizer.normalize(
            rendered,
            locale: pack.locale,
            semanticPairs: semanticPairs
        )
    }

    private func render(_ template: String, replacements: [String: String]) -> String {
        let rendered = replacements.reduce(template) {
            $0.replacingOccurrences(of: "{{\($1.key)}}", with: $1.value)
        }
        return CompositionTextNormalizer.normalize(rendered, locale: pack.locale)
    }

    private func validateOutput(
        summary: String,
        detail: String,
        rule: CompositionRule
    ) throws {
        guard !summary.isEmpty, !detail.isEmpty else {
            throw InterpretationEngineError.emptyOutput(ruleID: rule.id)
        }
        let unresolved = #"\{\{[^}]+\}\}"#
        if let range = summary.range(of: unresolved, options: .regularExpression) {
            throw InterpretationEngineError.unresolvedPlaceholder(
                ruleID: rule.id,
                placeholder: String(summary[range])
            )
        }
        if let range = detail.range(of: unresolved, options: .regularExpression) {
            throw InterpretationEngineError.unresolvedPlaceholder(
                ruleID: rule.id,
                placeholder: String(detail[range])
            )
        }
        if let expected = rule.summaryCharacterRange, !expected.contains(summary.count) {
            throw InterpretationEngineError.invalidLength(
                ruleID: rule.id,
                field: "summary",
                actual: summary.count,
                expected: expected
            )
        }
        if let expected = rule.detailCharacterRange, !expected.contains(detail.count) {
            throw InterpretationEngineError.invalidLength(
                ruleID: rule.id,
                field: "detail",
                actual: detail.count,
                expected: expected
            )
        }
    }

    private static func ruleKey(
        technique: InterpretationTechnique,
        cardID: String
    ) -> String {
        "\(technique.rawValue).\(cardID)"
    }
}
