//
//  SunTimesBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - gündoğumu / günbatımı kutusu
// sunrise ve sunset zaten çekiliyordu ama sadece gece/gündüz hesabında
// kullanılıyordu, hiç gerçek saat olarak gösterilmiyordu. shortened biçimi
// telefonun 12/24 saat ayarına otomatik uyuyor
struct SunTimesBox: View {
    let sunrise: Date?
    let sunset: Date?
    // 1-10 arası, günbatımının ne kadar "güzel" olabileceğine dair kaba bir
    // tahmin (bkz. CityWeather.sunsetQualityScore) — hiçbir hava durumu
    // uygulamasının vermediği, özgün bir dokunuş
    let sunsetQualityScore: Int
    let sunsetQualityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sun.horizon")
                    .font(.weatherCardTitle)
                    .foregroundColor(.orange)
                Text("GÜNDOĞUMU / GÜNBATIMI")
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 14) {
                Label {
                    Text(sunrise?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                } icon: {
                    Image(systemName: "sunrise.fill").foregroundColor(.orange)
                }

                Label {
                    Text(sunset?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                } icon: {
                    Image(systemName: "sunset.fill").foregroundColor(.indigo)
                }
            }
            .font(.weatherCaption.bold())
            .foregroundColor(.white)

            HStack(spacing: 5) {
                Image(systemName: "wand.and.stars")
                    .font(.caption2)
                Text("\(sunsetQualityScore)/10 — \(sunsetQualityLabel)")
                    .font(.caption2.bold())
            }
            .foregroundColor(.orange.opacity(0.9))

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 138)
        .weatherGlassCard(accentTint: .orange)
        .accessibilityElement(children: .combine)
    }
}
