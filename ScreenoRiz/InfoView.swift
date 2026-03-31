//
//  InfoView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct InfoView: View {
    @State private var navigateToPermissions = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("поки що час витрачений у соцмережах потрібно вносити вручну. куди відправити донат та підтверджуєш його виконання ти поки теж сам(а). ми вже працюємо над автоматизацією обох процесів, чекайте на оновлення.")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                Text("так, поки застосунок тільки для відданих донатерів :)")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button {
                    navigateToPermissions = true
                } label: {
                    Text("я доросла людина")
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
        .navigationDestination(isPresented: $navigateToPermissions) {
            PermissionsView()
        }
    }
}

#Preview {
    NavigationStack {
        InfoView()
    }
}
