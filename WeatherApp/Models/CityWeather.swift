//
//  CityWeather.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

struct CityWeather: Codable, Equatable {
    var name: String // applying(to:) sonradan üzerine yazabiliyor
    let country: String
    let temperature: Double

    let feelsLike: Double
    let pressure: Int
    let visibility: Int
    let cloudiness: Int

    let sunrise: Date?
    let sunset: Date?

    let conditionDescription: String
    let conditionCode: Int
    let humidity: Int
    let windSpeed: Double
    let windDeg: Int?
    let windGust: Double?

    let tempMin: Double
    let tempMax: Double

    let lat: Double
    let lon: Double
    let timezoneOffsetSeconds: Int
    let precipitationNowcast: String?

    let pressureTrend: WeatherTrend?
    let humidityTrend: WeatherTrend?

    var isNight: Bool {
        guard let sunrise, let sunset else { return false }
        let now = Date()
        return now < sunrise || now > sunset
    }

    var systemIconName: String {
        WMOWeatherCode.systemIconName(for: conditionCode, isNight: isNight)
    }

    var localizedCountryName: String {
        Locale.current.localizedString(forRegionCode: country) ?? country
    }

    // magnus-tetens yaklaşıklığı
    var dewPoint: Double {
        guard humidity > 0 else { return temperature }
        let b = 17.625
        let c = 243.04
        let gamma = (b * temperature) / (c + temperature) + log(Double(humidity) / 100)
        return (c * gamma) / (b - gamma)
    }

    // günbatımı güzellik tahmini: %45 civarı bulutluluk ideal, düşük nem ve
    // yüksek görüş de puanı artırıyor
    var sunsetQualityScore: Int {
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

    var moonPhase: MoonPhase {
        MoonPhase.phase(for: sunset ?? Date())
    }

    // "ne giymeli" önerisi: hissedilen sıcaklık, yağış ve rüzgara bakan
    // kural tabanlı kısa bir cümle
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

    var humidityComfortLabel: String {
        switch humidity {
        case ..<30: return String(localized: "humidity.dry", defaultValue: "Kuru")
        case 30..<60: return String(localized: "humidity.comfortable", defaultValue: "Rahat")
        case 60..<80: return String(localized: "humidity.humid", defaultValue: "Nemli")
        default: return String(localized: "humidity.very_humid", defaultValue: "Çok nemli")
        }
    }

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

    var dewPointComfortLabel: String {
        switch dewPoint {
        case ..<10: return String(localized: "dew_point.dry", defaultValue: "Kuru")
        case 10..<16: return String(localized: "dew_point.comfortable", defaultValue: "Rahat")
        case 16..<19: return String(localized: "dew_point.slightly_humid", defaultValue: "Hafif ağır")
        case 19..<23: return String(localized: "dew_point.humid", defaultValue: "Ağır")
        default: return String(localized: "dew_point.oppressive", defaultValue: "Bunaltıcı")
        }
    }

    var moonIlluminationPercent: Int {
        MoonPhase.illuminationPercent(for: sunset ?? Date())
    }
}

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

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let minTemperature: Double
    let maxTemperature: Double
    let conditionCode: Int
    let pop: Double

    var systemIconName: String {
        WMOWeatherCode.systemIconName(for: conditionCode)
    }
}

// haftanın "dışarı çıkmak için en iyi günü" önerisi
extension Array where Element == DailyForecast {
    var bestOutdoorDay: DailyForecast? {
        self.max { outdoorScore(for: $0) < outdoorScore(for: $1) }
    }

    private func outdoorScore(for day: DailyForecast) -> Double {
        let popScore = 1 - day.pop

        let conditionScore: Double
        switch day.conditionCode {
        case 800...802: conditionScore = 1.0
        case 803...804: conditionScore = 0.7
        case 300...321, 701...781: conditionScore = 0.4
        case 500...531, 600...622: conditionScore = 0.2
        default: conditionScore = 0.0
        }

        return popScore * 0.6 + conditionScore * 0.4
    }
}
