//
//  PermissionDeniedView.swift
//  ScreenoRiz
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("illus-permission-denied")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 64)

                Text("без дозволу нічого не вийде")
                    .font(.ktfTitleLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 40)

                Text("без дозволу на екранний час застосунок не бачить, скільки ти скролиш, а отже — яким має бути донат")
                    .font(.ktfBody)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                Spacer()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("до налаштувань")
                        .font(.ktfTitle)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Capsule().fill(.white))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
    }
}

#Preview {
    PermissionDeniedView()
}
