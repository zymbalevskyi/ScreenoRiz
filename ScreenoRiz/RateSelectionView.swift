//
//  RateSelectionView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct RateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    private let rates: [Double] = [0.5, 1, 2, 3, 4, 5]
    @State private var selectedRate: Double = 1
    @State private var navigateToInfo = false
    @Namespace private var pillNamespace

    private func rateLabel(_ rate: Double, active: Bool = false) -> String {
        let num = rate.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rate))"
            : String(format: "%.1f", rate)
        return active ? "\(num)₴" : num
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavBar(onBack: { dismiss() })

                // Title + subtitle
                VStack(alignment: .leading, spacing: 12) {
                    Text("обрати \"тариф\"")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)

                    Text("встанови скільки коштуватиме кожна хвилина понад лімітом")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 24)

                // Rate card
                VStack(spacing: 16) {
                    Text("1 хвилина дорівнює")
                        .font(.ktfTitleSmall)
                        .foregroundStyle(.white)

                    // Pill selector with sliding animation
                    HStack(spacing: 4) {
                        ForEach(rates, id: \.self) { rate in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedRate = rate
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(rateLabel(rate, active: rate == selectedRate))
                                    .font(.ktfBody)
                                    .foregroundStyle(.white.opacity(rate == selectedRate ? 1 : 0.45))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background {
                                        if rate == selectedRate {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(hex: "5E5E5E"))
                                                .matchedGeometryEffect(id: "pill", in: pillNamespace)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "292929")))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "121212")))
                .padding(.top, 28)

                Spacer()

                // Hint + Continue button
                VStack(spacing: 16) {
                    Text("ти завжди зможеш змінити вибір")
                        .font(.ktfCaption)
                        .foregroundStyle(.white.opacity(0.35))

                    Button {
                        appState.ratePerMinute = selectedRate
                        navigateToInfo = true
                    } label: {
                        Text("продовжити")
                            .font(.ktfTitle)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(Capsule().fill(.white))
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $navigateToInfo) {
            InfoView()
        }
        .onAppear {
            selectedRate = appState.ratePerMinute
        }
    }
}

#Preview {
    NavigationStack {
        RateSelectionView()
            .environmentObject(AppState())
    }
}
