//
//  WeatherService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - "neresi" sorusunun cevabı
// openweather'ın ücretsiz servisini artık sadece isim/ülke/koordinat bulmak
// için kullanıyorum. open-meteo bir şehir veritabanı değil, sadece hava
// durumu hesaplıyor, isimden koordinat bulamıyor. asıl sıcaklık verisi
// aşağıdaki open-meteo modelinden geliyor. nonisolated yazmamın sebebi,
// proje genelinde her şey mainactor'a bağlı ama bu decode işlemi ana
// thread'e sıkışmasın istiyorum
private nonisolated struct LocationIdentityResponse: Codable {
    let name: String
    let coord: Coord
    let sys: Sys

    struct Coord: Codable { let lat: Double; let lon: Double }
    // ülke kodu her zaman gelmiyor - antarktika gibi resmi bir ülkesi olmayan
    // yerlerde bu alan api cevabında hiç bulunmuyor, o yüzden opsiyonel
    struct Sys: Codable { let country: String? }
}

// MARK: - "ne durumda" sorusunun cevabı
// tek bir istekte anlık durumu, saatlik ve günlük tahmini birlikte veriyor.
// günlük en düşük/en yüksek değerleri openweather'daki gibi tahmini değil,
// o günün tüm saatlik verisinden gerçekten hesaplanıyor, küçük şehirlerde
// bile güvenilir (detaylı hikaye Kod-Rehberi.md'de var)
private nonisolated struct OpenMeteoResponse: Codable {
    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Codable {
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let apparent_temperature: Double
        let weather_code: Int
        let cloud_cover: Int
        let pressure_msl: Double
        let visibility: Double
        let wind_speed_10m: Double
        let wind_direction_10m: Int
        let wind_gusts_10m: Double?
    }

    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
    }

    struct Daily: Codable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Double]
        let sunrise: [String]
        let sunset: [String]
    }

    // "yağış birazdan başlıyor" uyarısı için 15 dakikalık çözünürlükte veri.
    // opsiyonel çünkü çok nadir istisnai bir bölgede open-meteo bunu hiç
    // vermeyebilir, o durumda uyarıyı sessizce hiç göstermiyoruz
    let minutely_15: Minutely15?

    struct Minutely15: Codable {
        let precipitation: [Double]
    }
}

// MARK: - hava kalitesi cevabı
private nonisolated struct AirPollutionResponse: Codable {
    let list: [Item]
    struct Item: Codable {
        let main: Main
        struct Main: Codable { let aqi: Int }
    }
}

// MARK: - hava durumu + tahmin paketi
// open-meteo tek istekte anlık durumu, saatlik ve günlük tahmini birlikte
// verdiği için viewmodel artık iki ayrı istek atmıyor, tek çağrı yetiyor
struct WeatherBundle: Sendable {
    let current: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

// MARK: - servisin sözleşmesi
// eskiden bir delegate üzerinden haber veriyordu, servis zaten async/await
// kullandığı için buna gerek kalmadı. artık direkt sonucu döndürüyor ya da
// hata fırlatıyor, viewmodel tarafında tek bir do/catch yeterli
nonisolated protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for cityName: String) async throws -> WeatherBundle
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle
    func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality
}

// MARK: - konum üzerinden ortak çağrı (WeatherLocation)
// isim mi koordinat mı diye her yerde tekrar tekrar yazmamak için bu
// dallanmayı protokolün kendisine ekleyip tek yerden paylaşıyorum
extension WeatherServiceProtocol {
    func fetchWeather(at location: WeatherLocation) async throws -> WeatherBundle {
        switch location {
        case .name(let name):
            return try await fetchWeather(for: name)
        case .coordinate(let lat, let lon, _):
            return try await fetchWeather(lat: lat, lon: lon)
        }
    }
}

// MARK: - asıl ağ servisi
// hiçbir değişken durumu yok (sadece sabit bir api anahtarı tutuyor), o yüzden
// class değil struct kullandım, her yerde güvenle yeniden yaratılabiliyor.
// nonisolated koydum çünkü proje genelinde her şey mainactor'a bağlı ama ağ
// isteği ana thread'i kilitlemesin istiyorum
//
// iki farklı sağlayıcı kullanıyorum, bilerek: openweather'ın ücretsiz servisi
// küçük şehirlerde en düşük/en yüksek sıcaklığı güvenilir vermiyor, kendi
// belgelerinde bile bunun "o anki ölçüme yakın bir tahmin" olduğunu yazıyorlar.
// open-meteo ise günlük değerleri o günün tüm saatlik verisinden hesaplıyor,
// hem küçük şehirlerde de tutarlı hem tamamen ücretsiz. ama open-meteo şehir
// arama yapamıyor, sadece koordinat kabul ediyor. o yüzden isim/koordinat
// bulma işini openweather'da bırakıp asıl sıcaklık verisini open-meteo'dan
// çekiyorum
nonisolated struct WeatherService: WeatherServiceProtocol {

    private let apiKey = Secrets.openWeatherAPIKey

    // MARK: - isimle ya da koordinatla hava durumu çekme
    func fetchWeather(for cityName: String) async throws -> WeatherBundle {
        guard let encodedCityName = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw WeatherError.invalidResponse
        }
        let identity = try await fetchLocationIdentity(
            urlString: "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCityName)&appid=\(apiKey)"
        )
        return try await fetchWeather(identity: identity)
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle {
        let identity = try await fetchLocationIdentity(
            urlString: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
        )
        return try await fetchWeather(identity: identity)
    }

    // MARK: - konum kimliğini bulma
    private struct LocationIdentity {
        let name: String
        let country: String
        let lat: Double
        let lon: Double
    }

    private func fetchLocationIdentity(urlString: String) async throws -> LocationIdentity {
        guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }

        let (data, response) = try await requestData(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw WeatherError.cityNotFound
        }

        guard let decoded = try? JSONDecoder().decode(LocationIdentityResponse.self, from: data) else {
            throw WeatherError.decoding
        }

        return LocationIdentity(
            name: decoded.name,
            country: decoded.sys.country ?? "",
            lat: decoded.coord.lat,
            lon: decoded.coord.lon
        )
    }

    // MARK: - open-meteo'dan asıl sıcaklık verisini çekme
    private func fetchWeather(identity: LocationIdentity) async throws -> WeatherBundle {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(identity.lat)&longitude=\(identity.lon)"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,pressure_msl,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
            + "&hourly=temperature_2m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&minutely_15=precipitation&forecast_minutely_15=8"
            + "&timezone=auto&wind_speed_unit=kmh&forecast_days=7&forecast_hours=24"

        guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }

        let (data, _) = try await requestData(from: url)
        guard let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            throw WeatherError.decoding
        }

        // open-meteo'nun zaman metinleri (mesela "2026-08-03T14:00") zaten o
        // şehrin kendi yerel saatinde geliyor, o yüzden çözerken de şehrin
        // kendi utc farkını kullanıyorum, telefonun saat dilimini değil. yoksa
        // yurt dışı bir şehre bakarken saatler kayardı
        let timeZone = TimeZone(secondsFromGMT: decoded.utc_offset_seconds) ?? .current
        let dateTimeFormatter = Self.formatter(dateFormat: "yyyy-MM-dd'T'HH:mm", timeZone: timeZone)
        let dayFormatter = Self.formatter(dateFormat: "yyyy-MM-dd", timeZone: timeZone)

        let conditionCode = WMOWeatherCode.legacyConditionCode(for: decoded.current.weather_code)

        let current = CityWeather(
            name: identity.name,
            country: identity.country,
            temperature: decoded.current.temperature_2m,
            feelsLike: decoded.current.apparent_temperature,
            pressure: Int(decoded.current.pressure_msl.rounded()),
            visibility: Int(decoded.current.visibility),
            cloudiness: decoded.current.cloud_cover,
            sunrise: decoded.daily.sunrise.first.flatMap(dateTimeFormatter.date(from:)),
            sunset: decoded.daily.sunset.first.flatMap(dateTimeFormatter.date(from:)),
            conditionDescription: WMOWeatherCode.localizedDescription(for: decoded.current.weather_code),
            conditionCode: conditionCode,
            humidity: decoded.current.relative_humidity_2m,
            windSpeed: decoded.current.wind_speed_10m,
            windDeg: decoded.current.wind_direction_10m,
            windGust: decoded.current.wind_gusts_10m,
            tempMin: decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m,
            tempMax: decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m,
            lat: identity.lat,
            lon: identity.lon,
            timezoneOffsetSeconds: decoded.utc_offset_seconds,
            precipitationNowcast: Self.nowcastMessage(from: decoded.minutely_15)
        )

        // forecast_hours=24 dediğim için open-meteo şu anki saatten itibaren
        // tam 24 saatlik veri veriyor, elle "ilk 8 tanesini al" gibi bir
        // kırpmaya gerek kalmadı
        let hourly: [HourlyForecast] = (0..<decoded.hourly.time.count).compactMap { index in
            guard let date = dateTimeFormatter.date(from: decoded.hourly.time[index]) else { return nil }
            return HourlyForecast(
                time: date,
                temperature: decoded.hourly.temperature_2m[index]
            )
        }

        // open-meteo günleri zaten şehrin kendi takvimine göre gruplayıp
        // veriyor, elle gün bölme mantığına gerek kalmadı
        let daily: [DailyForecast] = (0..<decoded.daily.time.count).compactMap { index in
            guard let date = dayFormatter.date(from: decoded.daily.time[index]) else { return nil }
            return DailyForecast(
                date: date,
                minTemperature: decoded.daily.temperature_2m_min[index],
                maxTemperature: decoded.daily.temperature_2m_max[index],
                conditionCode: WMOWeatherCode.legacyConditionCode(for: decoded.daily.weather_code[index]),
                pop: decoded.daily.precipitation_probability_max[index] / 100
            )
        }

        return WeatherBundle(current: current, hourly: hourly, daily: daily)
    }

    // MARK: - hava kalitesini çekme
    // bu ayrı openweather servisi zaten sorunsuz çalışıyordu, sadece sıcaklık
    // verisini değiştirdim, hava kalitesine hiç dokunmadım
    func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality {
        let urlString = "https://api.openweathermap.org/data/2.5/air_pollution?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
        guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }

        let (data, _) = try await requestData(from: url)
        guard let decoded = try? JSONDecoder().decode(AirPollutionResponse.self, from: data),
              let firstReading = decoded.list.first else {
            throw WeatherError.decoding
        }

        return AirQuality(aqi: firstReading.main.aqi)
    }

    // MARK: - ortak ağ isteği
    // üç fonksiyonun da tekrar tekrar yazacağı urlsession çağrısını burada
    // topladım, bağlantı hatasını da tek bir WeatherError'a çeviriyorum
    private func requestData(from url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(from: url)
        } catch {
            throw WeatherError.network
        }
    }

    // MARK: - open-meteo'nun zaman metinlerini çözme
    // "2026-08-03T14:00" gibi bir metni, şehrin kendi utc farkına göre gerçek
    // bir Date'e çeviriyorum. en_US_POSIX kullanıyorum çünkü sabit formatlı
    // tarihleri okurken telefonun bölge ayarından etkilenmek istemiyorum.
    // hem saatlik hem günlük zaman metinleri aynı mantıkla çözülüyor, tek
    // farkları format string'i, o yüzden tek fonksiyon yeterli
    // MARK: - "yağış birazdan başlıyor" mesajını üretme
    // 15 dakikalık dilimlerdeki yağış miktarına bakıp, önümüzdeki 2 saat
    // içinde (8 dilim) yağışın ne zaman başlayacağını/duracağını tahmin
    // ediyorum. eşik değeri (0.1mm) open-meteo'nun kendi belgelerinde
    // "hissedilir yağış" için önerdiği kabaca sınır
    private static func nowcastMessage(from minutely: OpenMeteoResponse.Minutely15?) -> String? {
        guard let precipitation = minutely?.precipitation, !precipitation.isEmpty else { return nil }
        let threshold = 0.1

        if precipitation[0] > threshold {
            if let stopIndex = precipitation.firstIndex(where: { $0 <= threshold }) {
                return String(
                    format: String(localized: "nowcast.stopping_format", defaultValue: "Yağış yaklaşık %d dakika içinde dinebilir"),
                    stopIndex * 15
                )
            }
            return String(localized: "nowcast.ongoing", defaultValue: "Şu anda yağış var")
        }

        if let startIndex = precipitation.firstIndex(where: { $0 > threshold }) {
            return String(
                format: String(localized: "nowcast.starting_format", defaultValue: "Yağış yaklaşık %d dakika içinde başlayabilir"),
                startIndex * 15
            )
        }

        return String(localized: "nowcast.clear", defaultValue: "Önümüzdeki 2 saat içinde yağış beklenmiyor")
    }

    private static func formatter(dateFormat: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
