//
//  WeatherService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// openweather: sadece isim/ülke/koordinat
private nonisolated struct LocationIdentityResponse: Codable {
    let name: String
    let coord: Coord
    let sys: Sys

    struct Coord: Codable { let lat: Double; let lon: Double }
    struct Sys: Codable { let country: String? }
}

// open-meteo: anlık durum + saatlik + günlük tahmin, tek istekte
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
        let wind_direction_10m: Int?
        let wind_gusts_10m: Double?
    }

    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let pressure_msl: [Double]
        let relative_humidity_2m: [Int]
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

    let minutely_15: Minutely15?

    struct Minutely15: Codable {
        let precipitation: [Double]
    }
}

private nonisolated struct AirPollutionResponse: Codable {
    let list: [Item]
    struct Item: Codable {
        let main: Main
        struct Main: Codable { let aqi: Int }
    }
}

struct WeatherBundle: Sendable {
    let current: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

nonisolated protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for cityName: String) async throws -> WeatherBundle
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle
    func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality
}

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

// openweather: konum. open-meteo: hava durumu sayıları
nonisolated struct WeatherService: WeatherServiceProtocol {

    private let apiKey = Secrets.openWeatherAPIKey

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

    private func fetchWeather(identity: LocationIdentity) async throws -> WeatherBundle {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(identity.lat)&longitude=\(identity.lon)"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,pressure_msl,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
            + "&hourly=temperature_2m,pressure_msl,relative_humidity_2m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&minutely_15=precipitation&forecast_minutely_15=8"
            + "&timezone=auto&wind_speed_unit=kmh&forecast_days=7&forecast_hours=24"

        guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }

        let (data, _) = try await requestData(from: url)
        guard let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            throw WeatherError.decoding
        }

        // zaman metinleri şehrin kendi utc farkına göre çözülüyor
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
            precipitationNowcast: Self.nowcastMessage(from: decoded.minutely_15),
            pressureTrend: Self.trend(from: decoded.hourly.pressure_msl, threshold: 1),
            humidityTrend: Self.trend(from: decoded.hourly.relative_humidity_2m.map(Double.init), threshold: 3)
        )

        let hourly: [HourlyForecast] = (0..<decoded.hourly.time.count).compactMap { index in
            guard let date = dateTimeFormatter.date(from: decoded.hourly.time[index]) else { return nil }
            return HourlyForecast(
                time: date,
                temperature: decoded.hourly.temperature_2m[index]
            )
        }

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

    private func requestData(from url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(from: url)
        } catch {
            throw WeatherError.network
        }
    }

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

    private static func trend(from values: [Double], threshold: Double) -> WeatherTrend? {
        guard values.count > 3 else { return nil }
        let delta = values[3] - values[0]
        if delta > threshold { return .rising }
        if delta < -threshold { return .falling }
        return .steady
    }

    private static func formatter(dateFormat: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
