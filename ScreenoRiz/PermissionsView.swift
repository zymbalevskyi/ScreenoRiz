//
//  PermissionsView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import UserNotifications
import FamilyControls

// MARK: - Screen Time

struct ScreenTimePermissionView: View {
    @EnvironmentObject var appState: AppState
    @State private var granted = false
    @State private var navigateNext = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Illustration pinned to very bottom of screen
            VStack(spacing: 0) {
                Spacer()
                Image("illus-screentime-permission")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }

            // Top content
            VStack(alignment: .leading, spacing: 0) {
                NavBar(onBack: { dismiss() })

                Text("надати дозволи")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                PermissionRow(icon: "icon-screentime", title: "екранний час", granted: granted) {
                    requestPermission()
                }
                .padding(.top, 24)

                Text("цей доступ дозволить нам обраховувати, скільки саме часу ви провели в обраних вами соцмережах")
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 12)

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 0)

            // Button pinned to bottom, overlaid on illustration
            VStack {
                Spacer()
                Button { navigateNext = true } label: {
                    Text("продовжити")
                        .font(.ktfTitle)
                        .foregroundStyle(granted ? Color.black : Color(hex: "5E5E5E"))
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(granted ? Color.white : Color(hex: "292929")))
                }
                .disabled(!granted)
                .padding(.horizontal, 32)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateNext) {
            NotificationsPermissionView()
        }
        .onAppear {
            granted = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    private func requestPermission() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { granted = true }
            } catch {}
        }
    }
}

// MARK: - Notifications

struct NotificationsPermissionView: View {
    @EnvironmentObject var appState: AppState
    @State private var granted = false
    @State private var navigateNext = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Illustration pinned to very bottom of screen
            VStack(spacing: 0) {
                Spacer()
                Image("illus-notification-permission")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)

            // Top content
            VStack(alignment: .leading, spacing: 0) {
                NavBar(onBack: { dismiss() })

                Text("надати дозволи")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                PermissionRow(icon: "icon-notifications", title: "сповіщення", granted: granted) {
                    requestPermission()
                }
                .padding(.top, 24)

                Text("отримуй сповіщення про накопичену суму\nдля донацій, зможеш налаштувати їх\nпізніше")
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 12)

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 0)

            // Button pinned to bottom, overlaid on illustration
            VStack {
                Spacer()
                Button { navigateNext = true } label: {
                    Text("продовжити")
                        .font(.ktfTitle)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateNext) {
            AppSelectionView()
        }
        .onAppear {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    granted = settings.authorizationStatus == .authorized
                }
            }
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { g, _ in
            DispatchQueue.main.async { granted = g }
        }
    }
}

// MARK: - Shared row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let granted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(icon)
                    .resizable().frame(width: 24, height: 24)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.ktfTitleSmall)
                        .foregroundStyle(.white)
                    Text(granted ? "надано" : "торкніся, щоб увімкнути")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.2, green: 0.2, blue: 0.2)))
        }
        .disabled(granted)
    }
}

#Preview("Screen Time Permission") {
    NavigationStack {
        ScreenTimePermissionView()
    }
    .environmentObject(AppState())
}

#Preview("Notifications Permission") {
    NavigationStack {
        NotificationsPermissionView()
    }
    .environmentObject(AppState())
}
