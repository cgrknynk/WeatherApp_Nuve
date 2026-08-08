//
//  FavoriteCityRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - favori şehir satırı
// veri henüz gelmediyse (uygulama yeni açıldı, hâlâ yükleniyor) sadece isim
// ve dönen bir çark gösteriyorum. veri geldiyse aynı görünümü tekrar yazmak
// yerine paylaşılan CityWeatherRow bileşenini kullanıyorum
struct FavoriteCityRow: View {
    let favorite: FavoriteCity
    let snapshot: CityWeather?
    let unit: TemperatureUnit

    var body: some View {
        if let snapshot {
            CityWeatherRow(
                name: favorite.displayName,
                temperature: snapshot.temperature,
                systemIconName: snapshot.systemIconName,
                unit: unit,
                timezoneOffsetSeconds: snapshot.timezoneOffsetSeconds,
                conditionCode: snapshot.conditionCode,
                accentColor: favorite.accentColor
            )
        } else {
            HStack {
                Text(favorite.displayName.capitalized)
                    .font(.weatherRowTitle)
                    .foregroundColor(.white)

                Spacer()

                ProgressView()
                    .tint(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .weatherGlassCard(cornerRadius: 18, accentTint: favorite.accentColor)
        }
    }
}
