//
//  WeatherContentView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI
import Charts

// MARK: - şehir detayının asıl içeriği, kaydırılabilir kısım
// bunu WeatherView'ın gövdesinden bilerek ayrı bir dosyada tutuyorum: bu View
// tamamen durumsuz, hiçbir ortam nesnesine bağlı değil, sadece kendisine
// verilen veriyi gösteriyor. böylece xcode önizlemesinde tek başına, örnek
// veriyle kolayca test edilebiliyor ve WeatherView'ın kendisi çok daha kısa kalıyor
struct WeatherContentView: View {
    let weather: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    let airQuality: AirQuality?
    let unit: TemperatureUnit
    let windUnit: WindSpeedUnit
    let lastUpdated: Date?
    let onRefresh: () -> Void

    // ilginç bilgi kartının açık olup olmadığı — bu view'ın dışına hiçbir
    // etkisi yok, tamamen kendi içinde başlayıp kendi içinde bitiyor, o
    // yüzden "durumsuz" ilkesini bozmuyor
    @State private var showCityFact = false

    // şehrin kendi saat dilimi. hem günlük tahmindeki "bugün/yarın" hesabı hem
    // de aşağıdaki canlı saat gösterimi bunu kullanıyor, telefonun saatini değil
    private var cityTimeZone: TimeZone {
        TimeZone(secondsFromGMT: weather.timezoneOffsetSeconds) ?? .current
    }

    private var cityCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone
        return calendar
    }

    // verilen anı, şehrin kendi saat dilimine göre "14:32" gibi kısa bir saat
    // yazısına çeviriyor
    private func localTimeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {

                // üst kısım, ana bilgiler
                VStack(spacing: 6) {
                    Text(weather.name)
                        .font(.weatherCityName)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    // antarktika gibi resmi bir ülkesi olmayan yerlerde bu boş
                    // geliyor, boşken hiç göstermiyoruz ki altında anlamsız bir
                    // boşluk kalmasın
                    if !weather.localizedCountryName.isEmpty {
                        Text(weather.localizedCountryName)
                            .font(.weatherCaption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // şehrin o anki yerel saati, dakikada bir kendini tazeliyor.
                    // küçük bir cam hap içinde, diğer küçük yazılardan bilerek
                    // daha belirgin — hızlıca göz atınca hemen okunsun diye
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

                    // günün ölçülen en düşük/en yüksek sıcaklığı, api zaten
                    // veriyordu ama önceden hiç ekranda göstermiyordum
                    HStack(spacing: 6) {
                        Text(String(format: String(localized: "weather.high_format", defaultValue: "Y:%@"), unit.format(weather.tempMax)))
                        Text(String(format: String(localized: "weather.low_format", defaultValue: "D:%@"), unit.format(weather.tempMin)))
                    }
                    .font(.weatherTemperatureSmall)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 2)

                    // hissedilen sıcaklık gerçek sıcaklıktan belirgin farklıysa
                    // küçük bir not ekliyorum, apple'ın kendi uygulamasında da benzeri var
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

                // hızlı öneriler kartı: dakika çözünürlüklü yağış tahmini +
                // kural tabanlı "ne giymeli" önerisi. apple'ın kendi hava
                // durumu uygulamasında olmayan, ikisini bir arada sunan
                // özgün bir dokunuş
                VStack(alignment: .leading, spacing: 14) {
                    // rengi sadece ikona veriyoruz, yazı uygulamanın her
                    // yerdeki aynı normal beyaz metin rengiyle kalıyor —
                    // sadece ikon rengiyle ayrışması daha şık duruyor
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

                // orta kısım, 24 saatlik grafik
                if !hourly.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("24 SAATLİK TAHMİN", icon: "clock")

                        // şu an çizgisi dakikada bir kendini tazeliyor ki grafikteki
                        // konumu gerçek zamana göre kayarak ilerlesin
                        TimelineView(.everyMinute) { timeline in
                            Chart {
                                // open-meteo artık gerçek saatlik veri veriyor, 24
                                // noktanın hepsine etiket koyarsam üst üste binip
                                // karman çorman görünüyor. o yüzden çizgi hâlâ tüm
                                // 24 saati kullanıyor ama nokta ve etiket sadece
                                // 3 saatte bir gösteriliyor
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

                                // grafikte "şu an" neredeyiz onu gösteren, kesik çizgili ince bir işaret.
                                // etiketi küçük bir kapsül içine koyuyorum, yoksa üstündeki başlıkla
                                // (24 SAATLİK TAHMİN) çakışıp karman çorman görünüyordu
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
                                    AxisValueLabel(format: .dateTime.hour())
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

                // günlük tahmin listesi
                if !daily.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("ÖNÜMÜZDEKİ GÜNLER", icon: "calendar")

                        // 7 günün içinden, yağış olasılığı en düşük ve havası
                        // en açık olanı öne çıkarıyorum — hiçbir hava durumu
                        // uygulamasının doğrudan söylemediği bir öneri
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

                // hava kalitesi kartı
                if let airQuality {
                    AirQualityCard(airQuality: airQuality)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }

                // alt kısım, detay kutuları ızgarası
                GlassEffectContainer {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        WeatherDetailBox(icon: "humidity", iconColor: .blue, title: "NEM", value: weather.humidity.percentFormatted, note: weather.humidityComfortLabel)
                        WindDetailBox(speedKmh: weather.windSpeed, degrees: weather.windDeg, gustKmh: weather.windGust, unit: windUnit)

                        WeatherDetailBox(icon: "thermometer.sun", iconColor: .orange, title: "HİSSEDİLEN", value: unit.format(weather.feelsLike), note: weather.feelsLikeDeltaLabel)
                        WeatherDetailBox(icon: "barometer", iconColor: .purple, title: "BASINÇ", value: "\(weather.pressure) hPa", note: weather.pressureLabel)

                        WeatherDetailBox(icon: "eye", iconColor: .teal, title: "GÖRÜŞ", value: "\(weather.visibility / 1000) km", note: weather.visibilityLabel)
                        WeatherDetailBox(icon: "cloud", iconColor: .gray, title: "BULUTLULUK", value: weather.cloudiness.percentFormatted, note: weather.cloudinessLabel)

                        WeatherDetailBox(icon: "thermometer.and.liquid.waves", iconColor: .cyan, title: "ÇİĞ NOKTASI", value: unit.format(weather.dewPoint), note: weather.dewPointComfortLabel)
                        SunTimesBox(
                            sunrise: weather.sunrise,
                            sunset: weather.sunset,
                            sunsetQualityScore: weather.sunsetQualityScore,
                            sunsetQualityLabel: weather.sunsetQualityLabel
                        )

                        // o geceki ay evresi, hiçbir yeni ağ isteği gerekmiyor,
                        // tamamen tarihten hesaplanıyor (bkz. Utilities/MoonPhase.swift)
                        MoonPhaseBox(phase: weather.moonPhase, illuminationPercent: weather.moonIlluminationPercent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .refreshable { onRefresh() }
        .sensoryFeedback(.success, trigger: lastUpdated)
        // ekranın sağ üst köşesinde, kaydırma sırasında yerinde sabit kalan
        // (overlay, scrollview'ın kendi çerçevesine bağlı, içeriğe değil)
        // yüzen bir düğme — apple'ın hava durumu uygulamasında hiç olmayan,
        // bilerek eklediğim özgün bir dokunuş: o an bakılan şehir/yer
        // hakkında vikipedi'den küçük bir "ilginç bilgi" gösteriyor
        .overlay(alignment: .topTrailing) {
            cityFactButton
        }
        .sheet(isPresented: $showCityFact) {
            CityFactSheet(cityName: weather.name, countryName: weather.localizedCountryName)
        }
    }

    // ampul: "burada bir bilgi/fikir var" çağrışımı yapan, uygulamanın geri
    // kalanında hiç kullanılmayan, bilerek amber renkli, kendine has bir ikon —
    // diğer köşe düğmelerinden (yıldız, paylaş) bilinçli olarak farklı dursun diye
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

    // MARK: - hissedilen sıcaklık notu
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

    // düz, tek renkli bir sf symbol yerine, apple'ın kendi sistem
    // uygulamalarında (sağlık, hatırlatıcılar) gördüğümüz gibi ince bir
    // halkalı, yumuşak dolgulu bir rozet içine oturtuyorum — aynı ikon,
    // çok daha "tasarlanmış" hissettiriyor
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
