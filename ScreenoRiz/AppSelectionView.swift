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
                .padding(.top, 72)
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
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
                }
                .padding(.horizontal, 32)

                Spacer()

                HStack(spacing: 16) {
                    Button { dismiss() } label: {
                        Image("icon-arrow-left")
                            .resizable().frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(.white.opacity(0.15)))
                    }

                    Button {
                        navigateToLimit = true
                    } label: {
                        Text("продовжити")
                            .font(.ktfTitleSmall)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    .disabled(selection.applicationTokens.isEmpty)
                    .opacity(selection.applicationTokens.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
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
