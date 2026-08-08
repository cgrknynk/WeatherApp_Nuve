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
//
// timezoneOffsetSeconds/conditionCode BİLEREK opsiyonel: filtre sonuçları
// (FilterResultsView) bu ikisini hiç vermiyor, sadece favoriler (FavoriteCityRow)
// veriyor — canlı saat ve dikkat çekici hava rozeti SADECE favorilerde görünüyor
struct CityWeatherRow: View {
    let name: String
    let temperature: Double
    let systemIconName: String
    let unit: TemperatureUnit
    var timezoneOffsetSeconds: Int? = nil
    var conditionCode: Int? = nil
    // kullanıcının o favoriye kendi seçtiği kart rengi — verilmezse (filtre
    // sonuçlarında ya da renksiz bir favoride) kartın nötr, varsayılan
    // görünümü aynen kalıyor
    var accentColor: Color? = nil

    // fırtına, kar ya da kuvvetli yağmur gibi "bir bakışta fark edilmesi
    // gereken" durumlar için küçük bir rozet — hafif çise/parçalı bulutlu
    // gibi sıradan durumlarda hiçbir şey göstermiyoruz
    private var notableWeatherIcon: (name: String, color: Color)? {
        guard let conditionCode else { return nil }
        switch conditionCode {
        case 200...232: return ("cloud.bolt.fill", .yellow)
        case 600...622: return ("snowflake", .white)
        case 502, 522, 531: return ("cloud.heavyrain.fill", .cyan)
        default: return nil
        }
    }

    private var cityTimeZone: TimeZone? {
        timezoneOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(name.capitalized)
                        .font(.weatherRowTitle)
                        .foregroundColor(.white)

                    if let notableWeatherIcon {
                        Image(systemName: notableWeatherIcon.name)
                            .font(.caption)
                            .foregroundColor(notableWeatherIcon.color)
                    }
                }

                // şehrin o anki yerel saati, dakikada bir kendini tazeliyor —
                // detay ekranındaki canlı saatle aynı fikir, sadece burada
                // liste satırına sığacak kadar küçük
                if let cityTimeZone {
                    TimelineView(.everyMinute) { timeline in
                        Text(timeline.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone)))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }

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
        .weatherGlassCard(cornerRadius: 18, accentTint: accentColor)
    }
}
