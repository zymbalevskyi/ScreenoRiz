//
//  DeviceActivityMonitorExtension.swift
//  ScreenoRizMonitor
//
//  Created by Yevhen on 15.03.2026.
//

import DeviceActivity
import Foundation
import OSLog

private let logger = Logger(subsystem: "app.zymbalevskyi.ScreenoRiz.monitor", category: "DeviceActivity")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let sharedDefaults = UserDefaults(suiteName: "group.app.zymbalevskyi.ScreenoRiz")!

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        logger.info("eventDidReachThreshold: \(event.rawValue)")

        // Event names are "a{appIndex}_m{minutes}" — e.g. "a0_m5"
        let parts = event.rawValue.split(separator: "_")
        guard parts.count == 2,
              parts[0].hasPrefix("a"), parts[1].hasPrefix("m"),
              let appIndex = Int(parts[0].dropFirst()),
              let minutes = Int(parts[1].dropFirst()) else { return }

        guard let mapData = sharedDefaults.data(forKey: "tokenIndexMap"),
              let indexMap = try? JSONDecoder().decode([String: String].self, from: mapData),
              let tokenKey = indexMap[String(appIndex)] else { return }

        let usageKey = "usage_\(tokenKey)_\(todayKey())"
        let current = sharedDefaults.integer(forKey: usageKey)
        if minutes > current {
            sharedDefaults.set(minutes, forKey: usageKey)
            logger.info("wrote \(usageKey) = \(minutes)")
        }
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
