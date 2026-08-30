import Foundation

struct AgentLocalMemorySnapshot: Codable, Equatable, Sendable {
    let conversationGoal: String?
    let chartAssetRefs: [String]
    let previousConclusions: [String]
    let analysisRefs: [String]
}

enum AgentLocalMemoryBuilder {
    static func build(
        conversation: AgentConversation?,
        analyses: [AgentAnalysisAsset]
    ) -> AgentLocalMemorySnapshot? {
        guard let conversation else { return nil }

        let goal: String?
        if conversation.title != "StelyraAgent", !conversation.title.trimmed.isEmpty {
            goal = String(conversation.title.prefix(240))
        } else if let firstUser = conversation.messages.first(where: { $0.kind == .userMessage })?.text,
                  !firstUser.trimmed.isEmpty {
            goal = String(firstUser.prefix(240))
        } else {
            goal = nil
        }

        let recentAnalyses = Array(analyses.prefix(3))
        let previousConclusions = recentAnalyses.map { String($0.finalAnswer.prefix(600)) }
        let analysisRefs = analyses.prefix(6).map { $0.analysisID.uuidString }
        let chartRefs = conversation.chartAssetRefs.suffix(12).map(\.uuidString)

        guard goal != nil || !chartRefs.isEmpty || !previousConclusions.isEmpty || !analysisRefs.isEmpty else {
            return nil
        }

        return AgentLocalMemorySnapshot(
            conversationGoal: goal,
            chartAssetRefs: chartRefs,
            previousConclusions: previousConclusions,
            analysisRefs: analysisRefs
        )
    }
}
