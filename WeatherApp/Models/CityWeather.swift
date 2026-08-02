//
//  CityWeather.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation
import SwiftUI

// MARK: - Şehir ve Hava Durumu Modeli (Şablonumuz)
struct CityWeather: Identifiable, Codable, Equatable {
    let id: Int // OpenWeather API'nin şehirlere verdiği sabit numara
    let name: String
    let country: String
    let temperature: Double
    
    let feelsLike: Double
    let pressure: Int
    let visibility: Int
    let cloudiness: Int
    
    // YENİ: Gündoğumu ve Günbatımı Saatleri
    let sunrise: Date?
    let sunset: Date?
    
    let conditionDescription: String
    let conditionCode: Int
    let humidity: Int
    let windSpeed: Double
    var isFavorite: Bool = false // Şehrin favori olup olmadığını tutacağız
    
    // UI (Arayüz) ekranda sıcaklığı doğrudan "29°" diye gösterebilsin diye hazırladığımız özellik
    var formattedTemperature: String {
        return "\(Int(temperature.rounded()))°"
    }
    
    // OpenWeather API'den gelen kod numarasına göre Apple'ın şık ikon adını veren sistem
    var systemIconName: String {
        switch conditionCode {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800:       return "sun.max.fill"
        case 801...804: return "cloud.fill"
        default:        return "cloud.sun.fill"
        }
    }
    
    // Hava durumuna (conditionCode) göre arka plan renklerini belirleyen sistem
    var backgroundColors: [Color] {
        switch conditionCode {
        case 200...232: // Fırtına
            return [Color.gray.opacity(0.9), Color.black.opacity(0.8)]
        case 300...531: // Yağmur
            return [Color.blue.opacity(0.6), Color.gray.opacity(0.8)]
        case 600...622: // Kar
            return [Color.blue.opacity(0.4), Color.white.opacity(0.5)]
        case 701...781: // Sis / Pus
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.8)]
        case 800:       // Açık / Güneşli
            return [Color.blue.opacity(0.6), Color.orange.opacity(0.5)]
        case 801...804: // Bulutlu
            return [Color.blue.opacity(0.5), Color.gray.opacity(0.6)]
        default:
            return [Color.blue.opacity(0.7), Color.purple.opacity(0.6)]
        }
    }
}

// MARK: - 5 Günlük Tahmin Listesi İçin Yeni Model
struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let minTemperature: Double
    let maxTemperature: Double
    let conditionCode: Int
    
    // Günlük listedeki hava durumu ikonları için
    var systemIconName: String {
        switch conditionCode {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800:       return "sun.max.fill"
        case 801...804: return "cloud.fill"
        default:        return "cloud.sun.fill"
        }
    }
}
