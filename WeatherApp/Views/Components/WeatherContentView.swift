//
//  WeatherContentView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI
import Charts

// şehir detayının asıl (kaydırılabilir) içeriği, durumsuz ve tek başına önizlenebilir
struct WeatherContentView: View {
    let weather: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    let airQuality: AirQuality?
    let unit: TemperatureUnit
    let windUnit: WindSpeedUnit
    let lastUpdated: Date?
    let onRefresh: () -> Void

    @State private var showCityFact = false

    private var cityTimeZone: TimeZone {
        TimeZone(secondsFromGMT: weather.timezoneOffsetSeconds) ?? .current
    }

    private var cityCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone
        return calendar
    }

    private func localTimeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {

                VStack(spacing: 6) {
                    Text(weather.name)
                        .font(.weatherCityName)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    if !weather.localizedCountryName.isEmpty {
                        Text(weather.localizedCountryName)
                            .font(.weatherCaption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // şehrin o anki yerel saati, dakikada bir kendini tazeliyor
                    TimelineView(.everyMinute) { timeline in
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(localTimeText(timeline.date))
                                .font(.weatherRowSubtitle.bold())
                        }
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75))
                    }
                    .padding(.top, 2)

                    Text(unit.format(weather.temperature))
                        .font(.weatherHero)
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .padding(.leading, 15)

                    HStack(spacing: 8) {
                        Image(systemName: weather.systemIconName)
                            .symbolRenderingMode(.multicolor)
                            .symbolEffect(.bounce, value: weather.conditionCode)

                        Text(weather.conditionDescription.capitalized)
                            .font(.weatherCondition)
                    }
                    .foregroundColor(.white)
                    .opacity(0.9)

                    HStack(spacing: 6) {
                        Text(String(format: String(localized: "weather.high_format", defaultValue: "Y:%@"), unit.format(weather.tempMax)))
                        Text(String(format: String(localized: "weather.low_format", defaultValue: "D:%@"), unit.format(weather.tempMin)))
                    }
                    .font(.weatherTemperatureSmall)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 2)

                    if abs(weather.feelsLike - weather.temperature) >= 2 {
                        Text(feelsLikeNote(for: weather))
                            .font(.weatherCaption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 2)
                    }

                    if let lastUpdated {
                        Text("Son güncelleme: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.weatherCaption)
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.top, 2)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                Spacer().frame(height: 30)

                VStack(alignment: .leading, spacing: 14) {
                    if let nowcast = weather.precipitationNowcast {
                        Label {
                            Text(nowcast)
                        } icon: {
                            iconBadge("cloud.rain.fill", tint: .cyan)
                        }
                    }

                    Label {
                        Text(weather.outfitSuggestion)
                    } icon: {
                        iconBadge("tshirt.fill", tint: .orange)
                    }
                }
                .font(.weatherCaption.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .weatherGlassCard()
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                if !hourly.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("24 SAATLİK TAHMİN", icon: "clock")

                        TimelineView(.everyMinute) { timeline in
                            Chart {
                                // etiket karmaşası olmasın diye nokta/etiket sadece 3 saatte bir
                                ForEach(Array(hourly.enumerated()), id: \.offset) { index, forecast in
                                    AreaMark(
                                        x: .value("Saat", forecast.time),
                                        y: .value("Sıcaklık", forecast.temperature)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                                    )

                                    LineMark(
                                        x: .value("Saat", forecast.time),
                                        y: .value("Sıcaklık", forecast.temperature)
                                    )
                                    .foregroundStyle(.white)
                                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                                    if index % 3 == 0 {
                                        PointMark(
                                            x: .value("Saat", forecast.time),
                                            y: .value("Sıcaklık", forecast.temperature)
                                        )
                                        .foregroundStyle(.white)
                                        .annotation(position: .top) {
                                            Text(unit.format(forecast.temperature))
                                                .font(.weatherTemperatureSmall.bold())
                                                .foregroundColor(.white)
                                        }
                                    }
                                }

                                // "şu an" çizgisi, kendi kapsülü içindeki saatle
                                RuleMark(x: .value("Şu An", timeline.date))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .annotation(position: .top, spacing: 2) {
                                        Text(localTimeText(timeline.date))
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(.black.opacity(0.35)))
                                    }
                            }
                            .padding(.top, 20)
                            .frame(height: 120)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                                    AxisValueLabel(format: Date.FormatStyle(timeZone: cityTimeZone).hour())
                                        .foregroundStyle(.white)
                                }
                            }
                            .chartYAxis(.hidden)
                        }
                    }
                    .padding()
                    .weatherGlassCard()
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 20)

                if !daily.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("ÖNÜMÜZDEKİ GÜNLER", icon: "calendar")

                        if let bestDay = daily.bestOutdoorDay {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text(String(
                                    format: String(localized: "weather.best_day_format", defaultValue: "Dışarı çıkmak için en iyi gün: %@"),
                                    RelativeDayFormatter.label(for: bestDay.date, calendar: cityCalendar)
                                ))
                            }
                            .font(.weatherCaption.bold())
                            .foregroundColor(.green.opacity(0.9))
                            .padding(.horizontal, 5)
                        }

                        VStack(spacing: 12) {
                            ForEach(daily) { day in
                                DailyForecastRow(day: day, calendar: cityCalendar, unit: unit)
                            }
                        }
                        .padding()
                        .weatherGlassCard()
                    }
                    .padding(.horizontal, 20)
                }

                Spacer().frame(height: 20)

                if let airQuality {
                    AirQualityCard(airQuality: airQuality)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }

                detailsGrid
                    .weatherGlassEffectContainer()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            // iPad'in geniş ekranında kartlar telefon genişliğinde tasarlanmış
            // içerikle (sol hizalı metin, sabit yükseklikli satırlar) uçtan uca
            // esneyince sağda kocaman boş alan bırakıyordu; okunabilir bir üst
            // sınırla (700pt) sütunu ortalamak hem üstteki kartları hem de
            // detay ızgarasını aynı anda düzeltiyor
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .refreshable { onRefresh() }
        .sensoryFeedback(.success, trigger: lastUpdated)
        // yüzen köşe düğmesi, kaydırırken de yerinde sabit kalıyor (overlay
        // scrollview'ın çerçevesine bağlı, içeriğe değil)
        .overlay(alignment: .topTrailing) {
            cityFactButton
        }
        .sheet(isPresented: $showCityFact) {
            CityFactSheet(cityName: weather.name, countryName: weather.localizedCountryName)
        }
    }

    // sabit 2 sütun iPad'in geniş ekranında kutuları aşırı esnetip boş
    // görünmesine yol açıyordu; .adaptive ile kutu genişliği 200pt'te
    // sınırlanıyor, geniş ekranlarda otomatik olarak daha fazla sütun açılıyor
    private var detailsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 15)], spacing: 15) {
            WeatherDetailBox(icon: "humidity", iconColor: .blue, title: "NEM", value: weather.humidity.percentFormatted, note: weather.humidityComfortLabel, trend: weather.humidityTrend)
            WindDetailBox(speedKmh: weather.windSpeed, degrees: weather.windDeg, gustKmh: weather.windGust, unit: windUnit)

            WeatherDetailBox(icon: "thermometer.sun", iconColor: .orange, title: "HİSSEDİLEN", value: unit.format(weather.feelsLike), note: weather.feelsLikeDeltaLabel)
            WeatherDetailBox(icon: "barometer", iconColor: .purple, title: "BASINÇ", value: "\(weather.pressure) hPa", note: weather.pressureLabel, trend: weather.pressureTrend)

            WeatherDetailBox(icon: "eye", iconColor: .teal, title: "GÖRÜŞ", value: "\(weather.visibility / 1000) km", note: weather.visibilityLabel)
            WeatherDetailBox(icon: "cloud", iconColor: .gray, title: "BULUTLULUK", value: weather.cloudiness.percentFormatted, note: weather.cloudinessLabel)

            WeatherDetailBox(icon: "thermometer.and.liquid.waves", iconColor: .cyan, title: "ÇİĞ NOKTASI", value: unit.format(weather.dewPoint), note: weather.dewPointComfortLabel)
            SunTimesBox(
                sunrise: weather.sunrise,
                sunset: weather.sunset,
                sunsetQualityScore: weather.sunsetQualityScore,
                sunsetQualityLabel: weather.sunsetQualityLabel
            )

            MoonPhaseBox(phase: weather.moonPhase, illuminationPercent: weather.moonIlluminationPercent)
        }
    }

    private var cityFactButton: some View {
        Button {
            showCityFact = true
        } label: {
            Image(systemName: "lightbulb.max.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.yellow.opacity(0.18)))
                .overlay(Circle().strokeBorder(.yellow.opacity(0.35), lineWidth: 0.75))
        }
        .padding(.top, 8)
        .padding(.trailing, 20)
        .accessibilityLabel(String(localized: "fact.button_label", defaultValue: "İlginç bilgi göster"))
    }

    private func feelsLikeNote(for weather: CityWeather) -> String {
        weather.feelsLike > weather.temperature
            ? String(localized: "weather.feels_warmer", defaultValue: "Gerçek sıcaklıktan daha sıcak hissettiriyor")
            : String(localized: "weather.feels_cooler", defaultValue: "Gerçek sıcaklıktan daha serin hissettiriyor")
    }

    private func sectionHeader(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .tracking(1.1)
        }
        .font(.weatherSectionHeader)
        .foregroundColor(.white.opacity(0.6))
        .padding(.horizontal, 5)
    }

    private func iconBadge(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(tint.opacity(0.18))
                    .overlay(Circle().strokeBorder(tint.opacity(0.4), lineWidth: 1))
            }
    }
}
