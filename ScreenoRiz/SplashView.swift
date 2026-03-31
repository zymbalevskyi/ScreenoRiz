//
//  SplashView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct SplashView: View {
    @State private var navigateToWelcome = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Image(systemName: "sterlingsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                navigateToWelcome = true
            }
        }
        .navigationDestination(isPresented: $navigateToWelcome) {
            WelcomeView()
        }
    }
}

#Preview {
    NavigationStack {
        SplashView()
    }
}
