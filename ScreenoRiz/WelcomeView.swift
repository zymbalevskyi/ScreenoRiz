//
//  WelcomeView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct WelcomeView: View {
    @State private var navigateToAppSelection = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("привіт! це ScreenoRiz, застосунок для боротьби з надмірним часом у соцмережах. кожна зайва хвилина — донат на суспільне благо.")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                Button {
                    navigateToAppSelection = true
                } label: {
                    Text("почніmo")
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
        .navigationDestination(isPresented: $navigateToAppSelection) {
            AppSelectionView()
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
}
