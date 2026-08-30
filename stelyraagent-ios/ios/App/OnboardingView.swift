import SwiftUI

struct OnboardingView: View {
    let language: AppLanguage
    let onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 20) {
                TabView(selection: $page) {
                    featurePage.tag(0)
                    plansPage.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page == 0 {
                        withAnimation { page = 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page == 0
                         ? localized("onboarding.next", language: language)
                         : localized("onboarding.get-started", language: language))
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var featurePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                onboardingHeader(
                    symbol: "sparkles",
                    title: localized("onboarding.welcome-title", language: language),
                    message: localized("onboarding.welcome-message", language: language)
                )
                featureRow("sparkles", "onboarding.today")
                featureRow("circle.hexagongrid", "onboarding.charts")
                featureRow("sparkle.magnifyingglass", "onboarding.ask")
                featureRow("person.crop.circle", "onboarding.profile")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private var plansPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                onboardingHeader(
                    symbol: "star.circle.fill",
                    title: localized("onboarding.plans-title", language: language),
                    message: localized("onboarding.plans-message", language: language)
                )
                planCard(
                    title: "Free",
                    symbol: "person.crop.circle",
                    items: ["onboarding.free-core", "onboarding.free-credits", "onboarding.free-people"]
                )
                planCard(
                    title: "Pro",
                    symbol: "star.fill",
                    items: ["onboarding.premium-insights", "onboarding.premium-credits", "onboarding.premium-people"]
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func onboardingHeader(symbol: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(AppTheme.violet)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(message)
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featureRow(_ symbol: String, _ key: String) -> some View {
        Label(localized(key, language: language), systemImage: symbol)
            .font(.headline)
            .foregroundStyle(AppTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
    }

    private func planCard(title: String, symbol: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.violet)
            ForEach(items, id: \.self) { key in
                Label(localized(key, language: language), systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
