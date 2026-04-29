//
//  ScreenoRizApp.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import FamilyControls
import DeviceActivity

@main
struct ScreenoRizApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
