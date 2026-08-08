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
    var iconColor: Color
    var title: LocalizedStringKey
    var value: String
    // çıplak bir sayı ("%38" gibi) tek başına yorumsuz kalıyordu — bu kısa
    // etiket ("Rahat"/"Kuru" gibi) sayının ne anlama geldiğini ekliyor.
    // opsiyonel: her kutunun anlamlı bir yorumu olmayabilir
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: weatherDetailBoxHeight)
        .weatherGlassCard(accentTint: iconColor)
        // voiceover bunu "nem, %65" gibi tek bir cümle olarak okusun diye,
        // yoksa ikon/etiket/değer ayrı ayrı, kopuk kopuk okunuyordu
        .accessibilityElement(children: .combine)
    }
}
