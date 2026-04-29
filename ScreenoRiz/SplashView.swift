//
//  SplashView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        WelcomeView()
    }
}

#Preview {
    NavigationStack {
        SplashView()
            .environmentObject(AppState())
    }
}
