//
//  RateSelectionView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct RateSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var ratePerMinute: Double = 1.0
    @State private var navigateToInfo = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("обери тариф")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("встанови денний ліміт часу, перевищення якого буде рахувати суму донату")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                Spacer()
                
                // Rate card
                VStack(spacing: 16) {
                    Text("1хв = \(Int(ratePerMinute))₴")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white, lineWidth: 2)
                )
                .padding(.horizontal, 32)
                
                // Slider
                VStack(spacing: 8) {
                    Slider(value: $ratePerMinute, in: 1...10, step: 1)
                        .tint(.white)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text("1₴")
                            .foregroundStyle(.gray)
                            .font(.caption)
                        Spacer()
                        Text("10₴")
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                Button {
                    appState.ratePerMinute = Int(ratePerMinute)
                    navigateToInfo = true
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
        .navigationDestination(isPresented: $navigateToInfo) {
            InfoView()
        }
    }
}

#Preview {
    NavigationStack {
        RateSelectionView()
            .environmentObject(AppState())
    }
}
