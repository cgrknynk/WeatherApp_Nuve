//
//  WeatherLoadingSkeleton.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - yükleniyor iskeleti
// düz bir dönen çark yerine, gelecek ekranın hatlarını andıran ve üzerinde
// yumuşak bir ışık dalgası gezen bir yer tutucu gösteriyorum
struct WeatherLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8).frame(width: 140, height: 20)
                RoundedRectangle(cornerRadius: 24).frame(width: 160, height: 90)
                RoundedRectangle(cornerRadius: 8).frame(width: 120, height: 18)
            }
            .padding(.top, 60)

            RoundedRectangle(cornerRadius: 20).frame(height: 140).padding(.horizontal, 20)
            RoundedRectangle(cornerRadius: 20).frame(height: 190).padding(.horizontal, 20)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20).frame(height: 138)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .foregroundColor(.white.opacity(0.18))
        .shimmering()
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: phase * 500)
                .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
