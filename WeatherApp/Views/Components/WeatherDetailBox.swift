//
//  WeatherDetailBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - cam efektli detay kutusu
// title'ı bilerek LocalizedStringKey yaptım: çağıran taraf hep sabit bir metin
// geçiyor ("NEM", "BASINÇ" gibi), bu tip sayesinde swiftui bunu otomatik
// çeviri kataloğunda arıyor. düz String olsaydı bu otomatik arama çalışmazdı
struct WeatherDetailBox: View {
    var icon: String
    // apple'ın kendi detay kartlarında olduğu gibi her ikon kendi anlamına
    // uygun bir renk taşıyor (nem mavi, basınç mor gibi), düz beyazdan daha canlı duruyor
    var iconColor: Color = .white
    var title: LocalizedStringKey
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.weatherCardTitle)
                    .foregroundColor(iconColor)
                Text(title)
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(value)
                .font(.weatherCardValue)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 138)
        .weatherGlassCard(accentTint: iconColor)
        // voiceover bunu "nem, %65" gibi tek bir cümle olarak okusun diye,
        // yoksa ikon/etiket/değer ayrı ayrı, kopuk kopuk okunuyordu
        .accessibilityElement(children: .combine)
    }
}
