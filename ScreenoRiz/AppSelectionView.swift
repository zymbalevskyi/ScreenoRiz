//
//  AppSelectionView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var navigateToLimit = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                NavBar(onBack: { dismiss() })
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 8) {
                    Text("обери соцмережі")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)

                    Text("обери мережі, у яких хочеш проводити менше часу")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 32)

                // Picker trigger
                Button { showingPicker = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("обрані застосунки")
                                .font(.ktfTitleSmall)
                                .foregroundStyle(.white)
                            Text(selectionSummary)
                                .font(.ktfBody)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Image("icon-arrow-right")
                            .resizable().frame(width: 16, height: 16)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    navigateToLimit = true
                } label: {
                    Text("продовжити")
                        .font(.ktfTitle)
                        .foregroundStyle(selection.applicationTokens.isEmpty ? Color(hex: "5E5E5E") : .black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(selection.applicationTokens.isEmpty ? Color(hex: "292929") : .white))
                }
                .disabled(selection.applicationTokens.isEmpty)
                .padding(.horizontal, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToLimit) {
            LimitSelectionView()
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
        .onChange(of: selection) { newSelection in
            // Persist and kick off monitoring immediately so the monitor extension
            // resolves app names before the user navigates to LimitSelectionView.
            appState.activitySelection = newSelection
        }
        .onAppear {
            selection = appState.activitySelection
        }
    }

    private var selectionSummary: String {
        let count = selection.applicationTokens.count
        return count == 0 ? "торкніться, щоб обрати" : "\(count) застосунок(ів) обрано"
    }
}

#Preview {
    NavigationStack {
        AppSelectionView()
            .environmentObject(AppState())
    }
}
