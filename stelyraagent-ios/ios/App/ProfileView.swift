import PhotosUI
import AstroCore
import SwiftUI
import StoreKit
import UIKit
import Darwin

struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
	@ObservedObject private var commerce = CommerceStore.shared
    @Binding var initialSetupRequested: Bool
    @State private var showsSettings = false
    @State private var showsEditor = false
    @State private var showsCreditActivity = false
    @State private var isInitialProfileSetup = false
    @State private var editingPerson: SavedPerson?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center) {
                            Text(localized("profile.profile", language: model.language))
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button { showsSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel(localized("profile.settings", language: model.language))
                        }
                        profileHero
                        accountSummary
                        peopleSection
                        Text("\(localized("commerce.user-id", language: model.language)): \(commerce.userID.uuidString.lowercased())")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showsEditor) {
                ProfileEditorView(
                    profile: model.profile,
                    language: model.language,
                    onSkip: isInitialProfileSetup ? {
                        isInitialProfileSetup = false
                    } : nil
                ) { profile in
                    isInitialProfileSetup = false
                    model.profile = profile
                    Task { await model.refresh() }
                }
            }
            .sheet(item: $editingPerson) { person in
                SavedPersonEditorView(person: person, language: model.language) {
                    model.savePerson($0)
                } onDelete: {
                    if let index = model.savedPeople.firstIndex(where: { $0.id == person.id }) {
                        model.deletePeople(at: IndexSet(integer: index))
                    }
                }
            }
            .sheet(isPresented: $showsCreditActivity) {
                CreditActivitySheet(
                    entries: commerce.account?.creditLedger ?? [],
                    accountUnavailable: commerce.account == nil && commerce.accountSyncFailed,
                    language: model.language
                )
            }
            .task { await commerce.refreshAccountIfStale() }
            .onAppear {
                guard initialSetupRequested else { return }
                initialSetupRequested = false
                isInitialProfileSetup = true
                showsEditor = true
            }
        }
    }

    private var accountSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localized("commerce.your-plan", language: model.language))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Button { Task { await commerce.refreshAccount() } } label: {
                    if commerce.isRefreshingAccount {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.violet)
                    .disabled(commerce.isRefreshingAccount)
                    .accessibilityLabel(localized("commerce.refresh", language: model.language))
                Text(commerce.planTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(commerce.isPremium ? AppTheme.violet : AppTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((commerce.isPremium ? AppTheme.violet : AppTheme.muted).opacity(0.12), in: Capsule())
            }
            HStack(spacing: 10) {
                creditBucket(value: commerce.account?.credits.allowance, label: "credits.monthly")
                creditBucket(value: commerce.account?.credits.bonus, label: "credits.bonus")
                creditBucket(value: commerce.account?.credits.purchased, label: "credits.permanent")
            }
            HStack {
                Text(localized("credits.total", language: model.language)).font(.caption).foregroundStyle(AppTheme.muted)
                Spacer()
                Text(creditValue(commerce.account?.credits.availableTotal)).font(.title2.bold()).foregroundStyle(AppTheme.violet)
            }
            if let reserved = commerce.account?.credits.reserved, reserved > 0 {
                HStack {
                    Text(localized("credits.reserved", language: model.language)).font(.caption).foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(String(reserved)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                }
            }
            if commerce.account == nil, !commerce.accountSyncFailed {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(localized("commerce.refreshing-account", language: model.language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            if let renewal = commerce.account?.creditsRenewAt {
                HStack {
                    Text(localized("credits.renews", language: model.language)).font(.caption).foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(commerceDate(renewal)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                }
            }
            if commerce.isPremium, let expiry = commerce.account?.premiumExpiresAt {
                HStack {
                    Text(localized("commerce.premium-until", language: model.language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(commerceDate(expiry))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
            }
            HStack {
                if !commerce.isPremium {
                    Button(localized("premium.explore", language: model.language)) {
                        commerce.showsPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)
                }
                Button(localized("credits.buy", language: model.language)) {
                    commerce.showsCredits = true
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.violet)
                Spacer()
            }
            Button { showsCreditActivity = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(AppTheme.violet)
                    Text(localized("credits.activity", language: model.language))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(minHeight: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if commerce.accountSyncFailed {
                Text(localized("commerce.account-refresh-failed", language: model.language))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.coral)
            }
        }
        .cardSurface()
    }

    private func creditBucket(value: Int?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(creditValue(value)).font(.title2.bold()).foregroundStyle(AppTheme.text)
            Text(localized(label, language: model.language)).font(.caption2).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14))
    }

    private func creditValue(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }

    private func commerceDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var profileHero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ProfileAvatarView(profile: model.profile, size: 68)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.profile.name).font(.title2.weight(.bold)).foregroundStyle(AppTheme.text)
                    Text(model.profile.placeName).font(.subheadline).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Button(localized("profile.edit", language: model.language)) { showsEditor = true }
                    .font(.caption.weight(.bold)).foregroundStyle(AppTheme.violet)
            }
            Divider().overlay(AppTheme.line)
            birthDetails
        }
        .cardSurface()
    }

    private var birthDetails: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: "calendar",
                title: localized("profile.birth-date-time", language: model.language),
                value: formattedBirthDate
            )
            Divider().overlay(AppTheme.line)
            detailRow(
                icon: "mappin.and.ellipse",
                title: localized("profile.birth-place", language: model.language),
                value: model.profile.placeName
            )
        }
    }

    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: model.profile.birthDateUTC)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(AppTheme.muted)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("profile.people", language: model.language))
                        .font(.footnote.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.violet)
                    Text(localized("profile.people-you-know", language: model.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
                Spacer()
                Button {
                    editingPerson = SavedPerson.new(using: model.profile)
                } label: {
                    Label(
                        localized("profile.add", language: model.language),
                        systemImage: "plus"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if model.savedPeople.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .foregroundStyle(AppTheme.violet)
                    Text(
                        localized("profile.add-someone-once-then-reuse-their-birth-details-in-future-relationship-c", language: model.language)
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.savedPeople.enumerated()), id: \.element.id) { index, person in
                        Button {
                            editingPerson = person
                        } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(profile: person.profile, size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(person.profile.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(
                                        "\(person.relationship.title(language: model.language)) · \(person.profile.placeName)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                model.deletePeople(at: IndexSet(integer: index))
                            } label: {
                                Label(
                                    localized("profile.delete", language: model.language),
                                    systemImage: "trash"
                                )
                            }
                        }
                        if index < model.savedPeople.count - 1 {
                            Divider().overlay(AppTheme.line)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.line))
            }
        }
    }

}

private struct CreditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [CommerceAccount.LedgerEntry]
    let accountUnavailable: Bool
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                Group {
                    if accountUnavailable {
                        ContentUnavailableView(
                            localized("commerce.account-refresh-failed", language: language),
                            systemImage: "exclamationmark.triangle"
                        )
                    } else if entries.isEmpty {
                        ContentUnavailableView(
                            localized("credits.no-activity", language: language),
                            systemImage: "list.bullet.rectangle"
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(entries) { entry in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: activityIcon(entry.action))
                                            .foregroundStyle(entry.delta >= 0 ? AppTheme.violet : AppTheme.coral)
                                            .frame(width: 28, height: 28)
                                            .background((entry.delta >= 0 ? AppTheme.violet : AppTheme.coral).opacity(0.10), in: Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(activityTitle(entry))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            if let detail = activityDetail(entry) {
                                                Text(detail)
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                            Text(activityDate(entry.createdAt))
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer(minLength: 8)
                                        Text(entry.delta > 0 ? "+\(entry.delta)" : String(entry.delta))
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(entry.delta >= 0 ? AppTheme.violet : AppTheme.coral)
                                    }
                                    .padding(.vertical, 13)
                                    Divider().overlay(AppTheme.line)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                }
            }
            .navigationTitle(localized("credits.activity", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityLabel(localized("location.cancel", language: language))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func activityTitle(_ entry: CommerceAccount.LedgerEntry) -> String {
        switch entry.action {
        case "MONTHLY_BONUS_RENEW": localized("credits.activity.monthly-bonus", language: language)
        case "PRO_ALLOWANCE_RENEW": localized("credits.activity.pro-renew", language: language)
        case "ALLOWANCE_RENEW": entry.delta <= 2
            ? localized("credits.activity.monthly-bonus", language: language)
            : localized("credits.activity.pro-renew", language: language)
        case "PURCHASE": localized("credits.activity.purchase", language: language)
        case "WELCOME_BONUS": localized("credits.activity.welcome", language: language)
        case "ADMIN_GRANT": localized("credits.activity.grant", language: language)
        case "ADMIN_DEDUCT": localized("credits.activity.deduct", language: language)
        case "ADMIN_RESET": localized("credits.activity.reset", language: language)
        case "RESERVE": entry.reportStatus == "success"
            ? localized("credits.activity.used", language: language)
            : localized("credits.activity.reserved", language: language)
        case "REVOCATION": localized("credits.activity.revoked", language: language)
        default: localized("credits.activity.adjustment", language: language)
        }
    }

    private func activityDetail(_ entry: CommerceAccount.LedgerEntry) -> String? {
        if let scope = entry.scope, !scope.isEmpty {
            return reportTitle(scope)
        }
        switch entry.action {
        case "MONTHLY_BONUS_RENEW": return localized("credits.activity.monthly-bonus-detail", language: language)
        case "PRO_ALLOWANCE_RENEW": return localized("credits.activity.pro-renew-detail", language: language)
        case "ALLOWANCE_RENEW": return entry.delta <= 2
            ? localized("credits.activity.monthly-bonus-detail", language: language)
            : localized("credits.activity.pro-renew-detail", language: language)
        case "WELCOME_BONUS": return localized("credits.activity.welcome-detail", language: language)
        case "PURCHASE": return localized("credits.activity.purchase-detail", language: language)
        case "ADMIN_GRANT", "ADMIN_DEDUCT", "ADMIN_RESET": return localized("credits.activity.admin-detail", language: language)
        default: return nil
        }
    }

    private func reportTitle(_ scope: String) -> String {
        switch scope {
        case "chart.natal": localized("reports.natal-report", language: language)
        case "chart.current-sky": localized("reports.current-sky-report", language: language)
        case "chart.transit": localized("reports.transit-report", language: language)
        case "chart.secondary": localized("reports.progressed-report", language: language)
        case "chart.solar-return": localized("reports.solar-return-report", language: language)
        case "chart.synastry": localized("reports.synastry-report", language: language)
        case let value where value.hasPrefix("ask."): localized("credits.activity.ask", language: language)
        default: scope
        }
    }

    private func activityIcon(_ action: String) -> String {
        switch action {
        case "ALLOWANCE_RENEW", "MONTHLY_BONUS_RENEW", "PRO_ALLOWANCE_RENEW": "arrow.clockwise"
        case "PURCHASE": "cart.fill"
        case "WELCOME_BONUS": "gift.fill"
        case "ADMIN_GRANT": "plus.circle.fill"
        case "ADMIN_DEDUCT", "ADMIN_RESET", "REVOCATION": "minus.circle.fill"
        default: "sparkles"
        }
    }

    private func activityDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ProfileAvatarView: View {
    let profile: UserProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let data = profile.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(profile.initials.isEmpty ? "✦" : profile.initials)
                    .font(.system(size: size * 0.31, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.violet, AppTheme.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}

private struct SavedPersonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SavedPerson
    @State private var showsLocationSearch = false
    @State private var avatarItem: PhotosPickerItem?
    let language: AppLanguage
    let onSave: (SavedPerson) -> Void
    let onDelete: () -> Void

    init(
        person: SavedPerson,
        language: AppLanguage,
        onSave: @escaping (SavedPerson) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _draft = State(initialValue: person)
        self.language = language
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("charts.person", language: language)) {
                    HStack {
                        ProfileAvatarView(profile: draft.profile, size: 58)
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Label(
                                localized("profile.change-photo", language: language),
                                systemImage: "photo"
                            )
                        }
                        if draft.profile.avatarData != nil {
                            Button(localized("profile.remove", language: language), role: .destructive) {
                                draft.profile.avatarData = nil
                            }
                        }
                    }
                    TextField(
                        localized("profile.name", language: language),
                        text: $draft.profile.name
                    )
                    Picker(
                        localized("profile.relationship-to-me", language: language),
                        selection: $draft.relationship
                    ) {
                        ForEach(PersonRelationship.allCases) { relationship in
                            Text(relationship.title(language: language)).tag(relationship)
                        }
                    }
                }

                Section(localized("profile.birth", language: language)) {
                    DatePicker(
                        localized("charts.date-time", language: language),
                        selection: $draft.profile.birthDateUTC,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button {
                        showsLocationSearch = true
                    } label: {
                        HStack {
                            Label(draft.profile.placeName, systemImage: "map")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    LabeledContent(
                        localized("profile.time-zone", language: language),
                        value: draft.profile.timezoneID
                    )
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label(
                            localized("profile.delete-person", language: language),
                            systemImage: "trash"
                        )
                    }
                }
            }
            .environment(
                \.timeZone,
                TimeZone(identifier: draft.profile.timezoneID) ?? .current
            )
            .navigationTitle(localized("profile.person-details", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("location.cancel", language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("profile.save", language: language)) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || draft.profile.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || TimeZone(identifier: draft.profile.timezoneID) == nil
                    )
                }
            }
            .sheet(isPresented: $showsLocationSearch) {
                LocationSearchView(language: language) { apply($0) }
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { draft.profile.avatarData = data }
                    }
                }
            }
        }
    }

    private func apply(_ selection: LocationSelection) {
        draft.profile.placeName = selection.name == "Current Location"
            ? localized("profile.current-location", language: language)
            : selection.name
        draft.profile.latitude = selection.latitude
        draft.profile.longitude = selection.longitude
        draft.profile.timezoneID = selection.timezoneID
    }
}

private enum LocalDataClear: Identifiable {
    case reports
    case askHistory
    case aiCache
    case currentPersonArtifacts
    case chartArtifacts(ChartKind)
    case personArtifacts(SavedPerson)

    var id: String {
        switch self {
        case .reports: "reports"
        case .askHistory: "askHistory"
        case .aiCache: "aiCache"
        case .currentPersonArtifacts: "currentPersonArtifacts"
        case let .chartArtifacts(chart): "chartArtifacts.\(chart.rawValue)"
        case let .personArtifacts(person): "personArtifacts.\(person.id.uuidString)"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .reports:
            localized("profile.this-removes-all-saved-chart-reports-from-this-device", language: language)
        case .askHistory:
            localized("profile.this-removes-your-saved-horary-questions", language: language)
        case .aiCache:
            localized("profile.generated-interpretations-will-be-regenerated-next-time-you-open-them", language: language)
        case .currentPersonArtifacts:
            localized("profile.this-removes-locally-generated-chart-reports-linked-to-your-current-birt", language: language)
        case let .chartArtifacts(chart):
            localizedTemplate("dynamic.a254895f81", substitutions: ["value1": String(describing: chart.title(language: language))], language: language)
        case let .personArtifacts(person):
            localizedTemplate("dynamic.68196d8f57", substitutions: ["value1": String(describing: person.profile.name)], language: language)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false
	@State private var legalDocument: LegalDocument?

    var body: some View {
        List {
            NavigationLink {
                CommerceSettingsView()
            } label: {
                Label(localized("commerce.account", language: model.language), systemImage: "star.circle")
            }
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label(localized("profile.appearance", language: model.language), systemImage: "circle.lefthalf.filled")
            }
            NavigationLink {
                InterpretationDefaultsSettingsView()
            } label: {
                Label(localized("profile.interpretation-defaults", language: model.language), systemImage: "slider.horizontal.3")
            }
            NavigationLink {
                LanguageSettingsView()
            } label: {
                Label(localized("profile.language", language: model.language), systemImage: "globe")
            }
            NavigationLink {
                LocalDataSettingsView()
            } label: {
                Label(localized("profile.local-data", language: model.language), systemImage: "internaldrive")
            }
            NavigationLink {
                FeedbackView(language: model.language)
            } label: {
                Label(localized("insight.current-sky.support", language: model.language), systemImage: "questionmark.bubble")
            }
            NavigationLink {
                AboutSettingsView()
            } label: {
                Label(localized("profile.about", language: model.language), systemImage: "info.circle")
            }
			Button {
				legalDocument = .terms
			} label: {
				Label(localized("legal.terms", language: model.language), systemImage: "doc.text")
			}
			Button {
				legalDocument = .privacy
			} label: {
				Label(localized("legal.privacy", language: model.language), systemImage: "hand.raised")
			}
            Button {
                onboardingCompleted = false
            } label: {
                Label(localized("onboarding.show-again", language: model.language), systemImage: "rectangle.on.rectangle")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(localized("profile.settings", language: model.language))
        .navigationBarTitleDisplayMode(.inline)
		.sheet(item: $legalDocument) {
			LegalDocumentView(document: $0, language: model.language)
		}
    }
}

private struct CommerceSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared
    @State private var showManageSubscriptions = false
    var body: some View {
        Form {
            Section {
                LabeledContent(localized("commerce.plan", language: model.language), value: commerce.planTitle)
                LabeledContent(localized("credits.monthly", language: model.language), value: creditValue(commerce.account?.credits.allowance))
                LabeledContent(localized("credits.bonus", language: model.language), value: creditValue(commerce.account?.credits.bonus))
                LabeledContent(localized("credits.permanent", language: model.language), value: creditValue(commerce.account?.credits.purchased))
                LabeledContent(localized("credits.total", language: model.language), value: creditValue(commerce.account?.credits.availableTotal))
                if let reserved = commerce.account?.credits.reserved, reserved > 0 {
                    LabeledContent(localized("credits.reserved", language: model.language), value: String(reserved))
                }
                if let renewal = commerce.account?.creditsRenewAt {
                    LabeledContent(localized("credits.renews", language: model.language), value: formatted(renewal))
                }
                if let expiry = commerce.account?.premiumExpiresAt, commerce.isPremium {
                    LabeledContent(localized("commerce.premium-until", language: model.language), value: formatted(expiry))
                }
                Text("\(localized("commerce.user-id", language: model.language)): \(commerce.userID.uuidString.lowercased())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Section {
                if !commerce.isPremium {
                    Button(localized("premium.explore", language: model.language)) { commerce.showsPaywall = true }
                }
                Button(localized("credits.buy", language: model.language)) { commerce.showsCredits = true }
                Button(localized("premium.restore", language: model.language)) { Task { await commerce.restore() } }
                Button {
                    Task { await commerce.refreshAccount() }
                } label: {
                    if commerce.isRefreshingAccount {
                        ProgressView()
                    } else {
                        Text(localized("commerce.refresh", language: model.language))
                    }
                }
                .disabled(commerce.isRefreshingAccount)
                if commerce.isPremium {
                    Button(localized("commerce.cancel-subscription", language: model.language), role: .destructive) {
                        showManageSubscriptions = true
                    }
                }
            }
            if commerce.accountSyncFailed {
                Section {
                    Text(localized("commerce.account-refresh-failed", language: model.language))
                        .foregroundStyle(AppTheme.coral)
                }
            }
        }
        .task { await commerce.refreshAccountIfStale() }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .settingsDetailStyle(title: localized("commerce.account", language: model.language))
    }

    private func formatted(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func creditValue(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker(localized("profile.theme", language: model.language), selection: $model.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title(language: model.language)).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Picker(localized("profile.text-size", language: model.language), selection: $model.fontSize) {
                ForEach(AppFontSize.allCases) { size in
                    Text(size.title(language: model.language)).tag(size)
                }
            }
            .pickerStyle(.navigationLink)
        }
        .settingsDetailStyle(title: localized("profile.appearance", language: model.language))
    }
}

private struct InterpretationDefaultsSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ChartKind.allCases) { chart in
                    Picker(
                        chart.title(language: model.language),
                        selection: Binding(
                            get: { model.preset(for: chart) },
                            set: { model.setPreset($0, for: chart) }
                        )
                    ) {
                        ForEach(CalculationPreset.consumerCases) { preset in
                            Text(preset.title(language: model.language)).tag(preset)
                        }
                    }
                }
            } footer: {
                Text(localized("profile.modern-and-classical-change-how-each-chart-is-calculated", language: model.language))
            }
        }
        .settingsDetailStyle(title: localized("profile.interpretation-defaults", language: model.language))
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker(localized("profile.app-language", language: model.language), selection: $model.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.inline)
        }
        .settingsDetailStyle(title: localized("profile.language", language: model.language))
    }
}

private struct LocalDataSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared
    @State private var pendingClear: LocalDataClear?
    @State private var confirmsAccountDeletion = false
    @State private var accountDeletionCompleted = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    localized("profile.allow-new-ai-generation", language: model.language),
                    isOn: Binding(
                        get: { model.aiConsentGranted },
                        set: { $0 ? model.grantAIConsent() : model.revokeAIConsent() }
                    )
                )
                Text(localized("profile.ai-assistance-disclosure", language: model.language))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Button { pendingClear = .reports } label: {
                    Label(localized("profile.clear-saved-reports", language: model.language), systemImage: "doc.text")
                }
                Button { pendingClear = .askHistory } label: {
                    Label(localized("profile.clear-ask-history", language: model.language), systemImage: "questionmark.circle")
                }
                Button { pendingClear = .aiCache } label: {
                    Label(localized("profile.clear-generated-content-cache", language: model.language), systemImage: "sparkles")
                }
                Menu {
                    Button(model.profile.name) { pendingClear = .currentPersonArtifacts }
                    ForEach(model.savedPeople) { person in
                        Button(person.profile.name) { pendingClear = .personArtifacts(person) }
                    }
                } label: {
                    Label(localized("profile.clear-by-person", language: model.language), systemImage: "person.crop.circle.badge.minus")
                }
                Menu {
                    ForEach(ChartKind.allCases) { chart in
                        Button(chart.title(language: model.language)) { pendingClear = .chartArtifacts(chart) }
                    }
                } label: {
                    Label(localized("profile.clear-by-chart-type", language: model.language), systemImage: "square.stack.3d.up.slash")
                }
            } footer: {
                Text(localized("profile.clearing-removes-data-stored-on-this-device-only", language: model.language))
            }

			Section {
				Toggle(localized("icloud.backup-toggle", language: model.language), isOn: $model.iCloudBackupEnabled)
				Button(localized("icloud.backup-now", language: model.language)) { Task { await model.saveICloudBackup() } }
				Button(localized("icloud.restore", language: model.language)) { Task { await model.restoreICloudBackup() } }
				if !model.iCloudBackupStatus.isEmpty { Text(model.iCloudBackupStatus).font(.footnote).foregroundStyle(.secondary) }
			} header: {
				Text(localized("icloud.title", language: model.language))
			} footer: {
				Text(localized("icloud.description", language: model.language))
			}

            Section {
                Button(localized("commerce.delete-account", language: model.language), role: .destructive) {
                    confirmsAccountDeletion = true
                }
                .disabled(commerce.isDeletingAccount)
                if commerce.isDeletingAccount { ProgressView() }
                if commerce.accountDeletionFailed {
                    Text(localized("commerce.delete-account-failed", language: model.language))
                        .foregroundStyle(AppTheme.coral)
                }
				if commerce.accountDeletionRequiresMediaPurchasesSignIn {
					Text(localized("commerce.delete-account-media-purchases-required", language: model.language))
						.foregroundStyle(AppTheme.coral)
				}
            } footer: {
                Text(localized("commerce.delete-account-summary", language: model.language))
            }
        }
        .settingsDetailStyle(title: localized("profile.local-data", language: model.language))
        .confirmationDialog(
            localized("profile.clear-data", language: model.language),
            isPresented: Binding(
                get: { pendingClear != nil },
                set: { if !$0 { pendingClear = nil } }
            ),
            presenting: pendingClear
        ) { item in
            Button(localized("profile.clear", language: model.language), role: .destructive) {
                switch item {
                case .reports: model.clearReports()
                case .askHistory: model.clearAskHistory()
                case .aiCache: model.clearAICache()
                case .currentPersonArtifacts: model.clearGeneratedArtifactsForCurrentPerson()
                case let .chartArtifacts(chart): model.clearGeneratedArtifacts(for: chart)
                case let .personArtifacts(person): model.clearGeneratedArtifacts(for: person)
                }
                pendingClear = nil
            }
            Button(localized("location.cancel", language: model.language), role: .cancel) {
                pendingClear = nil
            }
        } message: { item in
            Text(item.message(language: model.language))
        }
        .confirmationDialog(
            localized("commerce.delete-account", language: model.language),
            isPresented: $confirmsAccountDeletion,
            titleVisibility: .visible
        ) {
            Button(localized("commerce.delete-account-confirm", language: model.language), role: .destructive) {
                Task {
                    if await commerce.deleteAccount() {
                        await model.erasePersonalDataForAccountDeletion()
                        accountDeletionCompleted = true
                    }
                }
            }
            Button(localized("location.cancel", language: model.language), role: .cancel) {}
        } message: {
            Text(localized("commerce.delete-account-warning", language: model.language))
        }
        .alert(localized("commerce.delete-account-complete", language: model.language), isPresented: $accountDeletionCompleted) {
            Button(localized("common.done", language: model.language)) {}
        } message: {
            Text(localized("commerce.delete-account-complete-message", language: model.language))
        }
    }
}

private struct AboutSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            LabeledContent(localized("profile.version", language: model.language), value: appVersion)
            LabeledContent(localized("profile.calculation", language: model.language), value: "Swiss Ephemeris")
            LabeledContent(localized("profile.editorial-content", language: model.language), value: "© 2026 StelyraAgent")
            Link(localized("insight.current-sky.support", language: model.language), destination: Self.supportEmailURL)
            Link(localized("profile.source-code", language: model.language), destination: Self.sourceCodeURL)
            NavigationLink(localized("profile.open-source-licenses", language: model.language)) {
                LicenseView(language: model.language)
            }
        }
        .settingsDetailStyle(title: localized("profile.about", language: model.language))
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        #if DEBUG
            return "\(version) (\(build)) Debug"
        #else
            return "\(version) (\(build))"
        #endif
    }

    private static let sourceCodeURL = URL(string: "https://github.com/Stelyra-Astro/stelyraagent-ios")!
    private static let supportEmailURL = URL(string: "mailto:Stelyra-Astro@proton.me")!
}

private extension View {
    func settingsDetailStyle(title: String) -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bug
    case feature
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .bug: localized("profile.bug", language: language)
        case .feature: localized("profile.feature", language: language)
        case .other: localized("settings.other", language: language)
        }
    }
}

private struct FeedbackRequestBody: Encodable {
    let type: String
    let content: String
    let contact: String
}

private enum FeedbackSubmissionError: LocalizedError {
    case invalidResponse
    case rejected(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The feedback service returned an invalid response."
        case let .rejected(status): "The feedback service returned status \(status)."
        }
    }
}

private enum FeedbackService {
    private static let endpoint = URL(
        string: "https://aaadmin.xiaoguiwk.top/v1/feedback"
    )!

    static func submit(
        category: FeedbackCategory,
        content: String,
        contact: String
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FeedbackRequestBody(
                type: category.rawValue,
                content: content,
                contact: contact
            )
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackSubmissionError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw FeedbackSubmissionError.rejected(http.statusCode)
        }
    }
}

private struct FeedbackView: View {
    let language: AppLanguage
    @State private var category: FeedbackCategory = .bug
    @State private var subject = ""
    @State private var message = ""
    @State private var contact = ""
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var lastSubmission: String?

    var body: some View {
        Form {
            Section(localized("profile.feedback-type", language: language)) {
                Picker(
                    localized("profile.type", language: language),
                    selection: $category
                ) {
                    ForEach(FeedbackCategory.allCases) { item in
                        Text(item.title(language: language)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(localized("feedback.details.section", language: language)) {
                TextField(
                    localized("profile.short-title", language: language),
                    text: $subject
                )
                TextField(
                    localized("profile.what-happened-or-what-would-you-like-us-to-add", language: language),
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(5 ... 12)
                TextField(
                    localized("profile.contact-optional", language: language),
                    text: $contact
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView().padding(.trailing, 6)
                        }
                        Text(
                            isSubmitting
                                ? localized("profile.sending", language: language)
                                : localized("profile.send-feedback", language: language)
                        )
                        .font(AppTypography.label)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .disabled(isSubmitting || subject.trimmed.isEmpty || message.trimmed.isEmpty)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        localized("profile.feedback-uses-the-network-and-includes-the-app-version-and-device-model", language: language)
                    )
                    Text(localized("profile.feedback-bonus-credits-hint", language: language))
                }
                .font(AppTypography.supporting)
            }

            if let resultMessage {
                Section {
                    Label(
                        resultMessage,
                        systemImage: lastSubmission == nil
                            ? "checkmark.circle.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(lastSubmission == nil ? AppTheme.mint : AppTheme.amber)
                    if let lastSubmission {
                        Button {
                            UIPasteboard.general.string = lastSubmission
                            self.resultMessage = localized("profile.feedback-text-copied", language: language)
                            self.lastSubmission = nil
                        } label: {
                            Label(
                                localized("profile.copy-feedback-text", language: language),
                                systemImage: "doc.on.doc"
                            )
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
        .navigationTitle(localized("profile.report", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        let payload = composedMessage
        isSubmitting = true
        resultMessage = nil
        lastSubmission = nil
        Task {
            do {
                try await FeedbackService.submit(
                    category: category,
                    content: payload,
                    contact: contact.trimmed
                )
                await MainActor.run {
                    isSubmitting = false
                    subject = ""
                    message = ""
                    contact = ""
                    resultMessage = localized("profile.feedback-sent-thank-you", language: language)
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    lastSubmission = payload
                    resultMessage = localized("profile.could-not-send-feedback-you-can-copy-it-and-try-again-later", language: language)
                }
            }
        }
    }

    private var composedMessage: String {
        """
        \(subject.trimmed)

        \(message.trimmed)

        App: StelyraAgent 0.1.0
        Device: \(DeviceModel.current)
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Locale: \(language.rawValue)
        """
    }
}

private enum DeviceModel {
    static var current: String {
        var info = utsname()
        uname(&info)
        let identifier = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let names = [
            "iPhone13,1": "iPhone 12 mini",
            "iPhone18,2": "iPhone 17 Pro Max",
        ]
        return names[identifier].map { "\($0) (\(identifier))" } ?? identifier
    }
}

private struct LicenseView: View {
    let language: AppLanguage

    var body: some View {
        List {
			Section(localized("license.required-notices", language: language)) {
				Text(localized("license.swiss-attribution", language: language)).font(.footnote)
			}
            Section(localized("license.swiss-ephemeris", language: language)) {
                Text(
                    localized("profile.swiss-ephemeris-2-10-3-is-used-under-the-gnu-affero-general-public-licen", language: language)
                )
                .font(.footnote)
                NavigationLink(
                    localized("profile.swiss-ephemeris-license-notice", language: language)
                ) {
                    LicenseTextView(
                        title: localized("license.swiss-ephemeris", language: language),
                        resource: "LICENSE",
                        extension: nil,
                        language: language
                    )
                }
                NavigationLink(localized("profile.gnu-agpl-3-0", language: language)) {
                    LicenseTextView(
                        title: localized("license.gnu-agpl-3-0", language: language),
                        resource: "agpl-3.0",
                        extension: "txt",
                        language: language
                    )
                }
            }

            Section(localized("profile.content-rights", language: language)) {
                Text(
                    localized("profile.original-interpretations-translations-editorial-selection-and-arrangemen", language: language)
                )
                .font(.footnote)
            }
        }
        .navigationTitle(localized("profile.licenses", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseTextView: View {
    let title: String
    let resource: String
    let `extension`: String?
    let language: AppLanguage

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(text)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: `extension`),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return localized("profile.license-text-is-unavailable", language: language)
        }
        return text
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UserProfile
    @State private var showsLocationSearch = false
    @State private var avatarItem: PhotosPickerItem?
    let language: AppLanguage
    let onSkip: (() -> Void)?
    let onSave: (UserProfile) -> Void

    init(
        profile: UserProfile,
        language: AppLanguage,
        onSkip: (() -> Void)? = nil,
        onSave: @escaping (UserProfile) -> Void
    ) {
        _draft = State(initialValue: profile)
        self.language = language
        self.onSkip = onSkip
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("profile.identity", language: language)) {
                    HStack {
                        ProfileAvatarView(profile: draft, size: 58)
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            Label(
                                localized("profile.change-photo", language: language),
                                systemImage: "photo"
                            )
                        }
                        if draft.avatarData != nil {
                            Button(localized("profile.remove", language: language), role: .destructive) {
                                draft.avatarData = nil
                            }
                        }
                    }
                    TextField(localized("profile.name", language: language), text: $draft.name)
                }
                Section(localized("profile.birth", language: language)) {
                    DatePicker(
                        localized("charts.date-time", language: language),
                        selection: $draft.birthDateUTC,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Button {
                        showsLocationSearch = true
                    } label: {
                        HStack {
                            Label(draft.placeName, systemImage: "map")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    LabeledContent(
                        localized("profile.time-zone", language: language),
                        value: draft.timezoneID
                    )
                }
            }
            .environment(\.timeZone, TimeZone(identifier: draft.timezoneID) ?? .current)
            .navigationTitle(localized("profile.birth-details", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onSkip == nil
                           ? localized("location.cancel", language: language)
                           : localized("onboarding.skip", language: language)) {
                        onSkip?()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("profile.save", language: language)) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(
                        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || TimeZone(identifier: draft.timezoneID) == nil
                    )
                }
            }
            .sheet(isPresented: $showsLocationSearch) {
                LocationSearchView(language: language) { selection in
                    apply(selection)
                }
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run { draft.avatarData = data }
                    }
                }
            }
        }
    }

    private func apply(_ selection: LocationSelection) {
        draft.placeName = selection.name == "Current Location"
            ? localized("profile.current-location", language: language)
            : selection.name
        draft.latitude = selection.latitude
        draft.longitude = selection.longitude
        draft.timezoneID = selection.timezoneID
    }
}
