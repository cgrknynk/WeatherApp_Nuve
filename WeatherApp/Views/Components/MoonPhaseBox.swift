//
//  MoonPhaseBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import SwiftUI

struct MoonPhaseBox: View {
    let phase: MoonPhase
    let illuminationPercent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.weatherCardTitle)
                    .foregroundColor(.indigo)
                Text("AY EVRESİ")
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(phase.localizedName)
                .font(.weatherCardValue)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(format: String(localized: "moon.illumination_format", defaultValue: "Aydınlanma: %@"), illuminationPercent.percentFormatted))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.indigo.opacity(0.9))

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: weatherDetailBoxHeight)
        .background(alignment: .bottomTrailing) {
            Image(systemName: phase.systemImageName)
                .font(.system(size: 68))
                .symbolRenderingMode(.multicolor)
                .opacity(0.3)
                .offset(x: 14, y: 14)
        }
        .clipped()
        .weatherGlassCard(accentTint: .indigo)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            MoonPhaseBox(phase: .waningCrescent, illuminationPercent: 22)
            MoonPhaseBox(phase: .fullMoon, illuminationPercent: 98)
        }
        .padding()
    }
}
