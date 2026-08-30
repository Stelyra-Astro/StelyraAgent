import Foundation

private struct AstroTermCatalog: Decodable {
    let version: Int
    let locale: String
    let bodies: [String: String]
    let zodiac: [String: String]
    let aspects: [String: String]
    let aspectPhases: [String: String]
    let motions: [String: String]
    let elements: [String: String]
    let modalities: [String: String]
    let angles: [String: String]
    let moonPhases: [String: String]
    let chartKinds: [String: String]
    let formats: [String: String]

    func value(category: String, key: String) -> String? {
        switch category {
        case "bodies": bodies[key]
        case "zodiac": zodiac[key]
        case "aspects": aspects[key]
        case "aspectPhases": aspectPhases[key]
        case "motions": motions[key]
        case "elements": elements[key]
        case "modalities": modalities[key]
        case "angles": angles[key]
        case "moonPhases": moonPhases[key]
        case "chartKinds": chartKinds[key]
        case "formats": formats[key]
        default: nil
        }
    }
}

enum AstroTerms {
    private static let catalogs: [AppLanguage: AstroTermCatalog] = {
        var loaded: [AppLanguage: AstroTermCatalog] = [:]
        let decoder = JSONDecoder()
        for language in AppLanguage.allCases {
            guard let url = Bundle.main.url(forResource: "AstroTerms-\(language.rawValue)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let catalog = try? decoder.decode(AstroTermCatalog.self, from: data),
                  catalog.version == 1,
                  catalog.locale == language.rawValue
            else { continue }
            loaded[language] = catalog
        }
        return loaded
    }()

    static func value(_ category: String, _ key: String, language: AppLanguage) -> String {
        catalogs[language]?.value(category: category, key: key)
            ?? catalogs[.english]?.value(category: category, key: key)
            ?? key
    }

    static func house(_ number: Int, language: AppLanguage) -> String {
        String(
            format: value("formats", "house", language: language),
            locale: language.locale,
            arguments: [number]
        )
    }
}

extension AppLanguage {
    var locale: Locale { Locale(identifier: rawValue) }
}
