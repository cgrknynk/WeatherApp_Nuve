//
//  WindDetailBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - rüzgar kutusu, yön pusulası dahil
// kutunun yüksekliği (aşağıda 138) bilerek diğer kutulardan biraz daha ferah,
// hamle satırı eklenince eski sabit yükseklik yetmiyordu, metin kutunun
// dışına taşıyordu
struct WindDetailBox: View {
    let speedKmh: Double
    let degrees: Int?
    let gustKmh: Double?
    let unit: WindSpeedUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
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

            // api bazen rüzgar hamlesini de veriyor, önceden hiç okumuyordum.
            // sadece anlamlı bir değer varsa gösteriyorum
            if let gustKmh, gustKmh > speedKmh {
                Text(String(format: String(localized: "wind.gust_format", defaultValue: "Hamle: %@"), unit.format(gustKmh)))
                    .font(.weatherCaption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 138)
        .weatherGlassCard(accentTint: .mint)
        .accessibilityElement(children: .combine)
    }
}
