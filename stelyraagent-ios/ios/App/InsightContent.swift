import AstroCore
import ContentKit
import Foundation

struct InsightContentEntry: Codable, Equatable {
    let contentKey: String
    let summary: String
    let detail: String
    let sourceRevision: String?
    let translationStatus: String?
}

enum ConsumerContentArea: String, Codable, Sendable {
    case today
    case ask
}

private struct InsightContentPack: Codable {
    let schemaVersion: Int
    let locale: String
    let area: ConsumerContentArea
    let entries: [InsightContentEntry]
}

struct ContentProvider {
    private let entries: [String: InsightContentEntry]

    init(area: ConsumerContentArea, language: AppLanguage, bundle: Bundle = .main) {
        let contentLanguage: AppLanguage = switch area {
        case .today: language.todayContentLanguage
        case .ask: language.askContentLanguage
        }
        let resourceName = "PrivateContent-\(area.rawValue)-\(contentLanguage.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        var loaded: [InsightContentEntry] = []
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let pack = try? JSONDecoder().decode(InsightContentPack.self, from: data),
               pack.schemaVersion == 1,
               pack.locale == contentLanguage.rawValue,
               pack.area == area
            {
                loaded = pack.entries.filter {
                    $0.translationStatus == "approved"
                        || $0.translationStatus == "sample"
                }
                break
            }
        }
        entries = Dictionary(uniqueKeysWithValues: loaded.map { ($0.contentKey, $0) })
    }

    func requiredCopy(
        key: String,
        variables: [String: String] = [:]
    ) throws -> (summary: String, detail: String) {
        guard let entry = entries[key] else {
            throw ConsumerContentError.missingEntry(key)
        }
        return (
            interpolate(entry.summary, variables: variables),
            interpolate(entry.detail, variables: variables)
        )
    }

    func copyIfPresent(
        key: String,
        variables: [String: String] = [:]
    ) -> (summary: String, detail: String)? {
        guard let entry = entries[key] else { return nil }
        return (
            interpolate(entry.summary, variables: variables),
            interpolate(entry.detail, variables: variables)
        )
    }

    private func interpolate(
        _ template: String,
        variables: [String: String]
    ) -> String {
        variables.reduce(template) { result, item in
            result.replacingOccurrences(of: "{{\(item.key)}}", with: item.value)
        }
    }
}

struct RuntimeCopyVariable: Codable {
    let name: String
    let type: String
}

struct RuntimeCopyEntry: Codable {
    let id: String
    let locale: String
    let status: String
    let kind: String
    let sourcePath: String
    let value: String
    let variables: [RuntimeCopyVariable]
}

struct RuntimeThemeRule: Codable {
    let id: String
    let pair: [String]
    let tone: String
    let themeID: String
}

struct RuntimeCopyContract: Codable {
    let id: String
    let technique: String
    let cardID: String
    let selector: String
    let facts: [String]
    let evidenceByPreset: [String: [String]]
    let textFields: [String]
    let copySourceByPreset: [String: [String]]
}

struct RuntimeCopyCatalog: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let status: String
    let contracts: [RuntimeCopyContract]
    let entries: [RuntimeCopyEntry]
    let themeRulesByPreset: [String: [RuntimeThemeRule]]
}

enum CopyCatalogError: LocalizedError {
    case resourceMissing(String)
    case invalidPack(String)
    case missingCopy(String)
    case unknownVariable(String)
    case unresolvedVariable(String)

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(name): "Reviewed copy catalog \(name) is missing."
        case let .invalidPack(reason): "Reviewed copy catalog is invalid: \(reason)"
        case let .missingCopy(path): "Reviewed copy is missing: \(path)"
        case let .unknownVariable(name): "Copy uses an undeclared variable: \(name)"
        case let .unresolvedVariable(name): "Copy variable was not replaced: \(name)"
        }
    }
}

/// Normalized, chart-agnostic signals derived only from authoritative facts.
/// This layer never selects consumer wording.
struct StandardCopySignals {
    let moonSignIndex: Int
    let sunSignIndex: Int
    let ascendantSignIndex: Int
}

enum StandardSignalBuilder {
    static func build(snapshot: ChartSnapshot, aspects: [ChartAspect]) -> StandardCopySignals {
        StandardCopySignals(
            moonSignIndex: snapshot.point(.moon)?.signIndex ?? 0,
            sunSignIndex: snapshot.point(.sun)?.signIndex ?? 0,
            ascendantSignIndex: Int(snapshot.angles.ascendantDegrees / 30) % 12
        )
    }
}

/// Maps evidence to a reviewed theme selector. It deliberately returns only a
/// theme ID; complete consumer sentences remain owned by CopyCatalogMatcher.
enum ThemeMapper {
    static func themeID(
        for aspect: ChartAspect?,
        house: Int,
        rules: [RuntimeThemeRule],
        houseFallback: (Int, String) -> String?
    ) -> String {
        let tone = aspect.map {
            $0.kind.supportive ? "supportive" : ($0.kind.challenging ? "challenging" : "neutral")
        } ?? "neutral"
        if let aspect {
            let pair = Set([aspect.firstID, aspect.secondID])
            if let rule = rules.first(where: { Set($0.pair) == pair && $0.tone == tone }) {
                return rule.themeID
            }
        }
        if let fallback = houseFallback(house, tone) { return fallback }
        return tone == "supportive"
            ? "confidence.expansion"
            : (tone == "challenging" ? "responsibility.pressure" : "structure.building")
    }

    static func themeID(
        for input: TransitThemeInput,
        rules: [RuntimeThemeRule],
        houseFallback: (Int, String) -> String?
    ) -> String {
        if let movingID = input.movingID,
           let referenceID = input.referenceID,
           let rule = rules.first(where: {
               Set($0.pair) == Set([movingID, referenceID]) && $0.tone == input.tone
           })
        {
            return rule.themeID
        }
        if let house = input.house,
           let fallback = houseFallback(house, input.tone)
        {
            return fallback
        }
        return input.tone == "supportive"
            ? "confidence.expansion"
            : (input.tone == "challenging" ? "responsibility.pressure" : "structure.building")
    }
}

/// A resolved selection references one or two source paths. The runtime pack
/// stores both flat leaf strings and grouped headline/body maps; `textModel`
/// reads whichever is available.
struct CopySelection {
    let basePath: String?
    let secondaryPath: String?
    let themeID: String?
    let sourceFactIDs: [String]
}
struct StandardCopySelectionContext {
    let snapshot: ChartSnapshot
    let natal: ChartSnapshot?
    let aspects: [ChartAspect]
    let primaryAspect: ChartAspect?
    let aspectPath: String?
    let aspectSignalIDs: [String]
    let moonSign: String
    let sunSign: String
    let ascSign: String
    let leadingHouse: Int
    let atmosphere: String
    let themeRules: [RuntimeThemeRule]
}


struct TransitCopyRequest: Codable, Equatable, Sendable {
    let key: String
    let cardID: String
    let copySlot: String
    let themeID: String?
    let integratedThemeID: String?
    let roleID: String?
    let variables: [String: String]
    let sourceFactIDs: [String]

    var identity: String {
        [key, cardID, copySlot].joined(separator: "|")
    }
}

/// Runtime access to the normalized project catalog. Source attachments are
/// converted by build-ios-copy-catalog.mjs and are never read by the App.
struct CopyCatalogMatcher {
    let pack: RuntimeCopyCatalog
    let entriesByPath: [String: RuntimeCopyEntry]
    let contractsByID: [String: RuntimeCopyContract]

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let locale = language.chartContentLanguage.rawValue
        let resourceName = "CopyCatalog-\(locale)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CopyCatalogError.resourceMissing(resourceName)
        }
        do {
            let decoded = try JSONDecoder().decode(RuntimeCopyCatalog.self, from: Data(contentsOf: url))
            guard decoded.schemaVersion == 2,
                  decoded.locale == locale,
                  decoded.status == "approved"
            else {
                throw CopyCatalogError.invalidPack("version, locale or approval state")
            }
            let approved = decoded.entries.filter { $0.status == "approved" }
            guard approved.count == decoded.entries.count else {
                throw CopyCatalogError.invalidPack("non-approved entries reached the runtime pack")
            }
            let pairs = approved.map { ($0.sourcePath, $0) }
            guard Dictionary(grouping: pairs, by: \.0).values.allSatisfy({ $0.count == 1 }) else {
                throw CopyCatalogError.invalidPack("duplicate source path")
            }
            pack = decoded
            entriesByPath = Dictionary(uniqueKeysWithValues: pairs)
            contractsByID = Dictionary(uniqueKeysWithValues: decoded.contracts.map { ($0.id, $0) })
        } catch let error as CopyCatalogError {
            throw error
        } catch {
            throw CopyCatalogError.invalidPack(String(describing: error))
        }
    }

    func value(at sourcePath: String, variables: [String: String] = [:]) throws -> String {
        guard let entry = entriesByPath[sourcePath] else { throw CopyCatalogError.missingCopy(sourcePath) }
        let declared = Set(entry.variables.map(\.name))
        let supplied = Set(variables.keys)
        guard supplied.isSubset(of: declared) else {
            throw CopyCatalogError.unknownVariable(supplied.subtracting(declared).sorted().joined(separator: ","))
        }
        var rendered = entry.value
        for variable in entry.variables {
            guard let replacement = variables[variable.name] else {
                throw CopyCatalogError.unresolvedVariable(variable.name)
            }
            rendered = rendered.replacingOccurrences(of: "{{\(variable.name)}}", with: replacement)
        }
        if let opening = rendered.range(of: "{{"),
           let closing = rendered.range(of: "}}", range: opening.upperBound..<rendered.endIndex) {
            let unresolved = rendered[opening.upperBound..<closing.lowerBound]
            throw CopyCatalogError.unresolvedVariable(String(unresolved))
        }
        return rendered
    }

    func valueIfPresent(at sourcePath: String, variables: [String: String] = [:]) -> String? {
        try? value(at: sourcePath, variables: variables)
    }

    /// Returns true when the card's contract expects consumer-visible headline or body text.
    /// Rows-only or technical-only cards may return nil without breaking the build.
    func copyRequired(chart: ChartKind, cardID: String) -> Bool {
        guard chart.definition.insightMode == .plannedLocalCards else { return false }
        let technique = chart.contentPrefix
        guard let contract = contractsByID["\(technique).\(cardID)"] else { return true }
        let fields = contract.textFields
        return fields.contains("headline") || fields.contains("body") || fields.contains("allDisplayedFields") || fields.contains("secondary")
    }

    func cardText(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        preset: String? = nil
    ) -> CardTextModel? {
        // Classical preset copy selection is not yet fully implemented; use modern paths as a safe fallback.
        let _ = preset
        let selection = copySelection(
            chart: chart,
            cardID: cardID,
            snapshot: snapshot,
            natal: natal,
            aspects: aspects
        )
        return textModel(from: selection, cardID: cardID)
    }


    func todayText(
        cardID: String,
        sky: ChartSnapshot,
        transit: ChartSnapshot,
        natal: ChartSnapshot,
        transitAspects: [ChartAspect],
        preset: String? = nil
    ) -> CardTextModel? {
        // Classical preset copy selection is not yet fully implemented; use modern paths as a safe fallback.
        let _ = preset
        let selection: CopySelection?
        switch cardID {
        case "current-chapter":
            selection = copySelection(chart: .transit, cardID: "current-story", snapshot: transit, natal: natal, aspects: transitAspects)
        case "active-today":
            selection = copySelection(chart: .transit, cardID: "active-transits", snapshot: transit, natal: natal, aspects: transitAspects)
        case "coming-next":
            selection = copySelection(chart: .transit, cardID: "transit-timeline", snapshot: transit, natal: natal, aspects: transitAspects)
        case "moon-today":
            selection = copySelection(chart: .currentSky, cardID: "moon-now", snapshot: sky, natal: natal, aspects: sky.aspects)
        case "today-timeline":
            let strongest = sky.aspects.max(by: { $0.strength < $1.strength })
            selection = strongest.flatMap { aspectCopyPath($0) }.map {
                CopySelection(basePath: $0, secondaryPath: nil, themeID: nil, sourceFactIDs: strongest.map { [$0.id] } ?? [])
            }
        case "upcoming-sky-events":
            selection = copySelection(chart: .currentSky, cardID: "upcoming-7-days", snapshot: sky, natal: natal, aspects: sky.aspects)
        case "retrogrades":
            selection = copySelection(chart: .currentSky, cardID: "planetary-motion", snapshot: sky, natal: natal, aspects: sky.aspects)
        default:
            selection = nil
        }
        return textModel(from: selection, cardID: cardID)
    }

    func textModel(
        from selection: CopySelection?,
        cardID: String,
        scopeID: String? = nil,
        variables: [String: String] = [:],
        roleTexts: [CardRoleText] = [],
        cycleTexts: [TransitCycleText] = []
    ) -> CardTextModel? {
        guard let selection else { return nil }
        let resolved = selection.basePath.map { resolve(base: $0, variables: variables) }
        let secondaryBody = resolved?.secondary
            ?? selection.secondaryPath.flatMap { resolve(base: $0, variables: variables).body }
        let headline = resolved?.headline
        let body = resolved?.body
        guard headline != nil || body != nil || secondaryBody != nil else { return nil }
        return CardTextModel(
            sectionLabel: nil,
            cardLabel: cardID,
            headline: headline,
            body: body,
            secondaryBody: secondaryBody,
            areaLabel: nil,
            statusLabel: nil,
            technicalLabel: nil,
            startLabel: nil,
            endLabel: nil,
            themeID: selection.themeID,
            sourceFactIDs: selection.sourceFactIDs,
            copyPackID: "\(pack.contentVersion):\(selection.basePath ?? selection.secondaryPath ?? cardID)",
            scopeID: scopeID,
            roleTexts: roleTexts.isEmpty ? nil : roleTexts,
            cycleTexts: cycleTexts.isEmpty ? nil : cycleTexts
        )
    }

    func resolve(base: String, variables: [String: String] = [:]) -> (headline: String?, body: String?, secondary: String?) {
        let headline = valueIfPresent(at: "\(base).headline", variables: variables) ?? valueIfPresent(at: "\(base).label", variables: variables)
        let body = valueIfPresent(at: "\(base).body", variables: variables) ?? valueIfPresent(at: base, variables: variables)
        let secondary = valueIfPresent(at: "\(base).guidance", variables: variables)
            ?? valueIfPresent(at: "\(base).secondary", variables: variables)
        return (headline, body, secondary)
    }

    func copySelection(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> CopySelection? {
        let context = standardCopySelectionContext(snapshot: snapshot, natal: natal, aspects: aspects)
        switch chart {
        case .natal:
            return natalCopySelection(cardID: cardID, context: context)
        case .currentSky:
            return currentSkyCopySelection(cardID: cardID, context: context)
        case .transit:
            return transitLegacyCopySelection(cardID: cardID, context: context)
        case .secondary:
            return secondaryCopySelection(cardID: cardID, context: context)
        case .solarReturn:
            return solarReturnCopySelection(cardID: cardID, context: context)
        case .synastry:
            return synastryCopySelection(cardID: cardID, context: context)
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            return nil
        }
    }

    func standardCopySelectionContext(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect]
    ) -> StandardCopySelectionContext {
        let signals = StandardSignalBuilder.build(snapshot: snapshot, aspects: aspects)
        let primaryAspect = aspects.max(by: { $0.strength < $1.strength })
            ?? snapshot.aspects.max(by: { $0.strength < $1.strength })
        let copyableAspect = (aspects + snapshot.aspects)
            .sorted { $0.strength > $1.strength }
            .first { aspect in
                guard let path = aspectCopyPath(aspect) else { return false }
                return hasEntry(under: path)
            }
        let aspectPath = copyableAspect.flatMap(aspectCopyPath)
        let aspectSignalIDs = copyableAspect.map { [$0.id] } ?? primaryAspect.map { [$0.id] } ?? []
        return StandardCopySelectionContext(
            snapshot: snapshot,
            natal: natal,
            aspects: aspects,
            primaryAspect: primaryAspect,
            aspectPath: aspectPath,
            aspectSignalIDs: aspectSignalIDs,
            moonSign: signKey(signals.moonSignIndex),
            sunSign: signKey(signals.sunSignIndex),
            ascSign: signKey(signals.ascendantSignIndex),
            leadingHouse: leadingHouse(in: snapshot, aspects: aspects),
            atmosphere: skyAtmosphere(snapshot),
            themeRules: pack.themeRulesByPreset["modern"] ?? []
        )
    }

    func pair(_ base: String, themeID: String? = nil, sourceFactIDs: [String]) -> CopySelection {
        CopySelection(basePath: base, secondaryPath: nil, themeID: themeID, sourceFactIDs: sourceFactIDs)
    }

    func aspectCopyPath(_ aspect: ChartAspect) -> String? {
        let modernOrder = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]
        let order = modernOrder
        let allowed = Set(order)
        guard allowed.contains(aspect.firstID), allowed.contains(aspect.secondID) else { return nil }
        let pair = [aspect.firstID, aspect.secondID].sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
        let tone = aspect.kind.supportive ? "supportive" : (aspect.kind.challenging ? "challenging" : "neutral")
        return "modern.natal.aspectCopy.\(pair[0]).\(pair[1]).\(tone)"
    }

    func hasEntry(under base: String) -> Bool {
        entriesByPath[base] != nil || entriesByPath.keys.contains { $0.hasPrefix(base + ".") }
    }

    func temperament(_ snapshot: ChartSnapshot) -> (element: String, mode: String) {
        let signs = snapshot.points.filter { $0.body != .trueNode }.map { signKey($0.signIndex) }
        let elementCounts = Dictionary(grouping: signs.map(element), by: { $0 }).mapValues(\.count)
        let modeCounts = Dictionary(grouping: signs.map(mode), by: { $0 }).mapValues(\.count)
        let element = uniqueLeader(elementCounts) ?? "balanced"
        let mode = uniqueLeader(modeCounts) ?? "mixed"
        return (element, mode)
    }

    func leadingHouse(in snapshot: ChartSnapshot, aspects: [ChartAspect]) -> Int {
        let pointByID = Dictionary(uniqueKeysWithValues: snapshot.points.map { ($0.id, $0) })
        let weighted = aspects.reduce(into: [Int: Double]()) { result, aspect in
            for id in [aspect.firstID, aspect.secondID] {
                if let point = pointByID[id] { result[snapshot.house(containing: point.longitudeDegrees), default: 0] += aspect.strength }
            }
        }
        return weighted.max(by: { $0.value < $1.value })?.key ?? snapshot.point(.sun).map { snapshot.house(containing: $0.longitudeDegrees) } ?? 1
    }

    func skyAtmosphere(_ snapshot: ChartSnapshot) -> String {
        let supportive = snapshot.aspects.filter(\.kind.supportive).count
        let challenging = snapshot.aspects.filter(\.kind.challenging).count
        let retrogrades = snapshot.points.filter(\.retrograde).count
        if retrogrades >= 4 { return "review" }
        if snapshot.aspects.count <= 2 { return "quiet" }
        if supportive > challenging * 2 { return "supportive" }
        if challenging > supportive * 2 { return "challenging" }
        return "mixed"
    }

    func lunarPhaseKey(_ snapshot: ChartSnapshot) -> String {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return "new-moon" }
        let angle = (moon.longitudeDegrees - sun.longitudeDegrees + 360).truncatingRemainder(dividingBy: 360)
        return ["new-moon", "waxing-crescent", "first-quarter", "waxing-gibbous", "full-moon", "waning-gibbous", "last-quarter", "waning-crescent"][Int((angle + 22.5) / 45) % 8]
    }

    func progressedPhaseKey(_ snapshot: ChartSnapshot) -> String {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return "new" }
        let angle = (moon.longitudeDegrees - sun.longitudeDegrees + 360).truncatingRemainder(dividingBy: 360)
        if angle < 90 { return "new" }
        if angle < 180 { return "building" }
        if angle < 270 { return "review" }
        return "integration"
    }

    func synastryOverview(_ aspects: [ChartAspect]) -> String {
        guard !aspects.isEmpty else { return "quiet" }
        let supportive = aspects.filter(\.kind.supportive).count
        let challenging = aspects.filter(\.kind.challenging).count
        let intense = aspects.filter { $0.strength >= 0.78 }.count >= 2
        if supportive > challenging * 2 { return intense ? "supportive-intense" : "supportive-balanced" }
        if challenging > supportive * 2 { return intense ? "challenging-intense" : "challenging-growth" }
        return "mixed"
    }

    func uniqueLeader(_ counts: [String: Int]) -> String? {
        let sorted = counts.sorted { $0.value > $1.value }
        guard let first = sorted.first, sorted.dropFirst().first?.value != first.value else { return nil }
        return first.key
    }

    func signKey(_ index: Int) -> String {
        ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"][((index % 12) + 12) % 12]
    }

    func element(for sign: String) -> String {
        if ["aries", "leo", "sagittarius"].contains(sign) { return "fire" }
        if ["taurus", "virgo", "capricorn"].contains(sign) { return "earth" }
        if ["gemini", "libra", "aquarius"].contains(sign) { return "air" }
        return "water"
    }

    func mode(for sign: String) -> String {
        if ["aries", "cancer", "libra", "capricorn"].contains(sign) { return "cardinal" }
        if ["taurus", "leo", "scorpio", "aquarius"].contains(sign) { return "fixed" }
        return "mutable"
    }

    func ruler(for sign: String) -> String {
        ["aries": "mars", "taurus": "venus", "gemini": "mercury", "cancer": "moon", "leo": "sun", "virgo": "mercury", "libra": "venus", "scorpio": "pluto", "sagittarius": "jupiter", "capricorn": "saturn", "aquarius": "uranus", "pisces": "neptune"][sign] ?? "sun"
    }
    func currentQuarter(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        if month <= 3 { return "1" }
        if month <= 6 { return "2" }
        if month <= 9 { return "3" }
        return "4"
    }

    func normalizeDegrees(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    func angularDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(normalizeDegrees(a) - normalizeDegrees(b))
        return min(diff, 360 - diff)
    }

    func closestNatalOverlayAngle(solar: ChartSnapshot, natal: ChartSnapshot?) -> String {
        guard let natal = natal else { return "ASC" }
        let solarLongitude = solar.point(.sun)?.longitudeDegrees ?? solar.angles.ascendantDegrees
        let asc = natal.angles.ascendantDegrees
        let mc = natal.angles.midheavenDegrees
        let dsc = (asc + 180).truncatingRemainder(dividingBy: 360)
        let ic = (mc + 180).truncatingRemainder(dividingBy: 360)
        let candidates = [("ASC", asc), ("DSC", dsc), ("MC", mc), ("IC", ic)]
        let closest = candidates.min { angularDistance(solarLongitude, $0.1) < angularDistance(solarLongitude, $1.1) }
        return closest?.0 ?? "ASC"
    }

    func prominentMovingBody(in snapshot: ChartSnapshot) -> ChartPoint? {
        let moving: [CelestialBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        if let retro = snapshot.points.first(where: { moving.contains($0.body) && $0.retrograde }) { return retro }
        if let direct = snapshot.points.first(where: { moving.contains($0.body) }) { return direct }
        return snapshot.point(.sun) ?? snapshot.points.first
    }

}

/// Compatibility name for call sites while the v6 content pipeline migrates.
typealias CopyCatalogProvider = CopyCatalogMatcher

enum ConsumerContentError: Error, LocalizedError {
    case missingEntry(String)

    var errorDescription: String? {
        switch self {
        case let .missingEntry(key):
            "Required consumer content is missing: \(key)"
        }
    }
}

enum CorpusContentProviderError: Error, LocalizedError {
    case resourceMissing(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case let .resourceMissing(name):
            "Required interpretation pack \(name) is missing."
        case let .unreadable(reason):
            "Interpretation content could not be loaded: \(reason)"
        }
    }
}

struct CorpusContentProvider {
    private let engine: InterpretationEngine

    init(language: AppLanguage, bundle: Bundle = .main) throws {
        let resourceName = "PrivateCorpus-\(language.chartContentLanguage.rawValue)"
        let urls = [
            bundle.url(forResource: resourceName, withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateContent/\(resourceName).json"),
        ].compactMap { $0 }
        guard let url = urls.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CorpusContentProviderError.resourceMissing(resourceName)
        }

        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(InterpretationContentPack.self, from: data)
            #if DEBUG
            engine = try InterpretationEngine(
                pack: pack,
                allowedStatuses: ["approved", "sample"]
            )
            #else
            engine = try InterpretationEngine(pack: pack)
            #endif
            try engine.validateCoverage(requiredCards: Self.requiredCards)
        } catch {
            throw CorpusContentProviderError.unreadable(String(describing: error))
        }
    }

    func interpret(_ context: InterpretationContext) throws -> InterpretationResult {
        try engine.interpret(context)
    }

    private static let requiredCards: [InterpretationTechnique: Set<String>] = [
        .natal: [
            "natal-interpretation",
            "emotional-needs",
            "love-connection",
            "career-direction",
            "strengths-growth",
            "element-balance",
            "house-emphasis",
            "chart-signature",
            "planet-placements",
            "key-aspects",
        ],
        .currentSky: [
            "sky-overview",
            "moon-now",
            "aspect-pattern",
            "planetary-motion",
            "sign-changes",
            "element-climate",
            "upcoming-7-days",
        ],
        .transit: [
            "current-story",
            "current-cycles",
            "transit-timeline",
            "planet-paths",
            "life-areas",
            "active-transits",
        ],
        .secondary: [
            "developmental-chapter",
            "progressed-moon",
            "identity-development",
            "turning-points",
            "areas-maturing",
            "timeline",
        ],
        .solarReturn: [
            "year-theme",
            "year-anchors",
            "priority-areas",
            "year-dynamics",
            "year-timeline",
            "natal-overlay",
            "year-aspects",
        ],
        .synastry: [
            "relationship-overview",
            "perspectives",
            "emotional-connection",
            "communication",
            "chemistry",
            "commitment",
            "house-overlays",
            "key-inter-aspects",
        ],
    ]
}
