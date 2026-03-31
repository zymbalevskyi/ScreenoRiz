//
//  HomeView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView()
                .tabItem { Label("огляд", image: "icon-home") }
                .tag(0)

            SettingsView()
                .tabItem { Label("налаштування", image: "icon-gear") }
                .tag(1)
        }
        .tint(Color(hex: "F55426"))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentDate: Date = Date()
    @State private var showCharities = false

    private var sortedTokens: [(key: String, token: ApplicationToken)] {
        appState.activitySelection.applicationTokens
            .map { (key: appState.tokenKey($0), token: $0) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("ScreenoRiz")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 8) {
                        Button { changeDate(by: -1) } label: {
                            Image("icon-arrow-left")
                                .resizable().frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }

                        Text(dateText)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)

                        Button { changeDate(by: 1) } label: {
                            Image("icon-arrow-right")
                                .resizable().frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sortedTokens, id: \.key) { item in
                            AppUsageCard(
                                tokenKey: item.key,
                                token: item.token,
                                date: currentDate
                            )
                        }

                        DonationSummaryCard(date: currentDate) {
                            showCharities = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .fullScreenCover(isPresented: $showCharities) { CharitiesView() }
        .onAppear { appState.startMonitoring() }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        f.locale = Locale(identifier: "uk_UA")
        return f
    }()

    private var dateText: String {
        Calendar.current.isDateInToday(currentDate)
            ? "Сьогодні"
            : Self.dateFormatter.string(from: currentDate)
    }

    private func changeDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.startOfDay(for: newDate) <= today {
            currentDate = newDate
        }
    }
}

// MARK: - App Usage Card

struct AppUsageCard: View {
    @EnvironmentObject var appState: AppState
    let tokenKey: String
    let token: ApplicationToken
    let date: Date

    private var usedMinutes: Int { appState.getMinutes(forTokenKey: tokenKey, on: date) }
    private var limitMinutes: Int { appState.appLimits[tokenKey] ?? 15 }
    private var opens: Int { appState.getOpens(forTokenKey: tokenKey, on: date) }
    private var overLimit: Bool { usedMinutes > limitMinutes }
    private var progress: Double {
        guard limitMinutes > 0 else { return 0 }
        return min(Double(usedMinutes) / Double(limitMinutes), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Label(token)
                    .font(.ktfTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if opens > 0 {
                    Text("  \(opens) входів")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 8)

                Text(timeSummary)
                    .font(.ktfBody)
                    .foregroundStyle(overLimit ? Color(hex: "F55426") : Color(hex: "34C759"))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(overLimit ? Color(hex: "F55426") : Color.white)
                        .frame(width: max(geometry.size.width * progress, progress > 0 ? 4 : 0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
    }

    private func fmt(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0хв" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)хв" }
        return m == 0 ? "\(h)г" : "\(h)г \(m)хв"
    }

    private var timeSummary: String { "\(fmt(usedMinutes)) / \(fmt(limitMinutes))" }
}

// MARK: - Donation Summary Card

struct DonationSummaryCard: View {
    @EnvironmentObject var appState: AppState
    let date: Date
    let onShowCharities: () -> Void

    private var donation: Double { appState.getTotalDonation(for: date) }

    private var formattedDonation: String {
        donation.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(donation))₴"
            : String(format: "%.1f₴", donation)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Сума донату")
                    .font(.ktfTitle)
                    .foregroundStyle(.white)
                Spacer()
                Text(formattedDonation)
                    .font(.ktfTitle)
                    .foregroundStyle(donation > 0 ? Color(hex: "F55426") : .white)
            }

            Button(action: onShowCharities) {
                Text("переглянути фонди")
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("налаштування")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                VStack(spacing: 12) {
                    Button { showOnboarding = true } label: {
                        HStack {
                            Text("переглянути онбординг")
                                .font(.ktfBody)
                                .foregroundStyle(.white)
                            Spacer()
                            Image("icon-arrow-right")
                                .resizable().frame(width: 14, height: 14)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            NavigationStack {
                WelcomeView()
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
