import SwiftUI

@MainActor
struct StelyraAgentChatView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var conversations: AgentConversationStore
    @StateObject private var assets: AgentChartAssetStore
    @StateObject private var analyses: AgentAnalysisAssetStore
    @StateObject private var account: AgentAccountCoordinator
    @StateObject private var storeKit: AgentStoreKitCoordinator
    @StateObject private var runs: AgentRunCoordinator

    @State private var conversationID: UUID?
    @State private var input = ""
    @State private var chips: [AgentDraftContextChip] = []
    @State private var sheet: Sheet?
    @State private var showsAccount = false
    @State private var showsAIConsent = false
    @State private var availableModels: [AgentModelOption] = []
    @State private var selectedModelID: String?

    private enum Sheet: String, Identifiable {
        case charts, themes, profiles, assets
        var id: String { rawValue }
    }

    init() {
        let conversationStore = AgentConversationStore()
        let assetStore = AgentChartAssetStore()
        let analysisStore = AgentAnalysisAssetStore()
        let credentialStore = AgentCredentialStore()
        let apiClient = AgentAPIClient()
        let accountCoordinator = AgentAccountCoordinator(client: apiClient, credentialStore: credentialStore)
        let storeKitCoordinator = AgentStoreKitCoordinator { [weak accountCoordinator] _, signedJWS in
            guard let accountCoordinator else { return false }
            return try await accountCoordinator.reconcileStoreTransaction(signedJWS: signedJWS)
        }
        let runCoordinator = AgentRunCoordinator(
            client: apiClient,
            toolExecutor: AgentAstrologyToolExecutor(assetStore: assetStore),
            conversations: conversationStore,
            analysisStore: analysisStore
        )

        _conversations = StateObject(wrappedValue: conversationStore)
        _assets = StateObject(wrappedValue: assetStore)
        _analyses = StateObject(wrappedValue: analysisStore)
        _account = StateObject(wrappedValue: accountCoordinator)
        _storeKit = StateObject(wrappedValue: storeKitCoordinator)
        _runs = StateObject(wrappedValue: runCoordinator)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if messages.isEmpty { emptyState }
                        else { messageList }
                        if let interaction = runs.pendingInteraction {
                            AgentInteractionView(interaction: interaction) { result in
                                Task { await runs.submitInteraction(result: result) }
                            } onDecline: {
                                Task {
                                    if interaction.kind == .planReview {
                                        await runs.cancelPendingRun()
                                    } else {
                                        await runs.submitInteraction(result: ["declined": .bool(true)])
                                    }
                                }
                            }
                        }
                        if runs.isWorking {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Analyzing…").font(.footnote).foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 150)
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle(currentConversationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsAccount = true } label: {
                        Image(systemName: account.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    }
                }
            }
        }
        .task {
            ensureConversation()
            storeKit.start()
            await account.refreshCredits()
            await loadModels()
            if account.isSignedIn, let conversationID {
                try? await account.ensureFreshSession()
                await runs.resumePersistedRun(
                    conversationID: conversationID,
                    localContext: AgentLocalContextSnapshot.from(model: model)
                )
            }
        }
        .sheet(item: $sheet) { item in sheetView(item) }
        .sheet(isPresented: $showsAccount) {
            StelyraAgentAccountView(
                account: account,
                storeKit: storeKit,
                onResetLocalData: { clearLocalUserData() },
                onDeleteLocalData: { clearLocalUserData() }
            )
        }
        .alert("Allow AI Analysis", isPresented: $showsAIConsent) {
            Button("Not Now", role: .cancel) { }
            Button("Allow") {
                model.grantAIConsent()
                submitDraft()
            }
        } message: {
            Text("StelyraAgent may send the birth date and time, birth city, selected people information, calculated astrology evidence, and messages in the active analysis to the AI provider. Precise coordinates and internal timezone calculation parameters remain on this iPhone.")
        }
    }

    private var messages: [AgentConversationMessage] {
        guard let conversationID else { return [] }
        return conversations.conversation(id: conversationID)?.messages ?? []
    }

    private var currentConversationTitle: String {
        guard let conversationID else { return "StelyraAgent" }
        return conversations.conversation(id: conversationID)?.title ?? "StelyraAgent"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("ASTROLOGY AGENT").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(AppTheme.violet)
                Text("Ask what matters in real life.").font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                Text("StelyraAgent can choose the local calculations it needs, while every chart remains viewable on your iPhone.")
                    .font(.subheadline).foregroundStyle(AppTheme.muted)
            }
            shortcutSection(title: "Themes", items: AgentThemeCatalog.homeShortcuts.map { ($0.title, $0.symbol) }) { title in
                if let theme = AgentThemeCatalog.all.first(where: { $0.title == title }) {
                    addChip(kind: .theme, value: theme.id, title: "Theme · \(theme.title)")
                }
            }
            shortcutSection(title: "Charts", items: [
                ("Natal", "circle"), ("Transit", "clock.arrow.circlepath"), ("Secondary", "arrow.triangle.2.circlepath"), ("Synastry", "person.2")
            ]) { title in
                let value: String
                switch title {
                case "Natal": value = AgentCapability.natal.rawValue
                case "Transit": value = AgentCapability.transit.rawValue
                case "Secondary": value = AgentCapability.secondary.rawValue
                default: value = AgentCapability.synastry.rawValue
                }
                addChip(kind: .chart, value: value, title: "Chart · \(title)")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Try asking").font(.headline).foregroundStyle(AppTheme.text)
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { input = suggestion } label: {
                        HStack { Text(suggestion).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.left") }
                            .font(.subheadline).foregroundStyle(AppTheme.text).padding(13)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var messageList: some View {
        ForEach(messages) { message in
            if message.kind == .chartReference {
                chartReference(message)
            } else {
                HStack {
                    if message.kind == .userMessage { Spacer(minLength: 44) }
                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(message.kind == .systemNotice ? AppTheme.muted : AppTheme.text)
                        .padding(12)
                        .background(message.kind == .userMessage ? AppTheme.violet.opacity(0.22) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    if message.kind != .userMessage { Spacer(minLength: 44) }
                }
            }
        }
    }

    private func chartReference(_ message: AgentConversationMessage) -> some View {
        let matching = message.chartAssetIDs.compactMap { id in assets.assets.first { $0.assetID == id } }
        return VStack(alignment: .leading, spacing: 10) {
            Text(message.text).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.muted)
            if matching.count >= 5 {
                Button { sheet = .assets } label: {
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill")
                        Text("\(matching.count) charts analyzed")
                        Spacer()
                        Text("View all charts").font(.caption)
                    }
                    .padding(13)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(matching) { asset in
                            Button { sheet = .assets } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Image(systemName: "circle.hexagongrid")
                                    Text(displayChartKind(asset.chartKind)).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(asset.displaySubjects.joined(separator: " + ")).font(.caption).foregroundStyle(AppTheme.muted).lineLimit(1)
                                }
                                .frame(width: matching.count == 1 ? 240 : 150, alignment: .leading)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(chips) { chip in
                            HStack(spacing: 5) {
                                Text(chip.title).font(.caption)
                                Button { chips.removeAll { $0.id == chip.id } } label: { Image(systemName: "xmark.circle.fill") }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(.thinMaterial, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            if !availableModels.isEmpty {
                HStack {
                    Spacer()
                    Menu {
                        ForEach(availableModels) { option in
                            Button { selectedModelID = option.id } label: {
                                Text("\(option.label) · \(option.creditsRequired) Credit\(option.creditsRequired == 1 ? "" : "s")")
                            }
                        }
                    } label: {
                        if let option = selectedModel {
                            Text("\(option.label) · \(option.creditsRequired) Credit\(option.creditsRequired == 1 ? "" : "s")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 9) {
                Menu {
                    Button("Charts", systemImage: "circle.hexagongrid") { sheet = .charts }
                    Button("Themes", systemImage: "sparkles") { sheet = .themes }
                    Button("Assets", systemImage: "tray.full") { sheet = .assets }
                    Button("Profiles", systemImage: "person.2") { sheet = .profiles }
                } label: {
                    Image(systemName: "plus").font(.headline).frame(width: 38, height: 38)
                        .background(.thinMaterial, in: Circle())
                }
                TextField("Ask StelyraAgent", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                Button(action: submitDraft) {
                    Image(systemName: "arrow.up").font(.headline).frame(width: 38, height: 38)
                        .background(input.trimmed.isEmpty ? Color.secondary.opacity(0.2) : AppTheme.violet, in: Circle())
                }
                .disabled(input.trimmed.isEmpty || runs.isWorking || runs.pendingInteraction != nil)
            }
            .padding(.horizontal, 14)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func sheetView(_ item: Sheet) -> some View {
        switch item {
        case .assets:
            AgentAssetsView(store: assets, conversationID: conversationID, language: model.language)
        case .themes:
            NavigationStack {
                List(AgentThemeCatalog.all) { theme in
                    Button { addChip(kind: .theme, value: theme.id, title: "Theme · \(theme.title)"); sheet = nil } label: {
                        Label(theme.title, systemImage: theme.symbol)
                    }
                }.navigationTitle("Themes")
            }
        case .charts:
            NavigationStack {
                List {
                    Section("You") {
                        ForEach(AgentCapability.allSupported.filter { !$0.isRelationship && !$0.isAdvanced }) { capability in
                            chartChoice(capability)
                        }
                    }
                    Section("Bonds") {
                        ForEach(AgentCapability.allSupported.filter { $0.isRelationship && !$0.isAdvanced }) { capability in
                            chartChoice(capability)
                        }
                    }
                    Section("Advanced") {
                        ForEach(AgentCapability.allSupported.filter(\.isAdvanced)) { capability in
                            chartChoice(capability)
                        }
                    }
                }.navigationTitle("Charts")
            }
        case .profiles:
            NavigationStack {
                List {
                    Button { addChip(kind: .person, value: "primary", title: "Person · You"); sheet = nil } label: { Text("You") }
                    ForEach(model.savedPeople) { person in
                        Button { addChip(kind: .person, value: person.id.uuidString, title: "Person · \(person.profile.name)"); sheet = nil } label: {
                            VStack(alignment: .leading) { Text(person.profile.name); Text(person.relationship.title(language: model.language)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }.navigationTitle("Profiles")
            }
        }
    }

    private func shortcutSection(title: String, items: [(String, String)], action: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.headline); Spacer(); Button("See All") { sheet = title == "Themes" ? .themes : .charts }.font(.caption) }
                .foregroundStyle(AppTheme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.0) { item in
                        Button { action(item.0) } label: {
                            VStack(alignment: .leading, spacing: 10) { Image(systemName: item.1); Text(item.0).font(.subheadline.weight(.semibold)) }
                                .foregroundStyle(AppTheme.text).frame(width: 126, height: 78, alignment: .leading).padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestions: [String] {
        var values = [
            "What should I focus on in the next three months?",
            "When might be a better time for a career change?",
            "What patterns keep showing up in my relationships?",
        ]
        if let person = model.savedPeople.first, !person.profile.name.trimmed.isEmpty {
            values.append("What should I understand about my relationship with \(person.profile.name)?")
        }
        return values
    }

    private func addChip(kind: AgentDraftContextKind, value: String, title: String) {
        guard !chips.contains(where: { $0.kind == kind && $0.value == value }) else { return }
        chips.append(.init(kind: kind, value: value, title: title))
    }

    private func submitDraft() {
        ensureConversation()
        guard let conversationID else { return }
        let question = input.trimmed
        guard !question.isEmpty else { return }
        guard account.isSignedIn else {
            conversations.append(.init(kind: .systemNotice, text: "Sign in with Apple is required before paid AI analysis. Your draft and selected local context remain on this iPhone."), to: conversationID)
            showsAccount = true
            return
        }
        guard model.aiConsentGranted else {
            showsAIConsent = true
            return
        }

        let submittedChips = chips
        input = ""
        chips = []
        Task {
            do {
                try await account.ensureFreshSession()
                await runs.send(
                    question: question,
                    chips: submittedChips,
                    conversationID: conversationID,
                    localContext: AgentLocalContextSnapshot.from(model: model),
                    clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1",
                    modelID: selectedModelID
                )
                await account.refreshCredits()
            } catch {
                conversations.append(.init(kind: .systemNotice, text: error.localizedDescription), to: conversationID)
            }
        }
    }

    private var selectedModel: AgentModelOption? {
        if let selectedModelID, let match = availableModels.first(where: { $0.id == selectedModelID }) { return match }
        return availableModels.first
    }

    private func loadModels() async {
        do {
            let models = try await runs.availableModels()
            availableModels = models
            if selectedModelID == nil || !models.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = models.first?.id
            }
        } catch {
            availableModels = []
            selectedModelID = nil
        }
    }

    private func clearLocalUserData() {
        conversations.removeAll()
        assets.removeAll()
        analyses.removeAll()
        ensureConversation(replace: true)
    }

    private func ensureConversation(replace: Bool = false) {
        if replace { conversationID = nil }
        if conversationID == nil { conversationID = conversations.conversations.first?.id ?? conversations.createConversation().id }
    }

    @ViewBuilder
    private func chartChoice(_ capability: AgentCapability) -> some View {
        Button {
            addChip(kind: .chart, value: capability.rawValue, title: "Chart · \(capability.displayTitle)")
            sheet = nil
        } label: {
            HStack {
                Text(capability.displayTitle)
                Spacer()
                if capability.isAdvanced {
                    Text("Advanced").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chartTitle(_ capability: AgentCapability) -> String { capability.displayTitle }

    private func displayChartKind(_ raw: String) -> String {
        AgentCapability(rawValue: raw).map(chartTitle) ?? raw
    }
}

private struct AgentInteractionView: View {
    let interaction: AgentInteraction
    let onSubmit: ([String: AgentJSONValue]) -> Void
    let onDecline: () -> Void

    @State private var selectedOption: String?
    @State private var fieldValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(interaction.kind == .planReview ? "Analysis" : "StelyraAgent needs one choice")
                .font(.caption.weight(.bold)).foregroundStyle(AppTheme.violet)
            Text(interaction.prompt).font(.headline).foregroundStyle(AppTheme.text)

            if !interaction.options.isEmpty {
                ForEach(interaction.options, id: \.self) { option in
                    Button {
                        selectedOption = option
                    } label: {
                        HStack {
                            Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                            Text(option)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(interaction.fields) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(field.label).font(.caption).foregroundStyle(AppTheme.muted)
                    if field.options.isEmpty {
                        TextField(field.label, text: Binding(
                            get: { fieldValues[field.id, default: ""] },
                            set: { fieldValues[field.id] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Picker(field.label, selection: Binding(
                            get: { fieldValues[field.id, default: field.options.first ?? ""] },
                            set: { fieldValues[field.id] = $0 }
                        )) {
                            ForEach(field.options, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
            }

            HStack {
                Button(interaction.kind == .planReview ? "Cancel" : "Use best judgment", action: onDecline)
                    .buttonStyle(.bordered)
                Spacer()
                Button(interaction.kind == .planReview ? "Analyze" : "Continue") {
                    var result: [String: AgentJSONValue] = ["approved": .bool(true)]
                    if let selectedOption { result["selection"] = .string(selectedOption) }
                    if !fieldValues.isEmpty {
                        result["fields"] = .object(fieldValues.mapValues(AgentJSONValue.string))
                    }
                    onSubmit(result)
                }
                .buttonStyle(.borderedProminent)
                .disabled(needsOption && selectedOption == nil)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var needsOption: Bool {
        !interaction.options.isEmpty && interaction.kind != .planReview
    }
}
