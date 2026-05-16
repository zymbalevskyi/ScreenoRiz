//
//  WelcomeView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct WelcomeView: View {
    @State private var navigateToPermissions = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Illustration
                Image("illus-welcome-screen")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 120)

                // Description Text
                Text("Screenoriz – застосунок, що рахує надмірний екранний час як донати на суспільне благо")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 40)

                Spacer()

                // Start Button
                Button {
                    navigateToPermissions = true
                } label: {
                    Text("почнімо")
                        .font(.ktfTitle)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToPermissions) {
            ScreenTimePermissionView()
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
}
