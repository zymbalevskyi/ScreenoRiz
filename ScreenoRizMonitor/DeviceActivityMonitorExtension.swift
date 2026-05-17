//
//  DeviceActivityMonitorExtension.swift
//  ScreenoRizMonitor
//
//  Created by Yevhen on 15.03.2026.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import OSLog

private let logger = Logger(subsystem: "app.zymbalevskyi.ScreenoRiz.monitor", category: "DeviceActivity")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let sharedDefaults = UserDefaults(suiteName: "group.app.zymbalevskyi.ScreenoRiz")!
    private let store = ManagedSettingsStore()

    // MARK: – Threshold events ("m{minutes}" on "screenoriz.app.{generation}.{index}.{suffix}")

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.info("eventDidReachThreshold: \(event.rawValue) for \(activity.rawValue)")

        guard let threshold = thresholdInfo(event: event, activity: activity) else {
            logger.warning("Ignoring threshold with unexpected names: event=\(event.rawValue), activity=\(activity.rawValue)")
            return
        }

        let tokenKey = threshold.tokenKey
        let minutes = threshold.minutes

        // Update usage tracking.
        // Always overwrite — DeviceActivity thresholds are cumulative since midnight
        // and fire in strictly increasing order, so the latest event is always the
        // most accurate. The old "minutes > current" guard prevented recovery from
        // values inflated by stale data (e.g. a bad includesPastActivity run).
        let usageKey = "usage_\(tokenKey)_\(todayKey())"
        sharedDefaults.set(minutes, forKey: usageKey)
        logger.info("wrote \(usageKey) = \(minutes)")
        recomputeDailyDebt()

        guard let limit = SharedDefaults.appLimit(forTokenKey: tokenKey) else { return }

        if minutes == limit {
            // Shield when the per-app limit is first reached
            SharedDefaults.resetIfNewDay()
            if SharedDefaults.dailyDebtUAH <= 0 { SharedDefaults.isFirstShieldToday = true }
            shieldApp(tokenKey: tokenKey)
            return
        }

        // Post-limit: check whether an active grace session has expired.
        // Primary re-shield path for short sessions (1, 5 min) where DeviceActivity's
        // minimum interval prevents intervalDidEnd from ever firing.
        guard minutes > limit else { return }
        let suffix = SharedDefaults.overageSuffix(forTokenKey: tokenKey)
        guard SharedDefaults.sessionTokenKey(forSuffix: suffix) == tokenKey,
              let sessionStart = SharedDefaults.sessionStart(forSuffix: suffix) else { return }
        let chosenMinutes = Double(SharedDefaults.sessionMinutes(forSuffix: suffix))
        let elapsed = Date().timeIntervalSince(sessionStart) / 60.0
        guard elapsed >= chosenMinutes else { return }

        logger.info("Grace session expired — re-shielding \(tokenKey.prefix(8)).")
        SharedDefaults.clearSession(forSuffix: suffix)
        var active = SharedDefaults.activeSessionSuffixes
        active.remove(suffix)
        SharedDefaults.activeSessionSuffixes = active
        shieldApp(tokenKey: tokenKey)
    }

    // MARK: – Schedule lifecycle

    /// A daily or per-app schedule started — reset state if it's a new day.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .daily || activity.rawValue.hasPrefix("screenoriz.app.") else { return }
        let didReset = SharedDefaults.resetIfNewDay()
        if didReset { store.shield.applications = nil }
        logger.info("Interval started for \(activity.rawValue), didReset=\(didReset)")
    }

    /// Called when a per-app overage window expires.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Fix 1: activity names are now per-app ("screenoriz.overage.<suffix>")
        guard activity.rawValue.hasPrefix("screenoriz.overage.") else { return }

        let suffix = String(activity.rawValue.dropFirst("screenoriz.overage.".count))
        logger.info("Overage window ended for suffix \(suffix) — re-shielding.")

        SharedDefaults.resetIfNewDay()

        // Capture and clear per-app session state atomically
        let sessionTokenKey = SharedDefaults.sessionTokenKey(forSuffix: suffix)
        SharedDefaults.clearSession(forSuffix: suffix)
        var active = SharedDefaults.activeSessionSuffixes
        active.remove(suffix)
        SharedDefaults.activeSessionSuffixes = active

        // Recompute debt from threshold data — keeps dailyDebtUAH in sync with HomeView
        recomputeDailyDebt()

        // Re-shield the correct app
        if let tokenKey = sessionTokenKey {
            shieldApp(tokenKey: tokenKey)
        }
    }

    // MARK: – Helpers

    private func thresholdInfo(
        event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) -> (tokenKey: String, minutes: Int)? {
        let appPrefix = "screenoriz.app."
        guard activity.rawValue.hasPrefix(appPrefix),
              event.rawValue.hasPrefix("m"),
              let minutes = Int(event.rawValue.dropFirst()) else {
            return nil
        }

        guard let mapData = sharedDefaults.data(forKey: "activityTokenMap"),
              let activityTokenMap = try? JSONDecoder().decode([String: String].self, from: mapData),
              let tokenKey = activityTokenMap[activity.rawValue] else {
            logger.warning("Ignoring stale or unknown activity callback: \(activity.rawValue)")
            return nil
        }

        return (tokenKey, minutes)
    }

    /// Recomputes dailyDebtUAH as sum(max(0, usage − limit)) × rate across all tracked apps.
    /// Uses the same integer-minute threshold data that HomeView displays, so every view
    /// in the app shows a consistent donation figure.
    private func recomputeDailyDebt() {
        guard let limitsData = sharedDefaults.data(forKey: "sharedAppLimits"),
              let limitsMap = try? JSONDecoder().decode([String: Int].self, from: limitsData)
        else {
            logger.warning("recomputeDailyDebt: missing sharedAppLimits")
            return
        }

        let today = todayKey()
        var totalExcess = 0
        for (tokenKey, limit) in limitsMap {
            let usage = sharedDefaults.integer(forKey: "usage_\(tokenKey)_\(today)")
            totalExcess += max(0, usage - limit)
        }

        let rate = SharedDefaults.ratePerMinute
        SharedDefaults.dailyDebtUAH = Double(totalExcess) * rate
        logger.info("recomputeDailyDebt: \(totalExcess) excess min × \(rate)₴ = \(SharedDefaults.dailyDebtUAH)₴")
    }

    private func shieldApp(tokenKey: String) {
        guard let data = Data(base64Encoded: tokenKey),
              let token = try? JSONDecoder().decode(ApplicationToken.self, from: data)
        else {
            logger.error("Could not decode ApplicationToken for key \(tokenKey)")
            return
        }

        var shielded = store.shield.applications ?? []
        shielded.insert(token)
        store.shield.applications = shielded
        logger.info("Shielded app for tokenKey \(tokenKey.prefix(8))…")
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        return formatter.string(from: Date())
    }
}

private extension DeviceActivityName {
    static let daily = Self("screenoriz.daily")
}
