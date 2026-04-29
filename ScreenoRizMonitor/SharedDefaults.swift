import Foundation

enum SharedDefaults {
    static let suiteName = "group.app.zymbalevskyi.ScreenoRiz"
    static var store: UserDefaults { UserDefaults(suiteName: suiteName)! }

    // MARK: – Keys
    static let keyDailyDebtUAH           = "dailyDebtUAH"
    static let keyShieldRatePerMinute     = "shieldRatePerMinute"
    static let keyCurrentSessionStart     = "currentSessionStart"
    static let keyCurrentSessionTokenKey  = "currentSessionTokenKey"
    static let keyTodayDate               = "shieldTodayDate"
    static let keyIsFirstShieldToday      = "isFirstShieldToday"
    static let keySharedAppLimits         = "sharedAppLimits"
    static let keyChosenSessionMinutes    = "chosenSessionMinutes"

    // MARK: – Accessors
    static var dailyDebtUAH: Double {
        get { store.double(forKey: keyDailyDebtUAH) }
        set { store.set(newValue, forKey: keyDailyDebtUAH) }
    }

    static var ratePerMinute: Double {
        get {
            let v = store.double(forKey: keyShieldRatePerMinute)
            return v == 0 ? 1.0 : v
        }
        set { store.set(newValue, forKey: keyShieldRatePerMinute) }
    }

    static var isFirstShieldToday: Bool {
        get { store.object(forKey: keyIsFirstShieldToday) as? Bool ?? true }
        set { store.set(newValue, forKey: keyIsFirstShieldToday) }
    }

    static var chosenSessionMinutes: Int {
        get {
            let v = store.integer(forKey: keyChosenSessionMinutes)
            return v == 0 ? 5 : v
        }
        set { store.set(newValue, forKey: keyChosenSessionMinutes) }
    }

    static var currentSessionStart: Date? {
        get {
            let t = store.double(forKey: keyCurrentSessionStart)
            return t == 0 ? nil : Date(timeIntervalSince1970: t)
        }
        set {
            if let d = newValue {
                store.set(d.timeIntervalSince1970, forKey: keyCurrentSessionStart)
            } else {
                store.removeObject(forKey: keyCurrentSessionStart)
            }
        }
    }

    static var currentSessionTokenKey: String? {
        get { store.string(forKey: keyCurrentSessionTokenKey) }
        set { store.set(newValue, forKey: keyCurrentSessionTokenKey) }
    }

    static func appLimit(forTokenKey key: String) -> Int? {
        guard let data = store.data(forKey: keySharedAppLimits),
              let limits = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return nil }
        return limits[key]
    }

    // MARK: – Per-app session storage (Fix 1: concurrent grace sessions)

    /// Derives a stable 12-character alphanumeric suffix from a tokenKey for use as
    /// a per-app storage key and DeviceActivityName suffix.
    static func overageSuffix(forTokenKey key: String) -> String {
        String(key.filter { $0.isLetter || $0.isNumber }.prefix(12))
    }

    static var activeSessionSuffixes: Set<String> {
        get {
            let str = store.string(forKey: "activeSessionSuffixes") ?? ""
            return str.isEmpty ? [] : Set(str.split(separator: ",").map(String.init))
        }
        set { store.set(newValue.joined(separator: ","), forKey: "activeSessionSuffixes") }
    }

    static func sessionTokenKey(forSuffix suffix: String) -> String? {
        store.string(forKey: "sessionTokenKey_\(suffix)")
    }

    static func setSessionTokenKey(_ key: String, forSuffix suffix: String) {
        store.set(key, forKey: "sessionTokenKey_\(suffix)")
    }

    static func sessionStart(forSuffix suffix: String) -> Date? {
        let t = store.double(forKey: "sessionStart_\(suffix)")
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }

    static func setSessionStart(_ date: Date, forSuffix suffix: String) {
        store.set(date.timeIntervalSince1970, forKey: "sessionStart_\(suffix)")
    }

    static func sessionMinutes(forSuffix suffix: String) -> Int {
        let v = store.integer(forKey: "sessionMinutes_\(suffix)")
        return v == 0 ? 5 : v
    }

    static func setSessionMinutes(_ minutes: Int, forSuffix suffix: String) {
        store.set(minutes, forKey: "sessionMinutes_\(suffix)")
    }

    static func clearSession(forSuffix suffix: String) {
        store.removeObject(forKey: "sessionTokenKey_\(suffix)")
        store.removeObject(forKey: "sessionStart_\(suffix)")
        store.removeObject(forKey: "sessionMinutes_\(suffix)")
    }

    // MARK: – Daily reset
    @discardableResult
    static func resetIfNewDay() -> Bool {
        let today = todayString()
        guard store.string(forKey: keyTodayDate) != today else { return false }
        store.set(0.0,   forKey: keyDailyDebtUAH)
        store.set(true,  forKey: keyIsFirstShieldToday)
        store.set(5,     forKey: keyChosenSessionMinutes)
        store.removeObject(forKey: keyCurrentSessionStart)
        store.removeObject(forKey: keyCurrentSessionTokenKey)
        // Clear all per-app overage sessions from the previous day
        for suffix in activeSessionSuffixes { clearSession(forSuffix: suffix) }
        store.removeObject(forKey: "activeSessionSuffixes")
        store.set(today, forKey: keyTodayDate)
        return true
    }

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
