//
//  WMOWeatherCode.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import Foundation

// wmo kodunu openweather'ın eski aralık koduna çevirir
nonisolated enum WMOWeatherCode {

    static func legacyConditionCode(for wmoCode: Int) -> Int {
        switch wmoCode {
        case 0:  return 800 // açık
        case 1:  return 801 // az bulutlu
        case 2:  return 802 // parçalı bulutlu
        case 3:  return 804 // kapalı
        case 45, 48: return 741 // sis
        case 51: return 300 // hafif çise
        case 53: return 301 // orta çise
        case 55: return 302 // yoğun çise
        case 56: return 311 // hafif dondurucu çise
        case 57: return 312 // yoğun dondurucu çise
        case 61: return 500 // hafif yağmur
        case 63: return 501 // orta yağmur
        case 65: return 502 // kuvvetli yağmur
        case 66, 67: return 511 // dondurucu yağmur
        case 71: return 600 // hafif kar
        case 73: return 601 // orta kar
        case 75: return 602 // kuvvetli kar
        case 77: return 612 // kar taneleri
        case 80: return 520 // hafif sağanak
        case 81: return 521 // orta sağanak
        case 82: return 522 // şiddetli sağanak
        case 85: return 621 // hafif kar sağanağı
        case 86: return 622 // kuvvetli kar sağanağı
        case 95: return 200 // gök gürültülü fırtına
        case 96, 99: return 202 // dolulu fırtına
        default: return 800
        }
    }

    static func localizedDescription(for wmoCode: Int) -> String {
        switch wmoCode {
        case 0:  return String(localized: "wmo.clear", defaultValue: "Açık")
        case 1:  return String(localized: "wmo.mostly_clear", defaultValue: "Az Bulutlu")
        case 2:  return String(localized: "wmo.partly_cloudy", defaultValue: "Parçalı Bulutlu")
        case 3:  return String(localized: "wmo.overcast", defaultValue: "Kapalı")
        case 45, 48: return String(localized: "wmo.fog", defaultValue: "Sisli")
        case 51, 53, 55: return String(localized: "wmo.drizzle", defaultValue: "Çiseleyen Yağmur")
        case 56, 57: return String(localized: "wmo.freezing_drizzle", defaultValue: "Dondurucu Çise")
        case 61, 63, 65: return String(localized: "wmo.rain", defaultValue: "Yağmurlu")
        case 66, 67: return String(localized: "wmo.freezing_rain", defaultValue: "Dondurucu Yağmur")
        case 71, 73, 75: return String(localized: "wmo.snow", defaultValue: "Kar Yağışlı")
        case 77: return String(localized: "wmo.snow_grains", defaultValue: "Kar Taneleri")
        case 80, 81, 82: return String(localized: "wmo.rain_showers", defaultValue: "Sağanak Yağmur")
        case 85, 86: return String(localized: "wmo.snow_showers", defaultValue: "Kar Sağanağı")
        case 95: return String(localized: "wmo.thunderstorm", defaultValue: "Gök Gürültülü Fırtına")
        case 96, 99: return String(localized: "wmo.thunderstorm_hail", defaultValue: "Dolu ile Fırtına")
        default: return String(localized: "wmo.unknown", defaultValue: "Bilinmiyor")
        }
    }

    static func systemIconName(for legacyConditionCode: Int, isNight: Bool = false) -> String {
        switch legacyConditionCode {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800:       return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 801...804: return isNight ? "cloud.moon.fill" : "cloud.fill"
        default:        return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        }
    }
}
