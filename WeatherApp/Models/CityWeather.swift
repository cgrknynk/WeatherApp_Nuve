//
//  CityWeather.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - şehrin hava durumu verisi
struct CityWeather: Codable, Equatable {
    // burası "var" çünkü şehir ismini sonradan değiştirmem gerekiyor. api bazen
    // aradığım şehir yerine yakınındaki bir semti döndürüyordu, o yüzden ekranda
    // gösterilecek ismi kendim düzeltip üzerine yazıyorum (applying fonksiyonuna bak)
    var name: String
    let country: String
    let temperature: Double

    let feelsLike: Double
    let pressure: Int
    let visibility: Int
    let cloudiness: Int

    // gündoğumu ve günbatımı saatleri, ekranda alt tarafta gösteriliyor
    let sunrise: Date?
    let sunset: Date?

    let conditionDescription: String
    let conditionCode: Int // ekrandaki ikonu, arka plan rengini ve parçacık efektini bu kod belirliyor
    let humidity: Int
    let windSpeed: Double
    let windDeg: Int? // rüzgarın yönü, ekrandaki küçük pusula okuna bunu veriyorum
    let windGust: Double? // ani rüzgar hamlesi, api her zaman göndermiyor o yüzden opsiyonel

    let tempMin: Double // o günün en düşük ölçülen sıcaklığı
    let tempMax: Double // o günün en yüksek ölçülen sıcaklığı

    // şehrin koordinatları, hava kalitesi isteği için lazım
    let lat: Double
    let lon: Double

    // şehrin utc'ye göre saat farkı. günlük tahmindeki "bugün/yarın" hesabını
    // telefonun saatine göre değil şehrin kendi saatine göre yapmam lazım,
    // yoksa yurt dışı bir şehirde günler kayıp yanlış görünüyordu
    let timezoneOffsetSeconds: Int

    // "yağış 12 dakika içinde başlıyor" gibi, dakika çözünürlüklü bir tahmin.
    // hazır gelmiyor, WeatherService bunu open-meteo'nun 15 dakikalık verisinden
    // kendisi hesaplayıp burada hazır bir metin olarak bırakıyor (bkz. o dosya)
    let precipitationNowcast: String?

    // basınç/nem kutularındaki küçük trend oku için — "şimdi" ile "3 saat
    // sonrası" arasındaki farka bakarak WeatherService tarafından hesaplanıyor.
    // saatlik veri çok kısaysa (aşırı nadir) nil kalıp ok hiç gösterilmiyor
    let pressureTrend: WeatherTrend?
    let humidityTrend: WeatherTrend?

    // şu an gece mi gündüz mü, gündoğumu/günbatımı saatlerine bakarak anlıyorum.
    // arka plan rengi ve ikon (güneş mi ay mı) buna göre değişiyor
    var isNight: Bool {
        guard let sunrise, let sunset else { return false }
        let now = Date()
        return now < sunrise || now > sunset
    }

    // hava durumu koduna göre ekranda gösterilecek ikonun adını seçiyor.
    // gece olunca güneş yerine ay ikonlarına geçiyorum
    var systemIconName: String {
        WMOWeatherCode.systemIconName(for: conditionCode, isNight: isNight)
    }

    // ülkenin adını kullanıcının telefon diline göre çeviriyor, api sadece
    // "tr" gibi kısa bir kod veriyor ama ekranda "türkiye" yazmasını istiyorum
    var localizedCountryName: String {
        Locale.current.localizedString(forRegionCode: country) ?? country
    }

    // çiğ noktasını sıcaklık ve nemden hesaplıyorum, api bunu vermiyor ama
    // formülü biliyoruz (magnus-tetens formülü) o yüzden yeni istek atmaya gerek yok
    var dewPoint: Double {
        guard humidity > 0 else { return temperature }
        let b = 17.625
        let c = 243.04
        let gamma = (b * temperature) / (c + temperature) + log(Double(humidity) / 100)
        return (c * gamma) / (b - gamma)
    }

    // günbatımının ne kadar "güzel" olabileceğini tahmin eden basit bir skor.
    // hiçbir hava durumu servisi bunu doğrudan vermiyor ama gerçek bir
    // gözlemden yola çıkıyor: en canlı gün batımları GENELDE gökyüzü tamamen
    // açık değil de kısmen bulutluyken oluyor (bulutlar batan güneşin ışığını
    // turuncu/pembeye boyayan birer "tuval" gibi), hava ne kadar kuruysa
    // (düşük nem) renkler o kadar canlı çıkıyor, görüş mesafesi ne kadar
    // uzaksa hava o kadar duru demek. üç etkeni birleştirip 1-10 arası bir
    // skora çeviriyorum
    var sunsetQualityScore: Int {
        // %45 civarı bulutluluk ideal, 0 (tamamen açık) ve 100 (tamamen
        // kapalı) uçlara gittikçe puan düşüyor
        let cloudDistanceFromIdeal = abs(Double(cloudiness) - 45) / 45
        let cloudScore = max(0, 1 - cloudDistanceFromIdeal)

        let humidityScore = max(0, 1 - Double(humidity) / 100)
        let visibilityScore = min(1, Double(visibility) / 10_000)

        let combined = cloudScore * 0.5 + humidityScore * 0.3 + visibilityScore * 0.2
        return max(1, min(10, Int((combined * 10).rounded())))
    }

    var sunsetQualityLabel: String {
        switch sunsetQualityScore {
        case 9...10:
            return String(localized: "sunset.spectacular", defaultValue: "Muhteşem olabilir")
        case 7...8:
            return String(localized: "sunset.great", defaultValue: "Çok güzel olabilir")
        case 5...6:
            return String(localized: "sunset.decent", defaultValue: "Fena olmayabilir")
        default:
            return String(localized: "sunset.plain", defaultValue: "Sıradan olabilir")
        }
    }

    // o geceki ay evresi, sunset saatine göre hesaplanıyor (gündoğumu/günbatımı
    // arasındaki "gece" neredeyse hep günbatımından sonraki geceyi işaret eder)
    var moonPhase: MoonPhase {
        MoonPhase.phase(for: sunset ?? Date())
    }

    // "ne giymeli" önerisi: hissedilen sıcaklık, yağış ve rüzgara bakan kural
    // tabanlı kısa bir cümle. ekstra veri gerekmiyor, elimizdekiyle hesaplanıyor
    var outfitSuggestion: String {
        var parts: [String] = []

        switch feelsLike {
        case ..<0:
            parts.append(String(localized: "outfit.freezing", defaultValue: "kalın mont, bere ve eldiven şart"))
        case 0..<10:
            parts.append(String(localized: "outfit.cold", defaultValue: "kalın bir mont iyi olur"))
        case 10..<17:
            parts.append(String(localized: "outfit.mild", defaultValue: "ince bir ceket yeterli"))
        case 28...:
            parts.append(String(localized: "outfit.hot", defaultValue: "hafif ve ferah giyin"))
        default:
            break
        }

        if (300...321).contains(conditionCode) || (500...622).contains(conditionCode) {
            parts.append(String(localized: "outfit.umbrella", defaultValue: "şemsiyeni yanına al"))
        }

        if windSpeed >= 35 {
            parts.append(String(localized: "outfit.wind", defaultValue: "rüzgar kırıcı bir şey giy"))
        }

        guard !parts.isEmpty else {
            return String(localized: "outfit.pleasant", defaultValue: "Bugün özel bir hazırlığa gerek yok")
        }

        let sentence = parts.joined(separator: ", ")
        return sentence.prefix(1).capitalized + sentence.dropFirst()
    }

    // MARK: - detay kutularının altındaki kısa yorum etiketleri
    // her kutu tek başına çıplak bir sayı gösteriyordu ("%38", "1008 hPa"
    // gibi) — sayı doğru ama YORUMSUZ, ne kadar iyi/kötü olduğunu anlamak
    // için kullanıcının kendi bilgisine güvenmesi gerekiyordu. bunlar hiçbiri
    // yeni bir api isteği gerektirmiyor, elimizde zaten olan sayıyı standart
    // meteoroloji eşiklerine göre kısa bir sıfata çeviriyor

    var humidityComfortLabel: String {
        switch humidity {
        case ..<30: return String(localized: "humidity.dry", defaultValue: "Kuru")
        case 30..<60: return String(localized: "humidity.comfortable", defaultValue: "Rahat")
        case 60..<80: return String(localized: "humidity.humid", defaultValue: "Nemli")
        default: return String(localized: "humidity.very_humid", defaultValue: "Çok nemli")
        }
    }

    // hissedilen sıcaklığın gerçek sıcaklıktan ne kadar farklı olduğu, imzalı
    // bir sayı olarak ("+3°"/"-2°") — hero'nun altındaki tam cümle sadece
    // fark 2°'yi geçince görünüyor, bu rozet HER ZAMAN görünüyor
    var feelsLikeDeltaLabel: String {
        let delta = Int((feelsLike - temperature).rounded())
        if delta == 0 {
            return String(localized: "feels_like.same", defaultValue: "Gerçek sıcaklıkla aynı")
        }
        let format = delta > 0
            ? String(localized: "feels_like.warmer_format", defaultValue: "%d° daha sıcak")
            : String(localized: "feels_like.cooler_format", defaultValue: "%d° daha serin")
        return String(format: format, abs(delta))
    }

    var pressureLabel: String {
        switch pressure {
        case ..<1000: return String(localized: "pressure.low", defaultValue: "Alçak basınç")
        case 1000...1020: return String(localized: "pressure.normal", defaultValue: "Normal")
        default: return String(localized: "pressure.high", defaultValue: "Yüksek basınç")
        }
    }

    // visibility metre cinsinden geliyor, kutuda km'ye çevrilip gösteriliyor
    var visibilityLabel: String {
        switch visibility {
        case ..<1_000: return String(localized: "visibility.fog", defaultValue: "Sisli")
        case 1_000..<4_000: return String(localized: "visibility.limited", defaultValue: "Sınırlı görüş")
        case 4_000..<10_000: return String(localized: "visibility.good", defaultValue: "İyi görüş")
        default: return String(localized: "visibility.excellent", defaultValue: "Mükemmel görüş")
        }
    }

    var cloudinessLabel: String {
        switch cloudiness {
        case ..<20: return String(localized: "cloudiness.clear", defaultValue: "Açık gökyüzü")
        case 20..<50: return String(localized: "cloudiness.mostly_clear", defaultValue: "Az bulutlu")
        case 50..<80: return String(localized: "cloudiness.partly_cloudy", defaultValue: "Parçalı bulutlu")
        default: return String(localized: "cloudiness.overcast", defaultValue: "Kapalı")
        }
    }

    // çiğ noktası, standart meteorolojik "nem konforu" ölçeğine göre
    // yorumlanıyor — nem yüzdesinden daha güvenilir bir konfor göstergesi,
    // çünkü sıcaklığı da hesaba katıyor (magnus-tetens formülü zaten öyle).
    // bilerek "kuru/nemli" yerine "hafif ağır/ağır" gibi farklı kelimeler
    // kullanıyorum: örneğin çölde %22 bağıl nem (NEM kutusu "Kuru" der) ile
    // 16° çiğ noktası (mutlak nem yüksek) AYNI ANDA doğru olabiliyor — ikisi
    // farklı şeyi ölçüyor. iki kutu da "nemli/kuru" kelimesini kullanırsa
    // kullanıcıya çelişki gibi görünüyor, kelimeleri ayırınca bu kalkıyor
    var dewPointComfortLabel: String {
        switch dewPoint {
        case ..<10: return String(localized: "dew_point.dry", defaultValue: "Kuru")
        case 10..<16: return String(localized: "dew_point.comfortable", defaultValue: "Rahat")
        case 16..<19: return String(localized: "dew_point.slightly_humid", defaultValue: "Hafif ağır")
        case 19..<23: return String(localized: "dew_point.humid", defaultValue: "Ağır")
        default: return String(localized: "dew_point.oppressive", defaultValue: "Bunaltıcı")
        }
    }

    // ayın o an aydınlanmış yüzeyinin yüzdesi — evre ismiyle (mesela "Küçülen
    // Hilal") birlikte, "ne kadar" sorusuna da sayısal bir cevap veriyor
    var moonIlluminationPercent: Int {
        MoonPhase.illuminationPercent(for: sunset ?? Date())
    }
}

// MARK: - basınç/nem gibi kısa vadeli bir değerin yönü
// WeatherService bunu saatlik veriden hesaplıyor, detay kutuları da küçük
// bir ok ikonu olarak gösteriyor (bkz. Views/Components/WeatherDetailBox.swift)
enum WeatherTrend: Codable {
    case rising, falling, steady

    var systemImageName: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .steady: return "arrow.right"
        }
    }
}

// MARK: - günlük tahmin listesindeki tek bir gün
struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let minTemperature: Double
    let maxTemperature: Double
    let conditionCode: Int
    let pop: Double // o gün yağmur yağma olasılığı, 0 ile 1 arasında bir sayı

    // günlük tahmin satırındaki küçük ikon için
    var systemIconName: String {
        WMOWeatherCode.systemIconName(for: conditionCode)
    }
}

// MARK: - haftanın "dışarı çıkmak için en iyi günü" önerisi
// hiçbir servis bunu hazır vermiyor, elimizdeki 7 günlük tahminden kendimiz
// çıkarıyoruz: yağış olasılığı düşük VE hava açık/az bulutlu olan günler
// daha yüksek puan alıyor, en yükseği öneriliyor
extension Array where Element == DailyForecast {
    var bestOutdoorDay: DailyForecast? {
        self.max { outdoorScore(for: $0) < outdoorScore(for: $1) }
    }

    private func outdoorScore(for day: DailyForecast) -> Double {
        let popScore = 1 - day.pop

        let conditionScore: Double
        switch day.conditionCode {
        case 800...802: conditionScore = 1.0 // açık / az bulutlu
        case 803...804: conditionScore = 0.7 // parçalı / kapalı bulutlu
        case 300...321, 701...781: conditionScore = 0.4 // çise / sis
        case 500...531, 600...622: conditionScore = 0.2 // yağmur / kar
        default: conditionScore = 0.0 // fırtına ve benzeri
        }

        return popScore * 0.6 + conditionScore * 0.4
    }
}
