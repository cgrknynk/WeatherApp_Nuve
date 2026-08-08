//
//  AirQualityCard.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - hava kalitesi kartı
// ayrı ve ücretsiz kirlilik servisinden gelen endeksi şehir detay ekranında
// küçük bir cam kart olarak gösteriyorum
struct AirQualityCard: View {
    let airQuality: AirQuality

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(airQuality.tintColor)
                .frame(width: 14, height: 14)
                .shadow(color: airQuality.tintColor.opacity(0.6), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("HAVA KALİTESİ")
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.6))

                Text(airQuality.label)
                    .font(.weatherRowTitle)
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding()
        .weatherGlassCard(accentTint: airQuality.tintColor)
        .accessibilityElement(children: .combine)
    }
}
