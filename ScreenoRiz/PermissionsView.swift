//
//  PermissionsView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import UserNotifications

struct PermissionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var notificationPermissionGranted = false
    @State private var navigateToHome = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("надати дозволи")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                
                VStack(spacing: 12) {
                    // Notifications permission
                    Button {
                        requestNotificationPermission()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 40)
                            
                            Text("сповіщення")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if notificationPermissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Screen Time permission (disabled)
                    HStack(spacing: 16) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 40)
                        
                        Text("екранний час")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text("скоро")
                            .font(.caption)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.5))
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                Button {
                    appState.hasCompletedOnboarding = true
                    navigateToHome = true
                } label: {
                    Text("продовжити")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white, lineWidth: 2)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView()
        }
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                notificationPermissionGranted = granted
            }
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
}

#Preview {
    NavigationStack {
        PermissionsView()
            .environmentObject(AppState())
    }
}
