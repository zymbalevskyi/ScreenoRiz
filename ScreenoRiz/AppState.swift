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
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
            if hasCompletedOnboarding {
                if UserDefaults.standard.object(forKey: "firstUsedDate") == nil {
                    UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: "firstUsedDate")
                }
                scheduleMonitoring()
            } else {
                monitoringWorkItem?.cancel()
            }
        }
    }

    var firstUsedDate: Date {
        UserDefaults.standard.object(forKey: "firstUsedDate") as? Date
            ?? Calendar.current.startOfDay(for: Date())
    }

    @Published var activitySelection: FamilyActivitySelection {
        didSet {
            if let data = try? JSONEncoder().encode(activitySelection) {
                sharedDefaults.set(data, forKey: "activitySelection")
            }
            if hasCompletedOnboarding { scheduleMonitoring() }
        }
    }

    @Published var appLimits: [String: Int] {
        didSet {
            if let data = try? JSONEncoder().encode(appLimits) {
                UserDefaults.standard.set(data, forKey: "appLimits")
            }
            if hasCompletedOnboarding { scheduleMonitoring() }
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
    // Poll shared defaults because the monitor extension updates data out-of-process.
    private var usageRefreshTimer: AnyCancellable?
    private static let usageDataVersion = "v4"

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
           UserDefaults.standard.object(forKey: "firstUsedDate") == nil {
            UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: "firstUsedDate")
        }
        self.ratePerMinute = UserDefaults.standard.object(forKey: "ratePerMinute") as? Double ?? 1.0

        if let data = UserDefaults.standard.data(forKey: "appLimits"),
           let limits = try? JSONDecoder().decode([String: Int].self, from: data) {
            let steppedLimits = limits.mapValues(Self.steppedLimitMinutes)
            self.appLimits = steppedLimits
            if steppedLimits != limits,
               let data = try? JSONEncoder().encode(steppedLimits) {
                UserDefaults.standard.set(data, forKey: "appLimits")
            }
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

        migrateSharedUsageIfNeeded()
        resetSharedStateIfNewDay()

        // Re-register monitoring on every post-onboarding app launch so it doesn't silently stop.
        // didSet observers don't fire during init, so we must call this explicitly.
        if hasCompletedOnboarding { scheduleMonitoring() }

        usageRefreshTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Display name resolution

    /// Rendered app name cache (tokenKey → name, with "X" already replaced by "X (Twitter)")
    @Published var tokenDisplayNames: [String: String] = [:]

    /// Renders each selected app's label in the live key window (off-screen) to extract the display name.
    /// FamilyControls requires a real window hierarchy to resolve token names.
    @MainActor
    func resolveDisplayNames() {
        let newTokens = activitySelection.applicationTokens.filter {
            tokenDisplayNames[tokenKey($0)] == nil
        }
        guard !newTokens.isEmpty else { return }

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.resolveDisplayNames()
            }
            return
        }

        // retainedVCs keeps UIHostingControllers alive until extraction completes.
        // Without this, the VC is deallocated immediately after the loop because only
        // vc.view is stored — UIView holds only a weak back-reference to its VC.
        var retainedVCs: [UIViewController] = []
        var pending: [(view: UIView, key: String)] = []

        for token in newTokens {
            let key = tokenKey(token)
            let vc = UIHostingController(rootView: Label(token).labelStyle(.titleOnly))
            vc.view.frame = CGRect(x: -3000, y: 0, width: 300, height: 60)
            vc.view.backgroundColor = .clear
            window.addSubview(vc.view)
            retainedVCs.append(vc)
            pending.append((view: vc.view, key: key))
        }

        // 300 ms gives FamilyControls enough time to resolve token → display name.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            for pair in pending {
                pair.view.layoutIfNeeded()
                if let self, let name = self.extractText(from: pair.view), !name.isEmpty {
                    self.tokenDisplayNames[pair.key] = (name == "X") ? "X (Twitter)" : name
                }
                pair.view.removeFromSuperview()
            }
            _ = retainedVCs  // Release VCs only after all views are cleaned up
        }
    }

    private func extractText(from view: UIView) -> String? {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            return text
        }
        for sub in view.subviews {
            if let text = extractText(from: sub) { return text }
        }
        // SwiftUI Text may expose its content via accessibility elements rather than UILabel.
        if let elements = view.accessibilityElements {
            for el in elements {
                if let acc = (el as? NSObject)?.accessibilityLabel, !acc.isEmpty {
                    return acc
                }
            }
        }
        if let acc = view.accessibilityLabel, !acc.isEmpty { return acc }
        return nil
    }

    // MARK: - Per-app limit helpers

    func tokenKey(_ token: ApplicationToken) -> String {
        guard let data = try? JSONEncoder().encode(token) else { return "" }
        return data.base64EncodedString()
    }

    nonisolated static let minimumLimitMinutes = 1
    nonisolated static let maximumLimitMinutes = 23 * 60 + 55
    nonisolated static let limitMinuteStep = 5

    nonisolated static func limitMinutePickerValues(forHours hours: Int) -> [Int] {
        let steppedMinutes = Array(stride(from: limitMinuteStep, through: 55, by: limitMinuteStep))
        return hours == 0 ? [minimumLimitMinutes] + steppedMinutes : [0] + steppedMinutes
    }

    nonisolated static func steppedLimitMinutes(_ minutes: Int) -> Int {
        let clamped = min(maximumLimitMinutes, max(minimumLimitMinutes, minutes))
        let rounded = ((clamped + limitMinuteStep / 2) / limitMinuteStep) * limitMinuteStep
        return min(maximumLimitMinutes, max(minimumLimitMinutes, rounded))
    }

    func getLimit(for token: ApplicationToken) -> Int {
        Self.steppedLimitMinutes(appLimits[tokenKey(token)] ?? 15)
    }

    func setLimit(_ minutes: Int, for token: ApplicationToken) {
        appLimits[tokenKey(token)] = Self.steppedLimitMinutes(minutes)
    }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
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
        sharedDefaults.integer(forKey: "usage_\(key)_\(dateKey(for: date))")
    }

    func getOpens(forTokenKey key: String, on date: Date) -> Int {
        sharedDefaults.integer(forKey: "opens_\(key)_\(dateKey(for: date))")
    }

    func getTotalDonation(for date: Date) -> Double {
        let limits = appLimits(for: date)
        let totalExcess = activitySelection.applicationTokens.reduce(0) { sum, token in
            let key = tokenKey(token)
            let used = getMinutes(forTokenKey: key, on: date)
            let limit = limits[key] ?? appLimits[key] ?? 15
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

    @discardableResult
    func resetSharedStateIfNewDay() -> Bool {
        let today = dateKey(for: Date())
        guard sharedDefaults.string(forKey: "shieldTodayDate") != today else { return false }

        clearUsageValues(forDateKey: today)

        sharedDefaults.set(0.0, forKey: "dailyDebtUAH")
        sharedDefaults.set(true, forKey: "isFirstShieldToday")
        sharedDefaults.set(5, forKey: "chosenSessionMinutes")
        sharedDefaults.removeObject(forKey: "currentSessionStart")
        sharedDefaults.removeObject(forKey: "currentSessionTokenKey")

        let active = sharedDefaults.string(forKey: "activeSessionSuffixes") ?? ""
        for suffix in active.split(separator: ",").map(String.init) {
            sharedDefaults.removeObject(forKey: "sessionTokenKey_\(suffix)")
            sharedDefaults.removeObject(forKey: "sessionStart_\(suffix)")
            sharedDefaults.removeObject(forKey: "sessionMinutes_\(suffix)")
        }
        sharedDefaults.removeObject(forKey: "activeSessionSuffixes")
        sharedDefaults.set(today, forKey: "shieldTodayDate")
        sharedDefaults.synchronize()

        ManagedSettingsStore().shield.applications = nil
        return true
    }

    // MARK: - Monitoring

    private struct MonitoringRegistration {
        let activityName: String
        let token: ApplicationToken
        let checkpoints: [Int]
    }

    /// Snapshot of the current monitoring config used to detect when a restart is needed.
    /// "v5:" forces re-registration for past-activity events and wider threshold coverage.
    private func monitoringConfigSnapshot() -> String {
        let tokens = activitySelection.applicationTokens
            .map { tokenKey($0) }
            .sorted()
            .map { "\($0.prefix(8)):\(appLimits[$0] ?? 15)" }
            .joined(separator: ",")
        return "v5:\(tokens)"
    }

    private func migrateSharedUsageIfNeeded() {
        let versionKey = "usageDataVersion"
        guard sharedDefaults.string(forKey: versionKey) != Self.usageDataVersion else { return }

        let prefixesToRemove = [
            "usage_",
            "opens_",
            "sessionTokenKey_",
            "sessionStart_",
            "sessionMinutes_"
        ]
        for key in sharedDefaults.dictionaryRepresentation().keys
        where prefixesToRemove.contains(where: { key.hasPrefix($0) }) {
            sharedDefaults.removeObject(forKey: key)
        }

        [
            "dailyDebtUAH",
            "currentSessionStart",
            "currentSessionTokenKey",
            "chosenSessionMinutes",
            "isFirstShieldToday",
            "activeSessionSuffixes",
            "tokenIndexMap",
            "activityTokenMap",
            "monitoringActivityNames",
            "monitoringGeneration",
            "monitoringConfigSnapshot",
            "monitoringError"
        ].forEach { sharedDefaults.removeObject(forKey: $0) }

        sharedDefaults.set(Self.usageDataVersion, forKey: versionKey)
    }

    /// Debounced entry point. Skips the restart if the config is unchanged and
    /// monitoring is healthy — preserving DeviceActivity's daily accumulation counter.
    func scheduleMonitoring() {
        monitoringWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            _ = self.resetSharedStateIfNewDay()
            let snapshot = self.monitoringConfigSnapshot()
            let stored   = self.sharedDefaults.string(forKey: "monitoringConfigSnapshot") ?? ""
            let hasError = self.sharedDefaults.object(forKey: "monitoringError") != nil
            let center = DeviceActivityCenter()
            let storedActivityNames = self.sharedDefaults.stringArray(forKey: "monitoringActivityNames") ?? []
            let isHealthy = self.isMonitoringHealthy(storedActivityNames: storedActivityNames, center: center)
            guard snapshot != stored || hasError || !isHealthy else { return }
            self.startMonitoring()
        }
        monitoringWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func isMonitoringHealthy(
        storedActivityNames: [String],
        center: DeviceActivityCenter
    ) -> Bool {
        if activitySelection.applicationTokens.isEmpty {
            return storedActivityNames.isEmpty
        }

        guard !storedActivityNames.isEmpty else { return false }

        let activeNames = Set(center.activities.map(\.rawValue))
        for rawName in storedActivityNames {
            let name = DeviceActivityName(rawName)
            guard activeNames.contains(rawName) || center.schedule(for: name) != nil else {
                return false
            }
            guard !center.events(for: name).isEmpty else {
                return false
            }
        }

        return true
    }

    func startMonitoring() {
        let center = DeviceActivityCenter()
        let storedActivityNames = sharedDefaults.stringArray(forKey: "monitoringActivityNames") ?? []
        var namesToStop: [DeviceActivityName] = [.daily]
        namesToStop.append(contentsOf: (0..<20).map { DeviceActivityName("screenoriz.app.\($0)") })
        namesToStop.append(contentsOf: storedActivityNames.map { DeviceActivityName($0) })
        center.stopMonitoring(namesToStop)
        ManagedSettingsStore().shield.applications = nil
        guard !activitySelection.applicationTokens.isEmpty else {
            sharedDefaults.removeObject(forKey: "tokenIndexMap")
            sharedDefaults.removeObject(forKey: "activityTokenMap")
            sharedDefaults.removeObject(forKey: "monitoringActivityNames")
            sharedDefaults.removeObject(forKey: "monitoringGeneration")
            sharedDefaults.set(monitoringConfigSnapshot(), forKey: "monitoringConfigSnapshot")
            return
        }

        let sortedTokens = activitySelection.applicationTokens
            .map { (key: tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }
        let generation = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        let limitsMap = Dictionary(uniqueKeysWithValues:
            sortedTokens.map { ($0.key, appLimits[$0.key] ?? 15) })
        if let data = try? JSONEncoder().encode(limitsMap) {
            sharedDefaults.set(data, forKey: "sharedAppLimits")
            sharedDefaults.set(data, forKey: sharedAppLimitsKey(for: Date()))
        }
        sharedDefaults.set(ratePerMinute, forKey: "shieldRatePerMinute")
        sharedDefaults.synchronize()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        // Generated DeviceActivityNames keep threshold callbacks tied to the exact
        // registration that created them. Each app gets at least one activity; when
        // fewer than 20 apps are tracked, spare activity slots extend post-limit
        // coverage so long usage sessions keep updating instead of plateauing.
        var allSucceeded = true
        var activityTokenMap: [String: String] = [:]
        var registrations: [MonitoringRegistration] = []
        let activityBudget = max(sortedTokens.count, 16)
        let chunksPerApp = max(1, activityBudget / max(sortedTokens.count, 1))

        for (index, item) in sortedTokens.enumerated() {
            let suffix = String(item.key.filter { $0.isLetter || $0.isNumber }.prefix(12))
            let limit = appLimits[item.key] ?? 15
            for chunkIndex in 0..<chunksPerApp {
                let rawActivityName = "screenoriz.app.\(generation).\(index).\(chunkIndex).\(suffix)"
                activityTokenMap[rawActivityName] = item.key
                registrations.append(MonitoringRegistration(
                    activityName: rawActivityName,
                    token: item.token,
                    checkpoints: perAppCheckpoints(limit: limit, chunkIndex: chunkIndex)
                ))
            }
        }

        if let data = try? JSONEncoder().encode(activityTokenMap) {
            sharedDefaults.set(data, forKey: "activityTokenMap")
        }
        let monitoringActivityNames = registrations.map(\.activityName)
        sharedDefaults.set(monitoringActivityNames, forKey: "monitoringActivityNames")
        sharedDefaults.set(generation, forKey: "monitoringGeneration")

        for (index, registration) in registrations.enumerated() {
            let activityName = DeviceActivityName(registration.activityName)
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minute in registration.checkpoints {
                events[DeviceActivityEvent.Name("m\(minute)")] = makeMonitoringEvent(
                    token: registration.token,
                    minute: minute
                )
            }
            do {
                try center.startMonitoring(activityName, during: schedule, events: events)
            } catch {
                sharedDefaults.set(
                    "startMonitoring(app\(index)) failed \(Date()): \(error)",
                    forKey: "monitoringError"
                )
                print("DeviceActivity error app\(index): \(error)")
                allSucceeded = false
            }
        }

        if allSucceeded {
            sharedDefaults.removeObject(forKey: "monitoringError")
            sharedDefaults.set(monitoringConfigSnapshot(), forKey: "monitoringConfigSnapshot")
        }
    }

    private func makeMonitoringEvent(token: ApplicationToken, minute: Int) -> DeviceActivityEvent {
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(minute: minute),
                includesPastActivity: true
            )
        } else {
            return DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(minute: minute)
            )
        }
    }

    // Generates up to 20 minute checkpoints for a given per-app limit and chunk.
    // DeviceActivity only gives this app values when thresholds fire, so use
    // minute-level checkpoints for common short limits and around overage.
    // The exact limit minute is always guaranteed so shielding fires on time.
    private func perAppCheckpoints(limit: Int, chunkIndex: Int) -> [Int] {
        let limit = max(1, limit)

        guard chunkIndex == 0 else {
            let firstExtraMinute = 20 + ((chunkIndex - 1) * 20 * 5)
            return (0..<20).map { limit + firstExtraMinute + ($0 * 5) }
        }

        var pts = Set<Int>()
        let firstCheckpoint = min(5, limit)
        pts.insert(firstCheckpoint)

        // Use only a small pre-limit budget so more of the 20 event slots remain
        // available for donation debt after the limit is reached.
        if limit > firstCheckpoint {
            for i in 1...4 {
                let minute = Int((Double(i) / 4.0 * Double(limit)).rounded())
                pts.insert(min(limit, max(firstCheckpoint, minute)))
            }
        }

        pts.insert(limit)

        // Keep immediate post-limit debt precise; additional chunks continue in
        // five-minute steps for longer sessions.
        var nextMinute = limit + 1
        while pts.count < 20 {
            pts.insert(nextMinute)
            nextMinute += 1
        }

        return pts.sorted()
    }

    private func clearUsageValues(forDateKey dateKey: String) {
        let suffix = "_\(dateKey)"
        for key in sharedDefaults.dictionaryRepresentation().keys
        where (key.hasPrefix("usage_") || key.hasPrefix("opens_")) && key.hasSuffix(suffix) {
            sharedDefaults.removeObject(forKey: key)
        }
    }

    private func appLimits(for date: Date) -> [String: Int] {
        guard let data = sharedDefaults.data(forKey: sharedAppLimitsKey(for: date)),
              let limits = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return appLimits
        }
        return limits
    }

    private func sharedAppLimitsKey(for date: Date) -> String {
        "sharedAppLimits_\(dateKey(for: date))"
    }
}
