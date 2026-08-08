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

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
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

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 138)
        .weatherGlassCard(accentTint: .orange)
        .accessibilityElement(children: .combine)
    }
}
