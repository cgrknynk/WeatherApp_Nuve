//
//  ShareableWeatherCard.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import SwiftUI

// MARK: - paylaşım için özel çizilen, şık bir görsel kart
// eskiden paylaşım sadece düz bir metindi ("İzmir: 24°, Az Bulutlu" gibi).
// bunun yerine, uygulamanın kendi cam tasarım diliyle çizilmiş bu View'ı
// ImageRenderer ile bir resme çevirip, o resmi paylaşıyoruz (bkz.
// WeatherView.swift'teki paylaş düğmesi) — Instagram hikayesi gibi
// paylaşılabilir, tek başına anlamlı, markalı bir görsel çıkıyor
struct ShareableWeatherCard: View {
    let weather: CityWeather
    let unit: TemperatureUnit

    private var isNight: Bool { weather.isNight }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: WeatherPalette.colors(conditionCode: weather.conditionCode, isNight: isNight),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                Text(weather.name)
                    .font(.weatherCityName)
                    .foregroundColor(.white)

                if !weather.localizedCountryName.isEmpty {
                    Text(weather.localizedCountryName)
                        .font(.weatherCaption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 2)
                }

                Text(unit.format(weather.temperature))
                    .font(.weatherHero)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                HStack(spacing: 8) {
                    Image(systemName: weather.systemIconName)
                        .symbolRenderingMode(.multicolor)
                    Text(weather.conditionDescription.capitalized)
                        .font(.weatherCondition)
                }
                .foregroundColor(.white)
                .opacity(0.9)
                .padding(.top, 8)

                HStack(spacing: 6) {
                    Text(String(format: String(localized: "weather.high_format", defaultValue: "Y:%@"), unit.format(weather.tempMax)))
                    Text(String(format: String(localized: "weather.low_format", defaultValue: "D:%@"), unit.format(weather.tempMin)))
                }
                .font(.weatherTemperatureSmall)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 6)

                Spacer()

                BrandHeader()
                    .padding(.bottom, 32)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .frame(width: 420, height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

#Preview {
    ShareableWeatherCard(
        weather: CityWeather(
            name: "İzmir", country: "TR", temperature: 24, feelsLike: 25, pressure: 1013,
            visibility: 10000, cloudiness: 20, sunrise: nil, sunset: nil,
            conditionDescription: "Az Bulutlu", conditionCode: 801,
            humidity: 55, windSpeed: 12, windDeg: 90, windGust: nil, tempMin: 19, tempMax: 27,
            lat: 38.4, lon: 27.1, timezoneOffsetSeconds: 10800, precipitationNowcast: nil,
            pressureTrend: nil, humidityTrend: nil
        ),
        unit: .celsius
    )
    .padding()
    .background(Color.black)
}
