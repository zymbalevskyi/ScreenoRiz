//
//  InfoView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct InfoView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NavBar(onBack: { dismiss() })

                // Title + subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text("обрати складність")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)

                    Text("встанови скільки коштує одна зайва\nхвилина у соцмережах")
                        .font(.ktfBody)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 24)

                // Option cards — unchanged
                VStack(spacing: 12) {
                    // Card 1 — середній
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("середній")
                                .font(.ktfTitle)
                                .foregroundStyle(.white)
                            Text("ми лише рахуємо вам суму, ви\nдонатите на власний розсуд")
                                .font(.ktfCaption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            Image("icon-check")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.black)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "121212"))
                    )

                    // Card 2 — складний (locked)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("складний")
                                    .font(.ktfTitle)
                                    .foregroundStyle(.white)
                                Text("СКОРО")
                                    .font(.ktfCaption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: "292929"))
                                    )
                            }
                            Text("додамо платіжну систему для\nдонатів та блокування застосунків")
                                .font(.ktfCaption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Image("icon-lock")
                            .renderingMode(.template)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 24, height: 24)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "121212"))
                    )
                }
                .padding(.top, 32)

                Spacer()

                // Continue button
                Button {
                    appState.hasCompletedOnboarding = true
                } label: {
                    Text("продовжити")
                        .font(.ktfTitle)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(.white))
                }
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        InfoView()
            .environmentObject(AppState())
    }
}
