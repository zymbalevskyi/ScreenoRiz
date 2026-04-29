//
//  CharitiesView.swift
//  ScreenoRiz
//

import SwiftUI

// MARK: - Sheet

struct CharitiesView: View {
    let donationAmount: String

    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()

            VStack(spacing: 0) {
                // Donation amount header
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("сума донату")
                            .font(.ktfTitle)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("можете і більше, звісно")
                            .font(.ktfCaption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(donationAmount)
                        .font(.ktfTitleSmall)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Jar cards
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Charity.all) { jar in
                            JarCard(jar: jar)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundCompat(Color(hex: "121212"))
    }
}

// MARK: - Card

struct JarCard: View {
    let jar: Charity

    private let coverHeight: CGFloat = 160
    private let logoSize:    CGFloat = 52

    var body: some View {
        let url = URL(string: jar.url)

        VStack(alignment: .leading, spacing: 0) {
            // ── Cover (fixed 160pt height) ───────────────────────────────
            GeometryReader { geo in
                Group {
                    if !jar.coverAsset.isEmpty {
                        Image(jar.coverAsset)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.white.opacity(0.07)
                    }
                }
                .frame(width: geo.size.width, height: coverHeight)
                .clipped()
            }
            .frame(height: coverHeight)

            // ── Info ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image("icon-verified")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(jar.fundLabel)
                        .font(.ktfCaptionSmall)
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(alignment: .center, spacing: 0) {
                    Text(jar.name)
                        .font(.ktfTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "292929"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let url { UIApplication.shared.open(url) }
        }
        // Logo sits OUTSIDE clipShape so it overlaps the cover/info boundary.
        .overlay {
            if !jar.logoAsset.isEmpty {
                GeometryReader { geo in
                    ZStack {
                        Circle().fill(Color(hex: "292929"))
                        Image(jar.logoAsset)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .padding(4)
                    }
                    .frame(width: logoSize, height: logoSize)
                    .position(
                        x: geo.size.width - 16 - logoSize / 2,
                        y: coverHeight
                    )
                }
            }
        }
    }
}


#Preview {
    CharitiesView(donationAmount: "93 ₴")
}
