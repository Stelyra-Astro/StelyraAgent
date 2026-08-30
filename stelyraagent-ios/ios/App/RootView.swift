import SwiftUI

enum RootTab: Hashable {
    case agent
    case today
    case charts
    case ask
    case profile
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
	@ObservedObject private var commerce = CommerceStore.shared
    @State private var selection: RootTab = .agent
    @State private var initialProfileSetupRequested = false
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false

    var body: some View {
        Group {
            if onboardingCompleted || bypassesOnboardingForUITests {
                TabView(selection: $selection) {
                    StelyraAgentChatView()
                        .tag(RootTab.agent)
                        .tabItem {
                            Label("Agent", systemImage: "sparkles.rectangle.stack")
                        }

                    TodayView(selectedTab: $selection)
                        .tag(RootTab.today)
                        .tabItem {
                            Label(
                                localized("navigation.today", language: model.language),
                                systemImage: "sparkles"
                            )
                        }

                    ChartsView(selectedTab: $selection)
                        .tag(RootTab.charts)
                        .tabItem {
                            Label(
                                localized("charts.charts", language: model.language),
                                systemImage: "circle.hexagongrid"
                            )
                        }

                    AskView()
                        .tag(RootTab.ask)
                        .tabItem {
                            Label(
                                localized("navigation.ask", language: model.language),
                                systemImage: "sparkle.magnifyingglass"
                            )
                        }

                    ProfileView(initialSetupRequested: $initialProfileSetupRequested)
                        .tag(RootTab.profile)
                        .tabItem {
                            Label(
                                localized("profile.profile", language: model.language),
                                systemImage: "person.crop.circle"
                            )
                        }
                }
                .tint(AppTheme.violet)
            } else {
                OnboardingView(language: model.language) {
                    onboardingCompleted = true
                    selection = .profile
                    initialProfileSetupRequested = true
                }
            }
        }
        .dynamicTypeSize(model.fontSize.dynamicTypeSize)
        .task {
            await model.refresh()
        }
		.sheet(isPresented: $commerce.showsPaywall) { PremiumPaywallView(language: model.language) }
		.sheet(isPresented: $commerce.showsCredits) { CreditsPurchaseView(language: model.language) }
    }

    private var bypassesOnboardingForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["STELYRAAGENT_UI_TEST_LANGUAGE"] != nil
        #else
        false
        #endif
    }
}

struct ScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.background,
                AppTheme.backgroundAccent,
                AppTheme.background,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    let subtitle: String?

    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.footnote.weight(.bold))
                .tracking(1.7)
                .foregroundStyle(AppTheme.violet)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
