import XCTest

final class VisualRegressionTests: XCTestCase {
    @MainActor
    func testLightModeScreensAndChartsSmokeTest() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Current Chapter"].waitForExistence(timeout: 30))
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Current Chapter")).count,
            1,
            "The section heading should remain, but the duplicate label inside the first card must be removed"
        )
        XCTAssertTrue(
            app.staticTexts["Calculating locally…"].waitForNonExistence(timeout: 5),
            "The blocking launch calculation state should disappear once the essential snapshots are ready"
        )
        let currentChapterCard = app.descendants(matching: .any)["today-current-chapter-card"]
        XCTAssertTrue(currentChapterCard.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(
            currentChapterCard.frame.maxX,
            app.frame.maxX - 12,
            "The Current Chapter card must stay inside the iPhone 12 mini viewport"
        )
        XCTAssertTrue(app.buttons["Reports"].exists)
        let upcomingSky = app.staticTexts["Upcoming Sky Events"]
        scrollTo(upcomingSky, in: app)
        XCTAssertTrue(upcomingSky.exists)

        let chartsTab = app.tabBars.buttons["Charts"]
        chartsTab.tap()
        XCTAssertTrue(chartsTab.isSelected)

        let askTab = app.tabBars.buttons["Ask"]
        askTab.tap()
        XCTAssertTrue(askTab.isSelected)
        XCTAssertTrue(app.staticTexts["Will It Happen?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Which One?"].exists)
        XCTAssertTrue(app.staticTexts["Find the Best Time"].exists)

        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
        let people = app.staticTexts["People you know"]
        scrollTo(people, in: app)
        XCTAssertTrue(people.exists)

        app.buttons["Settings"].tap()
        let appearance = app.buttons["Appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.tap()
        XCTAssertTrue(app.staticTexts["Text size"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Settings"].tap()
        let support = app.buttons["Support"]
        XCTAssertTrue(support.waitForExistence(timeout: 5))
        support.tap()
        XCTAssertTrue(app.staticTexts["Feedback type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bug"].exists)
        XCTAssertTrue(app.buttons["Feature"].exists)
        XCTAssertTrue(app.buttons["Other"].exists)
    }

    @MainActor
    func testDarkModeCoreScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()
        XCTAssertTrue(profileTab.isSelected)
    }

    @MainActor
    func testSettingsLegalDocumentsStayBetweenAboutAndWelcomeGuide() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "light"
        app.launch()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 20))
        profileTab.tap()
        app.buttons["Settings"].tap()

        let about = app.buttons["About"]
        let terms = app.buttons["Terms of Use"]
        let privacy = app.buttons["Privacy Policy"]
        let welcome = app.buttons["Show Welcome Guide Again"]
        scrollTo(about, in: app)
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(terms.waitForExistence(timeout: 5))
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        XCTAssertTrue(welcome.waitForExistence(timeout: 5))
        XCTAssertLessThan(about.frame.midY, terms.frame.midY)
        XCTAssertLessThan(terms.frame.midY, privacy.frame.midY)
        XCTAssertLessThan(privacy.frame.midY, welcome.frame.midY)

        terms.tap()
        XCTAssertTrue(app.navigationBars["Terms of Use"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommerceEntryButtonsOpenPurchaseSheets() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "light"
        app.launch()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 20))
        profileTab.tap()

        let explore = app.buttons["Explore Pro"]
        scrollToHittable(explore, in: app)
        XCTAssertTrue(explore.isHittable)
        explore.tap()
        XCTAssertTrue(app.staticTexts["STELYRAAGENT PRO"].waitForExistence(timeout: 5))
        let proCancel = app.buttons["Cancel"]
        scrollToHittable(proCancel, in: app)
        XCTAssertTrue(proCancel.isHittable)
        proCancel.tap()
        XCTAssertTrue(app.staticTexts["STELYRAAGENT PRO"].waitForNonExistence(timeout: 3))

        let buyCredits = app.buttons["Buy Credits"]
        scrollToHittable(buyCredits, in: app)
        XCTAssertTrue(buyCredits.isHittable)
        buyCredits.tap()
        XCTAssertTrue(app.staticTexts["Need more reports?"].waitForExistence(timeout: 5))
        let creditsCancel = app.buttons["Cancel"]
        scrollToHittable(creditsCancel, in: app)
        XCTAssertTrue(creditsCancel.isHittable)
        creditsCancel.tap()
        XCTAssertTrue(app.staticTexts["Need more reports?"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testEventDrivenCardsRender() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_PREMIUM"] = "1"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()
        XCTAssertTrue(app.staticTexts["Charts"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Charts"].waitForExistence(timeout: 8), "Charts screen did not become visible")

        // Dismiss the AI consent alert if the simulator is online.
        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        func select(_ label: String, replacing previousCard: String? = nil) {
            scrollToTop(app)
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing chart selector button: \(label)")
            button.tap()
            if let previousCard {
                XCTAssertTrue(
                    app.staticTexts[previousCard].waitForNonExistence(timeout: 40),
                    "Previous chart did not finish switching from \(previousCard)"
                )
            }
        }

        func find(_ label: String) {
            scrollToTop(app)
            let element = app.staticTexts[label]
            var found = element.waitForExistence(timeout: 6)
            var swipes = 0
            while !found, swipes < 26 {
                app.swipeUp()
                swipes += 1
                usleep(250_000)
                found = element.exists
            }
            XCTAssertTrue(found, "Expected card \(label) to be visible")
        }

        // Natal is the default chart; its cards must render without errors.
        select("Natal", replacing: "Current Story")
        assertNoCardError(app)
        find("Natal interpretation")
        find("CORE PERSONALITY")

        select("Current Sky", replacing: "Natal interpretation")
        assertNoCardError(app)
        find("SKY NOW")
        find("Sign changes")
        find("Upcoming 7 days")

        select("Transits", replacing: "Sky overview")
        assertNoCardError(app)
        find("How the strongest cycles combine")
        find("Transit Timeline")

        select("Progressed", replacing: "Current Story")
        assertNoCardError(app)
        find("CURRENT DEVELOPMENT")
        find("Progressed moon")
        find("Turning points")

        select("Solar Return", replacing: "Developmental chapter")
        assertNoCardError(app)
        find("YEAR THEME")
        find("Year timeline")

        select("Synastry", replacing: "Year theme")
        assertNoCardError(app)
        find("Relationship overview")
        find("Elena Hart and Julian Mercer")
    }

    @MainActor
    func testModernTransitPrototypeCards() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_PREMIUM"] = "1"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()

        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        scrollToTop(app)
        let currentSky = app.buttons["Current Sky"]
        XCTAssertTrue(currentSky.waitForExistence(timeout: 10))
        currentSky.tap()
        let transits = app.buttons["Transits"]
        XCTAssertTrue(transits.waitForExistence(timeout: 10))
        transits.tap()
        XCTAssertTrue(app.staticTexts["Current Story"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["How the strongest cycles combine"].exists)

        scrollToHittable(app.buttons["Long-term"], in: app)
        XCTAssertTrue(app.staticTexts["Current Cycles"].exists)
        XCTAssertTrue(app.staticTexts["One theme per time scale"].exists)
        XCTAssertTrue(app.buttons["Long-term"].exists)
        XCTAssertTrue(app.buttons["Current"].exists)
        XCTAssertTrue(app.buttons["Daily"].exists)
        attachScreenshot(named: "modern-transit-current-cycles")

        scrollToHittable(app.staticTexts["Transit Timeline"], in: app)
        XCTAssertTrue(app.staticTexts["Start · Exact · Return · End"].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'interpretation unavailable'")
        ).firstMatch.exists)
        attachScreenshot(named: "modern-transit-timeline")

        scrollToHittable(app.staticTexts["Planet Paths"], in: app)
        XCTAssertTrue(app.staticTexts["Where the current planets are moving"].exists)
        let howItWorks = app.buttons["transit-planet-paths-how-it-works"]
        XCTAssertTrue(howItWorks.waitForExistence(timeout: 5))
        howItWorks.tap()
        XCTAssertTrue(app.staticTexts["Why separate it"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Difference from Active Transits"].exists)
        attachScreenshot(named: "modern-transit-planet-paths-drawer")
        app.buttons["Done"].tap()

        scrollToHittable(app.staticTexts["Life Areas"], in: app)
        XCTAssertTrue(app.staticTexts["Activity, not fortune"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Activity reflects transiting houses'")
        ).firstMatch.exists)
        attachScreenshot(named: "modern-transit-life-areas")

        scrollToHittable(app.staticTexts["Active Transits"], in: app)
        XCTAssertTrue(app.staticTexts["Complete filtered list"].exists)
        XCTAssertTrue(app.buttons["All"].exists)
        XCTAssertTrue(app.buttons["Long-term"].exists)
        XCTAssertTrue(app.buttons["Current"].exists)
        XCTAssertTrue(app.buttons["Daily"].exists)
        let activeRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'transit-active-'")
        )
        XCTAssertGreaterThan(activeRows.count, 0)
        XCTAssertLessThanOrEqual(activeRows.count, 5)
        attachScreenshot(named: "modern-transit-active-filtered")

        activeRows.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Technical basis"].waitForExistence(timeout: 5))
        attachScreenshot(named: "modern-transit-active-drawer")
    }

    @MainActor
    func testSynastryPrototypeCardsAndDrawer() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_PREMIUM"] = "1"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()

        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        scrollToTop(app)
        let synastry = app.buttons["Synastry"]
        XCTAssertTrue(synastry.waitForExistence(timeout: 10))
        synastry.tap()

        let overview = app.staticTexts["Relationship overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["Elena Hart and Julian Mercer"].exists)
        attachScreenshot(named: "synastry-relationship-overview")

        scrollToHittable(app.buttons["Elena Hart feels"], in: app)
        XCTAssertTrue(app.staticTexts["How you experience each other"].exists)
        XCTAssertTrue(app.buttons["Elena Hart feels"].exists)
        XCTAssertTrue(app.buttons["Julian Mercer feels"].exists)
        app.buttons["Julian Mercer feels"].tap()
        attachScreenshot(named: "synastry-perspectives")

        scrollToHittable(app.staticTexts["Emotional connection"], in: app)
        attachScreenshot(named: "synastry-emotional-connection")
        let emotionalCard = app.descendants(matching: .any)["insight-card-emotional-connection"]
        scrollToHittable(emotionalCard, in: app)
        emotionalCard.tap()
        XCTAssertTrue(app.staticTexts["Moon contacts show emotional recognition, regulation and pacing."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        attachScreenshot(named: "synastry-emotional-drawer")
        app.buttons["Done"].tap()

        for title in [
            "Communication", "Attraction & chemistry", "Commitment & longevity",
            "House overlays", "Key inter-aspects",
        ] {
            scrollToHittable(app.staticTexts[title], in: app)
            attachScreenshot(named: "synastry-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    @MainActor
    func testChineseCardsRender() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "zh-Hans"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_SYNASTRY_SAMPLE"] = "1"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_PREMIUM"] = "1"
        app.launch()

        // Language sanity: the app must be showing Chinese UI.
        let zhToday = app.staticTexts["今日"]
        XCTAssertTrue(zhToday.waitForExistence(timeout: 10), "Chinese UI not applied; app still shows English")
        let chartsTab = app.tabBars.buttons["星盘"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 10))
        chartsTab.tap()
        XCTAssertTrue(app.staticTexts["星盘"].waitForExistence(timeout: 8), "星盘页面未显示")

        let allow = app.buttons["允许"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }

        func select(_ label: String, replacing previousCard: String? = nil) {
            scrollToTop(app)
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing chart selector button: \(label)")
            button.tap()
            if let previousCard {
                XCTAssertTrue(
                    app.staticTexts[previousCard].waitForNonExistence(timeout: 40),
                    "Previous chart did not finish switching from \(previousCard)"
                )
            }
        }

        func find(_ label: String) {
            scrollToTop(app)
            let element = app.staticTexts[label]
            var found = element.waitForExistence(timeout: 6)
            var swipes = 0
            while !found, swipes < 26 {
                app.swipeUp()
                swipes += 1
                usleep(250_000)
                found = element.exists
            }
            XCTAssertTrue(found, "Expected card \(label) to be visible")
        }

        select("本命", replacing: "当前主线")
        assertNoCardError(app)
        find("本命解读")
        find("核心性格")

        select("天象", replacing: "本命解读")
        assertNoCardError(app)
        find("当前天空总览")
        find("当前天空")

        select("行运", replacing: "当前天空总览")
        assertNoCardError(app)
        find("当前主线")
        find("最强周期如何共同作用")
        find("生活领域")
        XCTAssertTrue(app.staticTexts["活跃度，不是运气"].exists)
        XCTAssertTrue(app.staticTexts["个人重心"].exists)
        XCTAssertFalse(app.staticTexts["身份与自主方向"].exists)
        XCTAssertFalse(app.staticTexts["自我表达与第一印象"].exists)
        attachScreenshot(named: "modern-transit-life-areas-zh-Hans")

        select("次限", replacing: "当前主线")
        assertNoCardError(app)
        find("发展阶段")
        find("当前发展")

        select("日返盘", replacing: "发展阶段")
        assertNoCardError(app)
        find("你的生日年")
        find("年度主题")

        select("合盘", replacing: "你的生日年")
        assertNoCardError(app)
        find("关系总览")
        XCTAssertTrue(
            app.descendants(matching: .any)["insight-card-relationship-overview"].exists,
            "合盘必须渲染稳定的关系总览卡片"
        )
    }

    @MainActor
    func testAskHistoryAndKeyboardDone() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        let askTab = app.tabBars.buttons["Ask"]
        XCTAssertTrue(askTab.waitForExistence(timeout: 20))
        askTab.tap()
        let history = app.buttons["History"]
        scrollTo(history, in: app)
        XCTAssertTrue(history.waitForExistence(timeout: 8))

        let willItHappen = app.buttons["ask-mode-yesNo"]
        XCTAssertTrue(willItHappen.waitForExistence(timeout: 5))
        willItHappen.tap()
        XCTAssertFalse(app.staticTexts["Assign each element to a life area"].exists)
        let question = app.textFields["For example: Will this application move forward?"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        question.tap()
        question.typeText("Will the application move forward?")
        let keyboardDone = app.keyboards.buttons["Done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5), "The keyboard return key should be Done")
        keyboardDone.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        app.buttons["ask-life-area-picker"].tap()
        let identity = app.buttons["ask-life-area-toggle-1"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.tap()
        app.buttons["Done"].tap()

        let askChart = app.buttons["Ask the chart"]
        scrollTo(askChart, in: app)
        XCTAssertTrue(askChart.isEnabled)
        askChart.tap()
        XCTAssertTrue(app.staticTexts["Your answer"].waitForExistence(timeout: 30))

        let askBack = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(askBack.waitForExistence(timeout: 5))
        askBack.tap()
        scrollTo(history, in: app)
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        let savedEntry = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ask-history-entry-")
        ).firstMatch
        XCTAssertTrue(savedEntry.waitForExistence(timeout: 5))
        savedEntry.tap()
        XCTAssertTrue(
            app.staticTexts["Your answer"].waitForExistence(timeout: 2),
            "Opening a saved Ask result should transition directly to its detail without flashing back"
        )
    }

    @MainActor
    func testChartsCompactHeaderAndParametersSheet() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
        app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        app.launch()

        let chartsTab = app.tabBars.buttons["Charts"]
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 20))
        chartsTab.tap()
        XCTAssertTrue(app.buttons["Parameters"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Wheel"].exists)
        let wheel = app.otherElements["Astrology wheel"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 8), "The wheel should be present below the compact controls")
        XCTAssertLessThan(wheel.frame.minY, app.frame.maxY - 83, "Expanded parameters must not push the wheel out of the initial viewport")
        XCTAssertFalse(app.staticTexts["Current sky compared with the natal chart"].exists)

        let reports = app.buttons["charts-reports-button"]
        XCTAssertTrue(reports.waitForExistence(timeout: 5))
        reports.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["report-chart-natal"].waitForExistence(timeout: 8),
            "Reports should open the main 12-chart report library"
        )
        for chartID in [
            "report-chart-tertiary", "report-chart-lunar-return", "report-chart-solar-arc",
            "report-chart-relocation", "report-chart-twelfth-harmonic", "report-chart-thirteenth-harmonic",
        ] {
            let card = app.descendants(matching: .any)[chartID]
            scrollTo(card, in: app)
            XCTAssertTrue(card.exists, "Reports is missing \(chartID)")
        }
        let chartsBack = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(chartsBack.waitForExistence(timeout: 5))
        chartsBack.tap()

        app.buttons["Parameters"].tap()
        XCTAssertTrue(app.staticTexts["Modern"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    @MainActor
    func testSpanishAndFrenchCoreLocalization() throws {
        continueAfterFailure = false

        let spanishApp = XCUIApplication()
        spanishApp.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "es"
        spanishApp.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        spanishApp.launch()
        XCTAssertTrue(spanishApp.tabBars.buttons["Hoy"].waitForExistence(timeout: 20))
        XCTAssertTrue(spanishApp.tabBars.buttons["Cartas"].exists)
        XCTAssertTrue(spanishApp.tabBars.buttons["Consultar"].exists)
        XCTAssertTrue(spanishApp.tabBars.buttons["Profil"].exists)
        spanishApp.tabBars.buttons["Cartas"].tap()
        XCTAssertTrue(spanishApp.buttons["charts-parameters-button"].waitForExistence(timeout: 8))
        XCTAssertTrue(spanishApp.otherElements["astrology-wheel"].waitForExistence(timeout: 8))
        spanishApp.terminate()

        let frenchApp = XCUIApplication()
        frenchApp.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "fr"
        frenchApp.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
        frenchApp.launch()
        XCTAssertTrue(frenchApp.tabBars.buttons["Aujourd’hui"].waitForExistence(timeout: 20))
        XCTAssertTrue(frenchApp.tabBars.buttons["Cartes"].exists)
        XCTAssertTrue(frenchApp.tabBars.buttons["Question"].exists)
        XCTAssertTrue(frenchApp.tabBars.buttons["Profil"].exists)
        frenchApp.tabBars.buttons["Cartes"].tap()
        XCTAssertTrue(frenchApp.buttons["charts-parameters-button"].waitForExistence(timeout: 8))
        XCTAssertTrue(frenchApp.otherElements["astrology-wheel"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testProductionRelayGenerationAndLocalReuse() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("Production App Attest requires a physical Apple device")
        #else
            continueAfterFailure = false
            let app = XCUIApplication()
            app.launchEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] = "en"
            app.launchEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"] = "dark"
            app.launch()

            let profileTab = app.tabBars.buttons["Profile"]
            XCTAssertTrue(profileTab.waitForExistence(timeout: 30))
            profileTab.tap()
            let settings = app.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()

            let localData = app.buttons["Local Data"]
            scrollTo(localData, in: app)
            XCTAssertTrue(localData.waitForExistence(timeout: 10))
            localData.tap()
            let consent = app.switches["Allow new AI generation"]
            XCTAssertTrue(consent.waitForExistence(timeout: 10))
            if (consent.value as? String) != "1" {
                consent.tap()
            }

            app.terminate()
            app.launch()
            let chartsTab = app.tabBars.buttons["Charts"]
            XCTAssertTrue(chartsTab.waitForExistence(timeout: 30))
            chartsTab.tap()
            let moreCharts = app.buttons["charts-more-button"]
            XCTAssertTrue(moreCharts.waitForExistence(timeout: 10))
            moreCharts.tap()
            let tertiaryChart = app.buttons["charts-all-tertiary"]
            XCTAssertTrue(tertiaryChart.waitForExistence(timeout: 10))
            tertiaryChart.tap()
            scrollToTop(app)
            let reports = app.buttons["Reports"]
            XCTAssertTrue(reports.waitForExistence(timeout: 10))
            reports.tap()

            let tertiaryCard = app.descendants(matching: .any)["report-chart-tertiary"]
            scrollTo(tertiaryCard, in: app)
            XCTAssertTrue(tertiaryCard.waitForExistence(timeout: 20), "The Tertiary Progressions report panel is missing")
            let generate = tertiaryCard.buttons["Generate Report"]
            let regenerate = tertiaryCard.buttons["Regenerate"]
            let reportAction = generate.exists ? generate : regenerate
            XCTAssertTrue(reportAction.waitForExistence(timeout: 20), "The report must wait for an explicit generation action")
            let enabled = NSPredicate(format: "enabled == true")
            let enabledExpectation = XCTNSPredicateExpectation(predicate: enabled, object: reportAction)
            XCTAssertEqual(
                XCTWaiter.wait(for: [enabledExpectation], timeout: 30),
                .completed,
                "The tertiary report should be ready to generate on the physical device"
            )
            reportAction.tap()
            let confirmGenerate = app.buttons["Generate"]
            XCTAssertTrue(confirmGenerate.waitForExistence(timeout: 10))
            confirmGenerate.tap()
            let allow = app.buttons["Allow"]
            if allow.waitForExistence(timeout: 5) {
                allow.tap()
            }

            let viewReport = tertiaryCard.buttons["View Report"]
            XCTAssertTrue(
                waitForReport(viewReport, in: app, timeout: 240),
                "The explicit physical-device report request did not produce a saved chart artifact"
            )
            viewReport.tap()
            XCTAssertTrue(app.buttons["Regenerate"].waitForExistence(timeout: 20))

            app.terminate()
            app.launch()
            XCTAssertTrue(chartsTab.waitForExistence(timeout: 30))
            chartsTab.tap()
            scrollToTop(app)
            XCTAssertTrue(reports.waitForExistence(timeout: 10))
            reports.tap()
            let restoredTertiaryCard = app.descendants(matching: .any)["report-chart-tertiary"]
            scrollTo(restoredTertiaryCard, in: app)
            let restoredViewReport = restoredTertiaryCard.buttons["View Report"]
            XCTAssertTrue(
                restoredViewReport.waitForExistence(timeout: 20),
                "The second launch did not restore the tertiary report from local storage"
            )
            restoredViewReport.tap()
            XCTAssertTrue(app.buttons["Regenerate"].waitForExistence(timeout: 20))
        #endif
    }

    @MainActor
    private func assertNoCardError(_ app: XCUIApplication) {
        let error = app.staticTexts.matching(
            NSPredicate(
                format: "label BEGINSWITH 'Rule ' OR label CONTAINS 'produced' OR label CONTAINS 'incomplete' OR label CONTAINS[c] 'missingCopy' OR label CONTAINS[c] 'Reviewed copy is missing'"
            )
        ).firstMatch
        if error.exists {
            XCTFail("Card loading error visible: \(error.label)")
        }
    }

    @MainActor
    private func scrollToTop(_ app: XCUIApplication) {
        for _ in 0 ..< 6 {
            app.swipeDown()
        }
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.exists {
            app.swipeUp()
        }
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable, attempts < 30 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to become visible")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForReport(_ reportButton: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let failed = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] 'unavailable' OR label CONTAINS '失败' OR label CONTAINS '不可用'")
        ).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if reportButton.exists { return true }
            if failed.exists {
                XCTFail("Report generation failed: \(failed.label)")
                return false
            }
            usleep(700_000)
        }
        return reportButton.exists
    }

}
