//
//  NavBar.swift
//  ScreenoRiz
//

import SwiftUI

struct NavBar: View {
    var title: String? = nil
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image("icon-arrow-left")
                    .resizable().frame(width: 20, height: 20)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.15)))
                    .opacity(0.75)
            }

            if let title {
                Spacer()
                Text(title)
                    .font(.ktfTitle)
                    .foregroundStyle(.white)
                Spacer()
                // Balance the back button so title stays centered
                Color.clear.frame(width: 32, height: 32)
            } else {
                Spacer()
            }
        }
    }
}
