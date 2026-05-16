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

    nonisolated static let limitMinuteStep = 5

    nonisolated static func steppedLimitMinutes(_ minutes: Int) -> Int {
        let rounded = ((max(0, minutes) + limitMinuteStep / 2) / limitMinuteStep) * limitMinuteStep
        return min(23 * 60 + 55, max(limitMinuteStep, rounded))
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

    /// Snapshot of the current monitoring config used to detect when a restart is needed.
    /// "v3:" forces re-registration for the minute-level threshold scheme.
    private func monitoringConfigSnapshot() -> String {
        let tokens = activitySelection.applicationTokens
            .map { tokenKey($0) }
            .sorted()
            .map { "\($0.prefix(8)):\(appLimits[$0] ?? 15)" }
            .joined(separator: ",")
        return "v3:\(tokens)"
    }

    /// Debounced entry point. Skips the restart if the config is unchanged and
    /// monitoring is healthy — preserving DeviceActivity's daily accumulation counter.
    func scheduleMonitoring() {
        monitoringWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let snapshot = self.monitoringConfigSnapshot()
            let stored   = self.sharedDefaults.string(forKey: "monitoringConfigSnapshot") ?? ""
            let hasError = self.sharedDefaults.object(forKey: "monitoringError") != nil
            guard snapshot != stored || hasError else { return }
            self.startMonitoring()
        }
        monitoringWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func startMonitoring() {
        let center = DeviceActivityCenter()
        // Stop legacy single-activity monitoring and any existing per-app activities.
        center.stopMonitoring([.daily] + (0..<20).map { DeviceActivityName("screenoriz.app.\($0)") })
        ManagedSettingsStore().shield.applications = nil
        guard !activitySelection.applicationTokens.isEmpty else { return }

        let sortedTokens = activitySelection.applicationTokens
            .map { (key: tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }

        let indexMap = Dictionary(uniqueKeysWithValues:
            sortedTokens.enumerated().map { (String($0.offset), $0.element.key) })
        if let data = try? JSONEncoder().encode(indexMap) {
            sharedDefaults.set(data, forKey: "tokenIndexMap")
        }

        let limitsMap = Dictionary(uniqueKeysWithValues:
            sortedTokens.map { ($0.key, appLimits[$0.key] ?? 15) })
        if let data = try? JSONEncoder().encode(limitsMap) {
            sharedDefaults.set(data, forKey: "sharedAppLimits")
        }
        sharedDefaults.set(ratePerMinute, forKey: "shieldRatePerMinute")

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        // One DeviceActivityName per app — each allows up to 20 events independently,
        // giving dense checkpoints for minute-level accuracy instead of 5 coarse points.
        var allSucceeded = true
        for (index, item) in sortedTokens.enumerated() {
            let limit = appLimits[item.key] ?? 15
            let activityName = DeviceActivityName("screenoriz.app.\(index)")
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minute in perAppCheckpoints(limit: limit) {
                events[DeviceActivityEvent.Name("m\(minute)")] = DeviceActivityEvent(
                    applications: [item.token],
                    threshold: DateComponents(minute: minute)
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

    // Generates up to 20 minute checkpoints for a given per-app limit.
    // DeviceActivity only gives this app values when thresholds fire, so use
    // minute-level checkpoints for common short limits and around overage.
    // The exact limit minute is always guaranteed so shielding fires on time.
    private func perAppCheckpoints(limit: Int) -> [Int] {
        let limit = max(1, limit)

        if limit <= 20 {
            return Array(1...20)
        }

        var pts = Set<Int>()
        pts.insert(1)
        pts.insert(min(5, limit))

        // Spread checkpoints before the limit so longer limits still show progress.
        for i in 1...8 {
            let minute = Int((Double(i) / 8.0 * Double(limit)).rounded())
            pts.insert(max(1, minute))
        }

        pts.insert(limit)

        // Keep post-limit debt precise for as many minutes as the event budget allows.
        var nextMinute = limit + 1
        while pts.count < 20 {
            pts.insert(nextMinute)
            nextMinute += 1
        }

        return pts.sorted()
    }
}
