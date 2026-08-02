//
//  WeatherServiceDelegate.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// 1. SÖZLEŞME: Temsilcinin (Yani Patronun/Ekranın) Uyacağı Kurallar
protocol WeatherServiceDelegate: AnyObject {
    // Kural 1: Eğer asistan hava durumunu başarıyla çekerse bu fonksiyonu tetikleyip veriyi verecek
    func weatherServiceDidFetchData(_ service: WeatherServiceProtocol, didUpdateWeather weather: CityWeather)
    
    // GÜNCELLENDİ: Artık hem saatlik hem de 5 günlük tahminleri aynı anda iletiyoruz
    func weatherServiceDidFetchForecast(_ service: WeatherServiceProtocol, hourly: [HourlyForecast], daily: [DailyForecast])
    
    // Kural 2: Eğer internet koparsa veya hata olursa bu fonksiyonu tetikleyip hatayı söyleyecek
    func weatherServiceDidFail(_ service: WeatherServiceProtocol, withError error: Error)
}

// 2. SÖZLEŞME: Asistanın (Yani Ağ Servisinin) Uyacağı Kurallar
protocol WeatherServiceProtocol {
    // Her servisin haber vereceği bir patronu (delegate) olmak zorundadır!
    var delegate: WeatherServiceDelegate? { get set }
    
    // Her servis internetten şehir adına göre hava durumu çekebilmelidir!
    func fetchWeather(for cityName: String) async
    
    // Her servis tahmin verilerini de çekebilmelidir!
    func fetchForecast(for cityName: String) async
}
