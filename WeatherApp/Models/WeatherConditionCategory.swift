//
//  WeatherConditionCategory.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - filtrede seçilebilen kaba hava durumu kategorileri
// diğer yerlerdeki ince ayrımlardan (drizzle, rain, storm gibi) bilerek daha
// basit tutuyorum, çünkü filtre ekranında kullanıcıya bu kadar ince seçenek
// sunmak kafa karıştırır. sadece filtre özelliği için kullanılıyor
enum WeatherConditionCategory: String, CaseIterable, Identifiable {
    case clear
    case cloudy
    case rain
    case storm
    case snow
    case fog

    var id: String { rawValue }

    static func category(forConditionCode conditionCode: Int) -> WeatherConditionCategory {
        switch conditionCode {
        case 200...232: return .storm
        case 300...531: return .rain
        case 600...622: return .snow
        case 701...781: return .fog
        case 800:       return .clear
        case 801...804: return .cloudy
        default:        return .clear
        }
    }

    var label: String {
        switch self {
        case .clear:  return String(localized: "condition.clear", defaultValue: "Açık")
        case .cloudy: return String(localized: "condition.cloudy", defaultValue: "Bulutlu")
        case .rain:   return String(localized: "condition.rain", defaultValue: "Yağmurlu")
        case .storm:  return String(localized: "condition.storm", defaultValue: "Fırtınalı")
        case .snow:   return String(localized: "condition.snow", defaultValue: "Karlı")
        case .fog:    return String(localized: "condition.fog", defaultValue: "Sisli")
        }
    }

    var icon: String {
        switch self {
        case .clear:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain:   return "cloud.rain.fill"
        case .storm:  return "cloud.bolt.rain.fill"
        case .snow:   return "cloud.snow.fill"
        case .fog:    return "cloud.fog.fill"
        }
    }
}

// MARK: - favori listesini filtreleme
// hem hava durumu kategorisine hem sıcaklık aralığına göre filtreliyorum.
// sıcaklığı her zaman celsius olarak tutuyorum, kullanıcının seçtiği birime
// sadece ekranda gösterirken çeviriyorum, uygulamanın her yerinde yaptığım gibi
struct WeatherFilter {
    var categories: Set<WeatherConditionCategory> = []
    var minTemperatureCelsius: Double = -30
    var maxTemperatureCelsius: Double = 50

    var isActive: Bool {
        !categories.isEmpty || minTemperatureCelsius > -30 || maxTemperatureCelsius < 50
    }

    // veri henüz gelmediyse (favori satırı hâlâ yükleniyorsa) ve filtre
    // aktifse, o satırı belirsiz göstermek yerine listeden gizliyorum. filtre
    // kapalıyken zaten her satır gösteriliyor
    func matches(_ weather: CityWeather?) -> Bool {
        guard isActive else { return true }
        guard let weather else { return false }

        if !categories.isEmpty {
            let category = WeatherConditionCategory.category(forConditionCode: weather.conditionCode)
            if !categories.contains(category) { return false }
        }

        if weather.temperature < minTemperatureCelsius || weather.temperature > maxTemperatureCelsius {
            return false
        }

        return true
    }
}
