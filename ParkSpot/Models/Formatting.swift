import Foundation

enum Formatting {
    /// Metric only: whole metres under 1000 ("84 m"), otherwise km with one decimal in `locale` ("1.2 km").
    /// A value that rounds to 1000 m or more counts as km.
    static func distance(_ metres: Double, locale: Locale) -> String {
        let whole = metres.rounded()
        guard whole >= 1000 else { return metresString(whole, locale: locale) }
        let km = (metres / 1000).formatted(.number.precision(.fractionLength(1)).locale(locale))
        return "\(km) km"
    }

    /// Distance rounded to the nearest 10 m, never below 10 m; km rule as in `distance`.
    static func roughDistance(_ metres: Double, locale: Locale) -> String {
        distance(max(10, (metres / 10).rounded() * 10), locale: locale)
    }

    /// GPS accuracy in whole metres ("12 m").
    static func accuracy(_ metres: Double, locale: Locale) -> String {
        metresString(metres.rounded(), locale: locale)
    }

    /// Walking time at 1.4 m/s, at least one minute.
    static func walkMinutes(_ metres: Double) -> Int {
        max(1, Int((metres / 1.4 / 60).rounded()))
    }

    private static func metresString(_ whole: Double, locale: Locale) -> String {
        "\(whole.formatted(.number.precision(.fractionLength(0)).locale(locale))) m"
    }
}
