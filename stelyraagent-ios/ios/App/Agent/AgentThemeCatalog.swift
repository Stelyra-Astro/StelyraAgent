import Foundation

struct AgentThemeDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let symbol: String
}

enum AgentThemeCatalog {
    static let all: [AgentThemeDefinition] = [
        .init(id: "love", title: "Love & Relationships", symbol: "heart"),
        .init(id: "career", title: "Career & Purpose", symbol: "briefcase"),
        .init(id: "money", title: "Money & Growth", symbol: "chart.line.uptrend.xyaxis"),
        .init(id: "family", title: "Family & Home", symbol: "house"),
        .init(id: "self", title: "Self & Wellbeing", symbol: "person"),
        .init(id: "creativity", title: "Creativity & Expression", symbol: "paintpalette"),
        .init(id: "learning", title: "Learning & Exploration", symbol: "book"),
        .init(id: "direction", title: "Life Direction", symbol: "safari"),
    ]

    static let homeShortcuts = Array(all.prefix(4))
}
