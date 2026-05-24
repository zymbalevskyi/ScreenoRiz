import ManagedSettings
import DeviceActivity
import FamilyControls
import Foundation

class ShieldActionExtension: ShieldActionDelegate {

    private let store = ManagedSettingsStore()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        if SharedDefaults.resetIfNewDay() {
            store.shield.applications = nil
        }

        switch action {

        case .primaryButtonPressed:
            completionHandler(.close)

        case .secondaryButtonPressed:
            // fallback for iOS < 26.4 — fixed 5-minute grace
            startSession(minutes: 5, for: application)
            completionHandler(.defer)

        case .firstSecondarySubmenuItemPressed:  // "1 хвилина"
            if #available(iOS 26.4, *) {
                startSession(minutes: 1, for: application)
                completionHandler(.defer)
            } else {
                completionHandler(.close)
            }

        case .secondSecondarySubmenuItemPressed:  // "5 хвилин"
            if #available(iOS 26.4, *) {
                startSession(minutes: 5, for: application)
                completionHandler(.defer)
            } else {
                completionHandler(.close)
            }

        case .thirdSecondarySubmenuItemPressed:  // "30 хвилин"
            if #available(iOS 26.4, *) {
                startSession(minutes: 30, for: application)
                completionHandler(.defer)
            } else {
                completionHandler(.close)
            }

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: – Private

    private func startSession(minutes: Int, for application: ApplicationToken) {
        guard let data = try? JSONEncoder().encode(application) else { return }
        let tokenKey = data.base64EncodedString()
        let suffix = SharedDefaults.overageSuffix(forTokenKey: tokenKey)

        // Attempt to schedule the per-app overage window. Use try? so that an
        // intervalTooShort error (system minimum ~15 min) doesn't block the grace
        // for short sessions — the next threshold event will re-shield the app anyway.
        scheduleOverageWindow(minutes: minutes, suffix: suffix)

        SharedDefaults.isFirstShieldToday = false
        SharedDefaults.setSessionStart(Date(), forSuffix: suffix)
        SharedDefaults.setSessionMinutes(minutes, forSuffix: suffix)
        SharedDefaults.setSessionTokenKey(tokenKey, forSuffix: suffix)

        var active = SharedDefaults.activeSessionSuffixes
        active.insert(suffix)
        SharedDefaults.activeSessionSuffixes = active
        SharedDefaults.synchronize()

        var shielded = store.shield.applications ?? []
        shielded.remove(application)
        store.shield.applications = shielded.isEmpty ? nil : shielded
    }

    // Fix 1: per-app activity name so a second grace session for app B does not
    // cancel the re-shielding timer that was set for app A.
    private func scheduleOverageWindow(minutes: Int, suffix: String) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName("screenoriz.overage.\(suffix)")
        center.stopMonitoring([activityName])   // stop only this app's previous overage

        let now = Date()
        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .minute, value: minutes, to: now) else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd:   calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )

        try? center.startMonitoring(activityName, during: schedule)
    }
}
