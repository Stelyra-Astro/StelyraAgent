import Foundation

enum LocalizedFormatters {
    static func shortDate(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "MMMd", language: language, timeZone: timeZone)
    }

    static func shortDateWithYear(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "yMMMd", language: language, timeZone: timeZone)
    }

    static func monthYear(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "yMMM", language: language, timeZone: timeZone)
    }

    static func time(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "jm", language: language, timeZone: timeZone)
    }

    static func formattedDate(
        _ date: Date,
        template: String,
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func savedQuestions(_ count: Int, language: AppLanguage) -> String {
        localizedCountTemplate("format.saved-questions.one", "format.saved-questions.other", count: count, language: language)
    }

    static func nextDays(_ count: Int, language: AppLanguage) -> String {
        localizedCountTemplate("format.next-days.one", "format.next-days.other", count: count, language: language)
    }

    static func nextMonths(_ count: Int, language: AppLanguage) -> String {
        localizedCountTemplate("format.next-months.one", "format.next-months.other", count: count, language: language)
    }

    static func hoursDuration(_ count: Int, language: AppLanguage) -> String {
        localizedValueTemplate("format.hours-duration", value: count, language: language)
    }

    static func viewAllAreas(_ count: Int, language: AppLanguage) -> String {
        localizedValueTemplate("format.view-all-areas", value: count, language: language)
    }

    static func day(_ number: Int, language: AppLanguage) -> String {
        localizedValueTemplate("format.day", value: number, language: language)
    }

    static func calendarDay(_ number: Int, language: AppLanguage) -> String {
        localizedValueTemplate("format.calendar-day", value: number, language: language)
    }

    static func exactAgain(_ date: String, language: AppLanguage) -> String {
        localizedTemplate("format.exact-again", substitutions: ["value": date], language: language)
    }

    static func exact(_ date: String, language: AppLanguage) -> String {
        localizedTemplate("dynamic.ccf2313c4f", substitutions: ["value1": date], language: language)
    }

    static func quarter(_ number: Int, language: AppLanguage) -> String {
        localizedValueTemplate("format.quarter", value: number, language: language)
    }

    static func retrogradePlanets(_ count: Int, language: AppLanguage) -> String {
        localizedCountTemplate("format.retrograde-planets.one", "format.retrograde-planets.other", count: count, language: language)
    }

    static func weekdayLabelsStartingMonday(language: AppLanguage) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        let sundayFirst = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard sundayFirst.count == 7 else { return [] }
        return Array(sundayFirst.dropFirst()) + [sundayFirst[0]]
    }

    private static func localizedValueTemplate(_ key: String, value: Int, language: AppLanguage) -> String {
        localizedTemplate(key, substitutions: ["value": String(value)], language: language)
    }

    private static func localizedCountTemplate(_ oneKey: String, _ otherKey: String, count: Int, language: AppLanguage) -> String {
        localizedTemplate(
            count == 1 ? oneKey : otherKey,
            substitutions: ["value": String(count)],
            language: language
        )
    }
}
