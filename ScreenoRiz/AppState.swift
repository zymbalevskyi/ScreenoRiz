//
//  AppState.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import UIKit
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

extension DeviceActivityName {
    static let daily = Self("screenoriz.daily")
}

class AppState: ObservableObject {

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var activitySelection: FamilyActivitySelection {
        didSet {
            if let data = try? JSONEncoder().encode(activitySelection) {
                sharedDefaults.set(data, forKey: "activitySelection")
            }
            scheduleMonitoring()
        }
    }

    @Published var appLimits: [String: Int] {
        didSet {
            if let data = try? JSONEncoder().encode(appLimits) {
                UserDefaults.standard.set(data, forKey: "appLimits")
            }
            scheduleMonitoring()
        }
    }

    var dailyLimitMinutes: Int {
        let sum = appLimits.values.reduce(0, +)
        return max(sum, 1)
    }

    @Published var ratePerMinute: Double {
        didSet {
            UserDefaults.standard.set(ratePerMinute, forKey: "ratePerMinute")
            sharedDefaults.set(ratePerMinute, forKey: "shieldRatePerMinute")
        }
    }

    let sharedDefaults = UserDefaults(suiteName: "group.app.zymbalevskyi.ScreenoRiz")!
    private var monitoringWorkItem: DispatchWorkItem?
    // Fires every 30 s so the home screen reflects fresh usage data written by the
    // monitor extension (a separate process that doesn't trigger @Published changes).
    private var usageRefreshTimer: AnyCancellable?

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.ratePerMinute = UserDefaults.standard.object(forKey: "ratePerMinute") as? Double ?? 1.0

        if let data = UserDefaults.standard.data(forKey: "appLimits"),
           let limits = try? JSONDecoder().decode([String: Int].self, from: data) {
            self.appLimits = limits
        } else {
            self.appLimits = [:]
        }

        let defaults = UserDefaults(suiteName: "group.app.zymbalevskyi.ScreenoRiz")!
        if let data = defaults.data(forKey: "activitySelection"),
           let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.activitySelection = sel
        } else {
            self.activitySelection = FamilyActivitySelection()
        }

        // Re-register monitoring on every app launch so it doesn't silently stop.
        // didSet observers don't fire during init, so we must call this explicitly.
        scheduleMonitoring()

        usageRefreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Display name resolution

    /// Rendered app name cache (tokenKey → name, with "X" already replaced by "X (Twitter)")
    @Published var tokenDisplayNames: [String: String] = [:]

    /// Renders each selected app's label off-screen via UIKit to extract the display name string.
    /// Must be called on the main thread.
    @MainActor
    func resolveDisplayNames() {
        for token in activitySelection.applicationTokens {
            let key = tokenKey(token)
            guard tokenDisplayNames[key] == nil else { continue }

            let vc = UIHostingController(rootView: Label(token).labelStyle(.titleOnly))
            vc.view.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
            vc.view.layoutIfNeeded()

            if let name = extractText(from: vc.view), !name.isEmpty {
                tokenDisplayNames[key] = (name == "X") ? "X (Twitter)" : name
            }
        }
    }

    private func extractText(from view: UIView) -> String? {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            return text
        }
        for sub in view.subviews {
            if let text = extractText(from: sub) { return text }
        }
        return view.accessibilityLabel.flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Per-app limit helpers

    func tokenKey(_ token: ApplicationToken) -> String {
        guard let data = try? JSONEncoder().encode(token) else { return "" }
        return data.base64EncodedString()
    }

    func getLimit(for token: ApplicationToken) -> Int {
        appLimits[tokenKey(token)] ?? 15
    }

    func setLimit(_ minutes: Int, for token: ApplicationToken) {
        appLimits[tokenKey(token)] = max(1, minutes)
    }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func dateKey(for date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - Usage data (read from App Group written by extension)

    func getTotalMinutes(on date: Date) -> Int {
        activitySelection.applicationTokens
            .map { getMinutes(forTokenKey: tokenKey($0), on: date) }
            .reduce(0, +)
    }

    func getMinutes(forTokenKey key: String, on date: Date) -> Int {
        var minutes = sharedDefaults.integer(forKey: "usage_\(key)_\(dateKey(for: date))")

        // If there's an active overage session for this exact app today, add elapsed
        // time on the fly — the monitor extension only writes at threshold intervals,
        // so without this the card lags until intervalDidEnd fires.
        if Calendar.current.isDateInToday(date) {
            let suffix = String(key.filter { $0.isLetter || $0.isNumber }.prefix(12))
            let timestamp = sharedDefaults.double(forKey: "sessionStart_\(suffix)")
            let sessionKey = sharedDefaults.string(forKey: "sessionTokenKey_\(suffix)")
            if timestamp > 0, sessionKey == key {
                let cap = sharedDefaults.integer(forKey: "sessionMinutes_\(suffix)")
                let capMinutes = Double(cap > 0 ? cap : 5)
                let elapsed = min(capMinutes, Date().timeIntervalSince(Date(timeIntervalSince1970: timestamp)) / 60)
                minutes += Int(elapsed)
            }
        }

        return minutes
    }

    func getOpens(forTokenKey key: String, on date: Date) -> Int {
        sharedDefaults.integer(forKey: "opens_\(key)_\(dateKey(for: date))")
    }

    func getTotalDonation(for date: Date) -> Double {
        let totalExcess = activitySelection.applicationTokens.reduce(0) { sum, token in
            let key = tokenKey(token)
            let used = getMinutes(forTokenKey: key, on: date)
            let limit = appLimits[key] ?? 15
            return sum + max(0, used - limit)
        }
        return Double(totalExcess) * ratePerMinute
    }

    func getWeeklyDebt(for date: Date) -> Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
                      .reduce(0) { $0 + getTotalDonation(for: $1) }
    }

    func getDailyDebtForWeek(for date: Date) -> [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
                      .map { (date: $0, amount: getTotalDonation(for: $0)) }
    }

    // MARK: - Monitoring

    /// Debounced entry point — coalesces rapid consecutive calls (e.g. from didSet observers).
    func scheduleMonitoring() {
        monitoringWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.startMonitoring() }
        monitoringWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func startMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        guard !activitySelection.applicationTokens.isEmpty else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        // Build per-app events sorted by tokenKey so the monitor extension can map
        // "a{index}_m{minute}" back to the right token.
        let sortedTokens = activitySelection.applicationTokens
            .map { (key: tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }

        // Persist index → tokenKey map for the monitor extension
        let indexMap = Dictionary(uniqueKeysWithValues:
            sortedTokens.enumerated().map { (String($0.offset), $0.element.key) })
        if let data = try? JSONEncoder().encode(indexMap) {
            sharedDefaults.set(data, forKey: "tokenIndexMap")
        }

        // Persist per-app limits and rate for shield extensions
        let limitsMap = Dictionary(uniqueKeysWithValues:
            sortedTokens.map { ($0.key, appLimits[$0.key] ?? 15) })
        if let data = try? JSONEncoder().encode(limitsMap) {
            sharedDefaults.set(data, forKey: "sharedAppLimits")
        }
        sharedDefaults.set(ratePerMinute, forKey: "shieldRatePerMinute")

        // Register events at 5-minute intervals up to the per-app limit.
        // Always include the exact limit so the shield fires precisely on time.
        // This keeps the event count small (≤ limit/5 + 1 per app) instead of
        // one event per minute, which was causing heavy system overhead.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for (index, item) in sortedTokens.enumerated() {
            let limit = appLimits[item.key] ?? 15
            // 1-minute granularity for the first 4 minutes so brief usage
            // (< 5 min) isn't invisible; coarse 5-min intervals after that.
            let fineCheckpoints = stride(from: 1, through: min(4, limit), by: 1).map { $0 }
            let coarseCheckpoints = stride(from: 5, through: limit, by: 5).map { $0 }
            var checkpoints = Array(Set(fineCheckpoints + coarseCheckpoints)).sorted()
            if !checkpoints.contains(limit) { checkpoints.append(limit) }

            for minute in checkpoints {
                events[DeviceActivityEvent.Name("a\(index)_m\(minute)")] = DeviceActivityEvent(
                    applications: [item.token],
                    threshold: DateComponents(minute: minute)
                )
            }

            // Post-limit: 1-minute granularity for 2 hours so we know exactly
            // how many minutes were used during an overage session.
            // intervalDidEnd no longer writes usage — it relies on these events.
            for minute in stride(from: limit + 1, through: limit + 120, by: 1) {
                events[DeviceActivityEvent.Name("a\(index)_m\(minute)")] = DeviceActivityEvent(
                    applications: [item.token],
                    threshold: DateComponents(minute: minute)
                )
            }
        }

        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
        } catch {
            print("DeviceActivity monitoring error: \(error)")
        }
    }
}
