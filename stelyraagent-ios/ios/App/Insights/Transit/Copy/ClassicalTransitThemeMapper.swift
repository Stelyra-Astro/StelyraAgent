import AstroCore

enum ClassicalTransitThemeID: String, CaseIterable, Equatable, Sendable {
    case fortifiedPlanet = "fortified-planet"
    case debilitatedPlanet = "debilitated-planet"
    case receptionSupport = "reception-support"
    case applyingContact = "applying-contact"
    case exactContact = "exact-contact"
    case separatingContact = "separating-contact"
    case retrogradeReview = "retrograde-review"
    case solarFortification = "solar-fortification"
    case solarImpairment = "solar-impairment"
    case angularEmphasis = "angular-emphasis"
    case succedentContinuity = "succedent-continuity"
    case cadentDelay = "cadent-delay"
    case motionChange = "motion-change"
    case houseActivation = "house-activation"
}

enum ClassicalTransitIntegratedThemeID: String, CaseIterable, Equatable, Sendable {
    case supportedMomentum = "supported-momentum"
    case constrainedMomentum = "constrained-momentum"
    case mixedTestimony = "mixed-testimony"
}

enum ClassicalTransitSignalRoleID: String, CaseIterable, Equatable, Sendable {
    case beneficSupport = "beneficSupport"
    case maleficPressure = "maleficPressure"
    case fortified = "fortified"
    case impaired = "impaired"
    case received = "received"
}

struct ClassicalTransitStorySignalAssignment: Equatable, Sendable {
    let signalRole: ClassicalTransitSignalRoleID
    let movingID: String
    let sourceFactIDs: [String]
}

enum ClassicalTransitThemeMapper {
    static func themeID(for aspect: TransitAspectFact) -> ClassicalTransitThemeID {
        if aspect.classicalContext?.receptionFromMoving == true
            || aspect.classicalContext?.receptionFromReference == true
        {
            return .receptionSupport
        }
        let conditions = Set(aspect.classicalContext?.movingConditions ?? [])
        if conditions.contains(.cazimi) { return .solarFortification }
        if !conditions.isDisjoint(with: [.combust, .underBeams]) { return .solarImpairment }
        if conditions.contains(.retrograde) { return .retrogradeReview }
        if !conditions.isDisjoint(with: [.domicile, .exaltation]) { return .fortifiedPlanet }
        if !conditions.isDisjoint(with: [.detriment, .fall]) { return .debilitatedPlanet }
        switch aspect.phase {
        case .applying: return .applyingContact
        case .exact: return .exactContact
        case .separating: return .separatingContact
        }
    }

    static func themeID(for placement: TransitPlanetPlacementFact) -> ClassicalTransitThemeID {
        let conditions = Set(placement.classicalConditions)
        if conditions.contains(.cazimi) { return .solarFortification }
        if !conditions.isDisjoint(with: [.combust, .underBeams]) { return .solarImpairment }
        if conditions.contains(.retrograde) { return .retrogradeReview }
        if !conditions.isDisjoint(with: [.domicile, .exaltation]) { return .fortifiedPlanet }
        if !conditions.isDisjoint(with: [.detriment, .fall]) { return .debilitatedPlanet }
        if conditions.contains(.angular) { return .angularEmphasis }
        if conditions.contains(.succedent) { return .succedentContinuity }
        return .cadentDelay
    }

    static func signalRole(for aspect: TransitAspectFact) -> ClassicalTransitSignalRoleID {
        if aspect.classicalContext?.receptionFromMoving == true
            || aspect.classicalContext?.receptionFromReference == true
        {
            return .received
        }
        let conditions = Set(aspect.classicalContext?.movingConditions ?? [])
        if conditions.contains(.cazimi) { return .fortified }
        if !conditions.isDisjoint(with: [.combust, .underBeams, .retrograde, .detriment, .fall]) {
            return .impaired
        }
        if !conditions.isDisjoint(with: [.domicile, .exaltation]) { return .fortified }
        switch CelestialBody(rawValue: aspect.movingID) {
        case .venus, .jupiter: return .beneficSupport
        case .mars, .saturn: return .maleficPressure
        default: return aspect.kind.challenging ? .maleficPressure : .beneficSupport
        }
    }

    static func integratedThemeID(
        for assignments: [ClassicalTransitStorySignalAssignment]
    ) -> ClassicalTransitIntegratedThemeID? {
        guard !assignments.isEmpty else { return nil }
        let supportive: Set<ClassicalTransitSignalRoleID> = [.beneficSupport, .fortified, .received]
        let obstructive: Set<ClassicalTransitSignalRoleID> = [.maleficPressure, .impaired]
        let roles = Set(assignments.map(\.signalRole))
        let hasSupport = !roles.isDisjoint(with: supportive)
        let hasPressure = !roles.isDisjoint(with: obstructive)
        if hasSupport && hasPressure { return .mixedTestimony }
        if hasSupport { return .supportedMomentum }
        return .constrainedMomentum
    }
}

enum ClassicalTransitCopyDomain {
    static let cycleThemeIDs: [ClassicalTransitThemeID] = [
        .fortifiedPlanet,
        .debilitatedPlanet,
        .receptionSupport,
        .applyingContact,
        .exactContact,
        .separatingContact,
        .retrogradeReview,
        .solarFortification,
        .solarImpairment,
        .motionChange,
    ]

    static let planetPathThemeIDs: [ClassicalTransitThemeID] = [
        .fortifiedPlanet,
        .debilitatedPlanet,
        .retrogradeReview,
        .solarFortification,
        .solarImpairment,
        .angularEmphasis,
        .succedentContinuity,
        .cadentDelay,
    ]

    static let activeAspectThemeIDs: [ClassicalTransitThemeID] = [
        .fortifiedPlanet,
        .debilitatedPlanet,
        .receptionSupport,
        .applyingContact,
        .exactContact,
        .separatingContact,
        .retrogradeReview,
        .solarFortification,
        .solarImpairment,
    ]
}

extension CopyCatalogMatcher {
    func classicalTransitCopyRequests(plan: CardEvidencePlan) -> [TransitCopyRequest] {
        switch plan.copySlot {
        case .integratedStory:
            var requests: [TransitCopyRequest] = []
            if let theme = plan.classicalIntegratedThemeID {
                requests.append(
                    classicalRequest(
                        key: "classical.transit.integratedStory.\(theme.rawValue)",
                        plan: plan,
                        slot: .integratedStory,
                        integratedThemeID: theme.rawValue,
                        sourceFactIDs: plan.sourceFactIDs
                    )
                )
            }
            requests += plan.classicalSignalRoles.map {
                classicalRequest(
                    key: "classical.transit.signalRole.\($0.signalRole.rawValue)",
                    plan: plan,
                    slot: .signalRole,
                    roleID: $0.signalRole.rawValue,
                    sourceFactIDs: $0.sourceFactIDs
                )
            }
            return requests
        case .cycleChapter:
            return plan.themeInputs.compactMap { input in
                guard let theme = input.classicalThemeID else { return nil }
                return classicalRequest(
                    key: "classical.transit.cycleChapter.\(input.roleID).\(theme.rawValue)",
                    plan: plan,
                    slot: .cycleChapter,
                    themeID: theme.rawValue,
                    roleID: input.roleID,
                    sourceFactIDs: input.sourceFactIDs
                )
            }
        case .planetPathShort:
            guard let input = plan.themeInputs.first(where: { $0.roleID == TransitEvidenceRole.path.rawValue }),
                  let theme = input.classicalThemeID
            else { return [] }
            return [
                classicalRequest(
                    key: "classical.transit.planetPathShort.\(theme.rawValue)",
                    plan: plan,
                    slot: .planetPathShort,
                    themeID: theme.rawValue,
                    roleID: input.roleID,
                    sourceFactIDs: input.sourceFactIDs
                ),
            ]
        case .lifeAreaShort:
            guard let input = plan.themeInputs.first,
                  let house = input.house
            else { return [] }
            return [
                classicalRequest(
                    key: "classical.transit.lifeAreaShort.house-\(house)",
                    plan: plan,
                    slot: .lifeAreaShort,
                    themeID: ClassicalTransitThemeID.houseActivation.rawValue,
                    roleID: input.roleID,
                    sourceFactIDs: input.sourceFactIDs
                ),
            ]
        case .activeTransitShort:
            guard let input = plan.themeInputs.first,
                  let theme = input.classicalThemeID
            else { return [] }
            return [
                classicalRequest(
                    key: "classical.transit.activeTransitShort.\(input.roleID).\(theme.rawValue)",
                    plan: plan,
                    slot: .activeTransitShort,
                    themeID: theme.rawValue,
                    roleID: input.roleID,
                    sourceFactIDs: input.sourceFactIDs
                ),
            ]
        case .signalRole, nil:
            return []
        }
    }

    private func classicalRequest(
        key: String,
        plan: CardEvidencePlan,
        slot: TransitCopySlot,
        themeID: String? = nil,
        integratedThemeID: String? = nil,
        roleID: String? = nil,
        sourceFactIDs: [String]
    ) -> TransitCopyRequest {
        TransitCopyRequest(
            key: key,
            cardID: plan.cardID,
            copySlot: slot.rawValue,
            themeID: themeID,
            integratedThemeID: integratedThemeID,
            roleID: roleID,
            variables: [:],
            sourceFactIDs: sourceFactIDs
        )
    }
}
