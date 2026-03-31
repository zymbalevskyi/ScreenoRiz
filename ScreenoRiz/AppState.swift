//
//  AppState.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
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
            startMonitoring()
        }
    }

    @Published var appLimits: [String: Int] {
        didSet {
            if let data = try? JSONEncoder().encode(appLimits) {
                UserDefaults.standard.set(data, forKey: "appLimits")
            }
            startMonitoring()
        }
    }

    var dailyLimitMinutes: Int {
        let sum = appLimits.values.reduce(0, +)
        return max(sum, 1)
    }

    @Published var ratePerMinute: Double {
        didSet { UserDefaults.standard.set(ratePerMinute, forKey: "ratePerMinute") }
    }

    let sharedDefaults = UserDefaults(suiteName: "group.app.zymbalevskyi.ScreenoRiz")!

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
        sharedDefaults.integer(forKey: "usage_\(key)_\(dateKey(for: date))")
    }

    func getOpens(forTokenKey key: String, on date: Date) -> Int {
        sharedDefaults.integer(forKey: "opens_\(key)_\(dateKey(for: date))")
    }

    func getTotalDonation(for date: Date) -> Double {
        let excess = max(0, getTotalMinutes(on: date) - dailyLimitMinutes)
        return Double(excess) * ratePerMinute
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

    func startMonitoring() {
        guard !activitySelection.applicationTokens.isEmpty else { return }

        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Build per-app events. Use a stable index (sorted by tokenKey) so the
        // monitor extension can map "a{index}_m{minute}" back to the right token.
        let sortedTokens = activitySelection.applicationTokens
            .map { (key: tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }

        // Persist index → tokenKey map for the monitor extension to read
        let indexMap = Dictionary(uniqueKeysWithValues: sortedTokens.enumerated().map { (String($0.offset), $0.element.key) })
        if let data = try? JSONEncoder().encode(indexMap) {
            sharedDefaults.set(data, forKey: "tokenIndexMap")
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for (index, item) in sortedTokens.enumerated() {
            let perAppLimit = appLimits[item.key] ?? 15
            let maxMinutes = min(max(perAppLimit * 4, 60), 180)
            for minute in 1...maxMinutes {
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

// MARK: - SocialApp (kept for subtitle text and icons used in UI)

enum SocialApp: String, CaseIterable, Identifiable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case twitter = "Twitter(X)"
    case threads = "Threads"
    case facebook = "Facebook"
    case telegram = "Telegram"
    case youtube = "Youtube"
    case olx = "OLX"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .twitter: return "bird.fill"
        case .threads: return "text.bubble.fill"
        case .facebook: return "person.2.fill"
        case .telegram: return "paperplane.fill"
        case .youtube: return "play.rectangle.fill"
        case .olx: return "bag.fill"
        }
    }
}
