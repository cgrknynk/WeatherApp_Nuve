//
//  WindDetailBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

struct WindDetailBox: View {
    let speedKmh: Double
    let degrees: Int?
    let gustKmh: Double?
    let unit: WindSpeedUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.weatherCardTitle)
                    .foregroundColor(.mint)
                Text("RÜZGAR")
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 8) {
                Text(unit.format(speedKmh))
                    .font(.weatherCardValue)
                    .foregroundColor(.white)

                if let degrees {
                    Image(systemName: "location.north.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .rotationEffect(.degrees(Double(degrees)))
                }
            }

            if let gustKmh, gustKmh > speedKmh {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: String(localized: "wind.gust_format", defaultValue: "Ani hamle: %@"), unit.format(gustKmh)))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(.mint.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: weatherDetailBoxHeight)
        .weatherGlassCard(accentTint: .mint)
        .accessibilityElement(children: .combine)
    }
}
