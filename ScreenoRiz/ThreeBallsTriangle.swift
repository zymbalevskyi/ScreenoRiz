//
//  ThreeBallsTriangle.swift
//  ScreenoRiz
//

import SwiftUI

/// Three pulsing dots arranged in an equilateral triangle — same animation as
/// SwiftfulLoadingIndicators' .threeBallsTriangle, built without the dependency.
struct ThreeBallsTriangle: View {
    var color: Color = Color(hex: "E94200")
    var size: CGFloat = 36

    @State private var animating = false

    private var ballSize: CGFloat { size * 0.28 }
    private var radius: CGFloat { size * 0.33 }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let angle = Double(i) * 120.0 - 90.0          // -90°, 30°, 150°
                let rad   = angle * .pi / 180.0
                Circle()
                    .fill(color)
                    .frame(width: ballSize, height: ballSize)
                    .offset(x: radius * CGFloat(cos(rad)),
                            y: radius * CGFloat(sin(rad)))
                    .scaleEffect(animating ? 0.4 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.17),
                        value: animating
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { animating = true }
    }
}
