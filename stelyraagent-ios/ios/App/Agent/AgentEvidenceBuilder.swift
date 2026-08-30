import AstroCore
import Foundation

/// Converts local deterministic chart output into model-sized evidence. It
/// deliberately excludes raw renderer data and full positional dumps.
struct AgentEvidenceBuilder {
    let targetTokenBudget: Int

    init(targetTokenBudget: Int = 16_000) {
        self.targetTokenBudget = targetTokenBudget
    }

    func build(
        capability: AgentCapability,
        snapshots: [ChartSnapshot],
        aspects: [ChartAspect],
        relationshipArtifacts: [RelationshipChartArtifact],
        timingFacts: [AgentEvidenceFact]
    ) -> [AgentEvidenceFact] {
        var raw = timingFacts
        if relationshipArtifacts.isEmpty {
            for (index, snapshot) in snapshots.enumerated() {
                raw.append(contentsOf: placementFacts(
                    snapshot,
                    capability: capability,
                    role: index == snapshots.count - 1 ? "primary" : "reference"
                ))
            }
            raw.append(contentsOf: aspectFacts(aspects, capability: capability, relationship: false))
        } else {
            let contributing = relationshipArtifacts.filter { capability.relationshipArtifactContributesEvidence(kind: $0.kind) }
            if capability == .synastry, let first = contributing.first {
                if let reference = first.reference {
                    raw.append(contentsOf: placementFacts(reference, capability: capability, role: "subject_1"))
                }
                raw.append(contentsOf: placementFacts(first.snapshot, capability: capability, role: "subject_2"))
            } else {
                for (index, artifact) in contributing.enumerated() {
                    raw.append(contentsOf: placementFacts(artifact.snapshot, capability: capability, role: "relationship_\(index + 1)"))
                }
            }
            raw.append(contentsOf: aspectFacts(
                contributing.flatMap(\.comparisonAspects),
                capability: capability,
                relationship: true
            ))
        }

        return compress(group(select(rank(deduplicate(normalize(raw))))))
    }

    func normalize(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        facts.map { fact in
            AgentEvidenceFact(
                id: fact.id,
                sourceChart: fact.sourceChart,
                evidenceRole: fact.evidenceRole,
                factType: fact.factType,
                data: fact.data.filter { !$0.value.isEmpty },
                priority: fact.priority.map { min(1, max(0, $0)) }
            )
        }
    }

    func deduplicate(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        var result: [AgentEvidenceFact] = []
        var seen = Set<String>()
        for fact in facts {
            let key: String
            if fact.factType == "cross_aspect" {
                let pair = [fact.data["first"] ?? "", fact.data["second"] ?? ""].sorted().joined(separator: "|")
                key = "cross|\(pair)|\(fact.data["kind"] ?? "")|\(fact.data["orb"] ?? "")"
            } else {
                key = fact.id
            }
            guard seen.insert(key).inserted else { continue }
            result.append(fact)
        }
        return result
    }

    func rank(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        facts.sorted { lhs, rhs in
            let lhsTiming = lhs.factType == "timing_event" ? 0.25 : 0
            let rhsTiming = rhs.factType == "timing_event" ? 0.25 : 0
            return (lhs.priority ?? 0.35) + lhsTiming > (rhs.priority ?? 0.35) + rhsTiming
        }
    }

    func select(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        var selected: [AgentEvidenceFact] = []
        var estimatedTokens = 0
        let encoder = JSONEncoder()
        for fact in facts {
            let bytes = (try? encoder.encode(fact).count) ?? 256
            let tokens = max(16, bytes / 4)
            if estimatedTokens + tokens > targetTokenBudget { continue }
            selected.append(fact)
            estimatedTokens += tokens
        }
        return selected
    }

    func group(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        facts.sorted { lhs, rhs in
            if lhs.factType == rhs.factType { return (lhs.priority ?? 0) > (rhs.priority ?? 0) }
            if lhs.factType == "timing_event" { return true }
            if rhs.factType == "timing_event" { return false }
            if lhs.factType.contains("aspect") { return true }
            if rhs.factType.contains("aspect") { return false }
            return lhs.factType < rhs.factType
        }
    }

    func compress(_ facts: [AgentEvidenceFact]) -> [AgentEvidenceFact] {
        // Facts are already normalized into compact semantic fields. Keeping
        // this final stage explicit makes future provider-specific compression
        // replaceable without touching deterministic calculation code.
        facts
    }

    private func placementFacts(
        _ snapshot: ChartSnapshot,
        capability: AgentCapability,
        role: String
    ) -> [AgentEvidenceFact] {
        snapshot.points.map { point in
            AgentEvidenceFact(
                id: "\(capability.rawValue).\(role).placement.\(point.body.rawValue)",
                sourceChart: capability.rawValue,
                evidenceRole: role,
                factType: "placement",
                data: [
                    "body": point.body.rawValue,
                    "sign_index": String(point.signIndex),
                    "degree_in_sign": String(format: "%.2f", point.degreeInSign),
                    "retrograde": point.retrograde ? "true" : "false",
                    "house": String(snapshot.house(containing: point.longitudeDegrees)),
                ],
                priority: [.sun, .moon].contains(point.body) ? 0.8 : 0.45
            )
        }
    }

    private func aspectFacts(
        _ aspects: [ChartAspect],
        capability: AgentCapability,
        relationship: Bool
    ) -> [AgentEvidenceFact] {
        aspects.sorted { $0.strength > $1.strength }.prefix(40).map { aspect in
            AgentEvidenceFact(
                id: "\(capability.rawValue).aspect.\(aspect.id)",
                sourceChart: capability.rawValue,
                evidenceRole: relationship ? "relationship" : "activation",
                factType: relationship ? "cross_aspect" : "aspect",
                data: [
                    "first": aspect.firstID,
                    "second": aspect.secondID,
                    "kind": aspect.kind.rawValue,
                    "orb": String(format: "%.3f", aspect.orbDegrees),
                    "phase": aspect.phase.rawValue,
                ],
                priority: aspect.strength
            )
        }
    }
}
