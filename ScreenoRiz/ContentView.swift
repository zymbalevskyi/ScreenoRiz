//
//  ContentView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var authCenter = AuthorizationCenter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                switch authCenter.authorizationStatus {
                case .approved:
                    HomeView()
                case .notDetermined:
                    // Status hasn't resolved yet — hold on a black screen to avoid
                    // flashing PermissionDeniedView while FamilyControls initialises.
                    Color.black.ignoresSafeArea()
                default:
                    PermissionDeniedView()
                }
            } else {
                NavigationStack {
                    SplashView()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  appState.hasCompletedOnboarding,
                  authCenter.authorizationStatus == .approved else { return }
            appState.resetSharedStateIfNewDay()
            appState.scheduleMonitoring()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
