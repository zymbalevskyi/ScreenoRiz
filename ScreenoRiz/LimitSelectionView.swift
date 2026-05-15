//
//  LimitSelectionView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import FamilyControls
import ManagedSettings


struct LimitSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var localMinutes: [String: Int] = [:]
    @State private var expandedKey: String? = nil
    @State private var navigateToRate = false
    @Environment(\.dismiss) var dismiss

    private var sortedTokens: [(key: String, token: ApplicationToken)] {
        appState.activitySelection.applicationTokens
            .map { token in (key: appState.tokenKey(token), token: token) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                NavBar(onBack: { dismiss() })
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ліміти для застосунків")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)

                    Text("встанови денний ліміт часу для кожного застосунку окремо")
                        .font(.ktfBody)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(sortedTokens.enumerated()), id: \.element.key) { index, item in
                            AppLimitRow(
                                token: item.token,
                                isExpanded: expandedKey == item.key,
                                totalMinutes: Binding(
                                    get: { localMinutes[item.key] ?? 15 },
                                    set: { localMinutes[item.key] = $0 }
                                ),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedKey = expandedKey == item.key ? nil : item.key
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }

                Button {
                    saveAllLimits()
                    navigateToRate = true
                } label: {
                    Text("продовжити")
                        .font(.ktfTitle)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateToRate) {
            RateSelectionView()
        }
        .onAppear { initializeLimits() }
    }

    private func initializeLimits() {
        for item in sortedTokens {
            if localMinutes[item.key] == nil {
                localMinutes[item.key] = AppState.steppedLimitMinutes(appState.getLimit(for: item.token))
            }
        }
        if expandedKey == nil, let first = sortedTokens.first {
            expandedKey = first.key
        }
    }

    private func saveAllLimits() {
        for item in sortedTokens {
            appState.setLimit(localMinutes[item.key] ?? 15, for: item.token)
        }
    }
}

// MARK: - AppLimitRow

struct AppLimitRow: View {
    let token: ApplicationToken
    let isExpanded: Bool
    @Binding var totalMinutes: Int
    let onToggle: () -> Void

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 15

    private let hoursRange = Array(0...23)
    private let minutesRange = Array(stride(from: 0, through: 55, by: AppState.limitMinuteStep))

    private var timeText: String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m) хв" }
        if m == 0 { return "\(h) год" }
        return "\(h) год \(m) хв"
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Label(token)
                        .font(.ktfBody)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(timeText)
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.6))
                    Image(isExpanded ? "icon-arrow-up" : "icon-arrow-right")
                        .resizable().frame(width: 14, height: 14)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(16)
            }

            if isExpanded {
                Rectangle()
                    .fill(Color(hex: "292929"))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("починати рахувати після:")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    HStack(spacing: 0) {
                        Picker("Hours", selection: $selectedHours) {
                            ForEach(hoursRange, id: \.self) { h in
                                Text("\(h)")
                                    .foregroundStyle(.white)
                                    .tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text("годин")
                            .foregroundStyle(.white)
                            .font(.ktfBody)
                            .padding(.horizontal, 12)

                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(minutesRange, id: \.self) { m in
                                Text("\(m)")
                                    .foregroundStyle(.white)
                                    .tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text("хв")
                            .foregroundStyle(.white)
                            .font(.ktfBody)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .onChange(of: selectedHours) { _ in commitSelectedLimit() }
                .onChange(of: selectedMinutes) { _ in commitSelectedLimit() }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
        .onAppear {
            syncPickerToLimit()
        }
    }

    private func syncPickerToLimit() {
        totalMinutes = AppState.steppedLimitMinutes(totalMinutes)
        selectedHours = totalMinutes / 60
        selectedMinutes = totalMinutes % 60
    }

    private func commitSelectedLimit() {
        let steppedTotal = AppState.steppedLimitMinutes(selectedHours * 60 + selectedMinutes)
        totalMinutes = steppedTotal
        selectedHours = steppedTotal / 60
        selectedMinutes = steppedTotal % 60
    }
}

#Preview {
    NavigationStack {
        LimitSelectionView()
            .environmentObject(AppState())
    }
}
