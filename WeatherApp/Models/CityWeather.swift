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
    let conditionCode: Int // ekrandaki ikonu ve arka plan rengini bu kod belirliyor
    // api bazen aynı anda birden fazla hava durumu döndürüyor, mesela kar+sis gibi.
    // birinci eleman zaten conditionCode ile aynı, geri kalanları arka plandaki
    // parçacık efektleri için kullanıyorum ki ikisi de aynı anda görünebilsin
    let conditionCodes: [Int]
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
