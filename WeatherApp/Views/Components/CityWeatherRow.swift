//
//  CityWeatherRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - isim + sıcaklık + ikon satırı
// favoriler listesindeki satır ile filtre sonuçlarındaki satır neredeyse
// birebir aynıydı, ikisi de bu tek bileşeni kullanıyor artık, bir şeyi
// değiştirmek gerekince tek dosyayı değiştirmem yetiyor
struct CityWeatherRow: View {
    let name: String
    let temperature: Double
    let systemIconName: String
    let unit: TemperatureUnit

    var body: some View {
        HStack {
            Text(name.capitalized)
                .font(.weatherRowTitle)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: systemIconName)
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .foregroundColor(.white)

            Text(unit.format(temperature))
                .font(.weatherRowTemperature)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .weatherGlassCard(cornerRadius: 18)
    }
}
