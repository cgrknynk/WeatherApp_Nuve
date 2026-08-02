//
//  WeatherService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - Mevcut Hava Durumu DTO'su
private struct OpenWeatherResponse: Codable {
    let id: Int
    let name: String
    let sys: Sys
    let main: Main
    let weather: [WeatherDetail]
    let wind: Wind
    let visibility: Int
    let clouds: Clouds
    
    struct Sys: Codable {
        let country: String
        let sunrise: TimeInterval?
        let sunset: TimeInterval?
    }
    struct Main: Codable {
        let temp: Double
        let humidity: Int
        let feels_like: Double
        let pressure: Int
    }
    struct WeatherDetail: Codable { let description: String; let id: Int }
    struct Wind: Codable { let speed: Double }
    struct Clouds: Codable { let all: Int }
}

// MARK: - 5 Günlük / 3 Saatlik Tahmin DTO'su
private struct OpenWeatherForecastResponse: Codable {
    let list: [ForecastItem]
    
    struct ForecastItem: Codable {
        let dt: TimeInterval // Tarih/Saat (Unix Timestamp)
        let main: Main
        let weather: [WeatherDetail]
        
        struct Main: Codable {
            let temp: Double
            let temp_min: Double?
            let temp_max: Double?
        }
        struct WeatherDetail: Codable { let id: Int }
    }
}

// MARK: - Asıl Ağ Servisimiz
class WeatherService: WeatherServiceProtocol {
    
    weak var delegate: WeatherServiceDelegate?
    private let apiKey = "eff32b3ac02ea2adf9abcb7f29533d4a"
    
    // MARK: - Mevcut Hava Durumunu Çeken Fonksiyon
    func fetchWeather(for cityName: String) async {
        
        guard let encodedCityName = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCityName)&appid=\(apiKey)&units=metric&lang=tr"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedData = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            
            // DÜZELTİLDİ: Parametre sıralaması CityWeather modeliyle tamamen uyumlu hale getirildi
            let cityWeather = CityWeather(
                id: decodedData.id,
                name: decodedData.name,
                country: decodedData.sys.country,
                temperature: decodedData.main.temp,
                feelsLike: decodedData.main.feels_like,
                pressure: decodedData.main.pressure,
                visibility: decodedData.visibility,
                cloudiness: decodedData.clouds.all,
                sunrise: decodedData.sys.sunrise.map { Date(timeIntervalSince1970: $0) },
                sunset: decodedData.sys.sunset.map { Date(timeIntervalSince1970: $0) },
                conditionDescription: decodedData.weather.first?.description ?? "Bilinmiyor",
                conditionCode: decodedData.weather.first?.id ?? 800,
                humidity: decodedData.main.humidity,
                windSpeed: decodedData.wind.speed
            )
            
            DispatchQueue.main.async {
                self.delegate?.weatherServiceDidFetchData(self, didUpdateWeather: cityWeather)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.delegate?.weatherServiceDidFail(self, withError: error)
            }
        }
    }
    
    // MARK: - Saatlik ve Günlük Tahmin Verilerini Çeken Fonksiyon
    func fetchForecast(for cityName: String) async {
        
        guard let encodedCityName = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?q=\(encodedCityName)&appid=\(apiKey)&units=metric&lang=tr"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedData = try JSONDecoder().decode(OpenWeatherForecastResponse.self, from: data)
            
            // 1. İŞLEM: Yalnızca ilk 24 saati alıp Saatlik Model'e çeviriyoruz
            let forecastItems = Array(decodedData.list.prefix(8))
            let hourlyForecast = forecastItems.map { item in
                HourlyForecast(
                    time: Date(timeIntervalSince1970: item.dt),
                    temperature: item.main.temp
                )
            }
            
            // 2. İŞLEM: Tüm 40 veriyi alıp günlere göre grupluyoruz (5 Günlük Liste İçin)
            let calendar = Calendar.current
            var dailyForecasts: [DailyForecast] = []
            
            let groupedByDay = Dictionary(grouping: decodedData.list) { item -> Date in
                let date = Date(timeIntervalSince1970: item.dt)
                return calendar.startOfDay(for: date)
            }
            
            let sortedDays = groupedByDay.keys.sorted()
            
            for day in sortedDays {
                guard let itemsForDay = groupedByDay[day] else { continue }
                
                let minTemp = itemsForDay.map { $0.main.temp_min ?? $0.main.temp }.min() ?? 0
                let maxTemp = itemsForDay.map { $0.main.temp_max ?? $0.main.temp }.max() ?? 0
                let conditionCode = itemsForDay.first?.weather.first?.id ?? 800
                
                dailyForecasts.append(DailyForecast(
                    date: day,
                    minTemperature: minTemp,
                    maxTemperature: maxTemp,
                    conditionCode: conditionCode
                ))
            }
            
            DispatchQueue.main.async {
                self.delegate?.weatherServiceDidFetchForecast(self, hourly: hourlyForecast, daily: dailyForecasts)
            }
            
        } catch {
            print("Tahmin verisi çekilirken hata oluştu: \(error)")
        }
    }
}
