import AstroCore
import Foundation

struct PlannedCardEvidence: Equatable, Sendable {
    let cardID: String
    let copySlot: String
    let evidenceFactIDs: [String]
    let primaryFactID: String?

    init(
        cardID: String,
        copySlot: String,
        evidenceFactIDs: [String],
        primaryFactID: String? = nil
    ) {
        self.cardID = cardID
        self.copySlot = copySlot
        self.evidenceFactIDs = Array(Set(evidenceFactIDs)).sorted()
        self.primaryFactID = primaryFactID
    }
}

protocol ChartContentPlanProtocol {
    var scopeID: String { get }
    var orderedCardIDs: [String] { get }
    func evidenceFactIDs(for cardID: String) -> [String]
}

protocol StandardChartContentPlanProtocol: ChartContentPlanProtocol {
    var cards: [PlannedCardEvidence] { get }
}

extension StandardChartContentPlanProtocol {
    var orderedCardIDs: [String] { cards.map(\.cardID) }

    func evidenceFactIDs(for cardID: String) -> [String] {
        cards.first(where: { $0.cardID == cardID })?.evidenceFactIDs ?? []
    }

    func plannedCard(_ cardID: String) -> PlannedCardEvidence? {
        cards.first { $0.cardID == cardID }
    }
}

enum ChartContentScopeID {
    static func make(
        technique: String,
        preset: String,
        snapshot: ChartSnapshot,
        reference: ChartSnapshot? = nil
    ) -> String {
        let raw = [
            "planned-card-v1",
            technique,
            preset,
            String(format: "%.8f", snapshot.julianDayUT),
            String(format: "%.5f", snapshot.location.latitudeDegrees),
            String(format: "%.5f", snapshot.location.longitudeDegrees),
            reference.map { String(format: "%.8f", $0.julianDayUT) } ?? "none",
        ].joined(separator: "|")
        return String(SHA256Digest.hash(Data(raw.utf8)).hex.prefix(20))
    }

    static func point(_ body: CelestialBody, role: String? = nil) -> String {
        [role, "point", body.rawValue].compactMap { $0 }.joined(separator: ".")
    }

    static func angle(_ name: String, role: String? = nil) -> String {
        [role, "angle", name].compactMap { $0 }.joined(separator: ".")
    }

    static func aspect(_ aspect: ChartAspect, role: String? = nil) -> String {
        [role, "aspect", aspect.firstID, aspect.kind.rawValue, aspect.secondID]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    static func house(_ number: Int, role: String? = nil) -> String {
        [role, "house", String(number)].compactMap { $0 }.joined(separator: ".")
    }
}

enum PlannedCardContractValidator {
    static func validate(
        cards: [InsightCardModel],
        standardPlan: any StandardChartContentPlanProtocol,
        chart: ChartKind
    ) throws {
        try validate(cards: cards, plan: standardPlan)
        guard standardPlan.orderedCardIDs == chart.definition.localCardIDs else {
            throw InsightFactoryError.invalidCardContract(
                "planned card IDs do not match ChartDefinition for \(chart.rawValue)"
            )
        }
        guard standardPlan.cards.allSatisfy({ !$0.copySlot.isEmpty && !$0.evidenceFactIDs.isEmpty }) else {
            throw InsightFactoryError.invalidCardContract(
                "planned local cards require a copy slot and deterministic evidence"
            )
        }
    }

    static func validate(cards: [InsightCardModel], plan: any ChartContentPlanProtocol) throws {
        guard cards.map(\.id) == plan.orderedCardIDs else {
            throw InsightFactoryError.invalidCardContract(
                "planned card order does not match content plan"
            )
        }
        guard Set(plan.orderedCardIDs).count == plan.orderedCardIDs.count else {
            throw InsightFactoryError.invalidCardContract("content plan contains duplicate card IDs")
        }
    }
}
