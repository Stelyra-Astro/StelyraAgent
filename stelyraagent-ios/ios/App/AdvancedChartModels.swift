import AstroCore
import Foundation

enum ChartPositionSemantics: String, Codable, Equatable, Sendable {
    case physical
    case progressed
    case directed
    case derived
}

enum ChartHouseFrame: String, Codable, Equatable, Sendable {
    case snapshot
    case natalReference
}

enum ChartTechniqueMetadata: Codable, Equatable, Sendable {
    case standard
    case tertiary(targetDate: Date, progressedDate: Date, monthDays: Double)
    case lunarReturn(
        targetDate: Date,
        returnMoment: Date,
        natalMoonLongitude: Double,
        returnMoonLongitude: Double
    )
    case solarArc(targetDate: Date, progressedDate: Date, arcDegrees: Double)
    case relocation
    case harmonic(number: Int)

    var positionSemantics: ChartPositionSemantics {
        switch self {
        case .standard, .lunarReturn, .relocation:
            .physical
        case .tertiary:
            .progressed
        case .solarArc:
            .directed
        case .harmonic:
            .derived
        }
    }

    var houseFrame: ChartHouseFrame {
        switch self {
        case .solarArc, .harmonic:
            .natalReference
        case .standard, .tertiary, .lunarReturn, .relocation:
            .snapshot
        }
    }

    var aiDocument: [String: Any] {
        let formatter = ISO8601DateFormatter()
        var document: [String: Any] = [
            "positionSemantics": positionSemantics.rawValue,
            "houseFrame": houseFrame.rawValue,
        ]
        switch self {
        case .standard:
            document["id"] = "standard"
        case let .tertiary(targetDate, _, monthDays):
            document["id"] = "tertiary-progression"
            document["targetDate"] = formatter.string(from: targetDate)
            document["monthDays"] = monthDays
        case let .lunarReturn(targetDate, returnMoment, natalMoonLongitude, returnMoonLongitude):
            document["id"] = "lunar-return"
            document["targetDate"] = formatter.string(from: targetDate)
            document["returnMoment"] = formatter.string(from: returnMoment)
            document["natalMoonLongitude"] = natalMoonLongitude
            document["returnMoonLongitude"] = returnMoonLongitude
        case let .solarArc(targetDate, _, arcDegrees):
            document["id"] = "solar-arc"
            document["targetDate"] = formatter.string(from: targetDate)
            document["arcDegrees"] = arcDegrees
        case .relocation:
            document["id"] = "relocation"
            document["birthInstantUnchanged"] = true
        case let .harmonic(number):
            document["id"] = number == 12 ? "twelfth-harmonic" : number == 13 ? "thirteenth-harmonic" : "harmonic"
            document["harmonic"] = number
        }
        return document
    }
}

struct ChartDisplayResult: Codable, Equatable, Sendable {
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let techniqueMetadata: ChartTechniqueMetadata
}

enum AdvancedChartLoadState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed(String)
}
