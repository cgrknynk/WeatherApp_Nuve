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
