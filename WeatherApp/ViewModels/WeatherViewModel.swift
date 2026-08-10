import Foundation
import Combine

struct HourlyForecast {
    let time: Date
    let temperature: Double
}

enum WeatherViewState {
    case idle
    case loading
    case success(CityWeather)
    case error(String)
}

enum TemperatureUnit: String {
    case celsius
    case fahrenheit

    func format(_ celsius: Double) -> String {
        switch self {
        case .celsius:
            return "\(Int(celsius.rounded()))°"
        case .fahrenheit:
            let fahrenheit = celsius * 9 / 5 + 32
            return "\(Int(fahrenheit.rounded()))°"
        }
    }
}

enum WindSpeedUnit: String {
    case kilometersPerHour
    case milesPerHour

    func format(_ kmh: Double) -> String {
        switch self {
        case .kilometersPerHour:
            return String(format: String(localized: "wind.speed_kmh_format", defaultValue: "%.0f km/s"), kmh)
        case .milesPerHour:
            let mph = kmh * 0.621371
            return String(format: String(localized: "wind.speed_mph_format", defaultValue: "%.0f mph"), mph)
        }
    }
}

@MainActor
final class WeatherViewModel: ObservableObject {

    @Published private(set) var state: WeatherViewState = .idle
    @Published private(set) var hourlyForecast: [HourlyForecast] = []
    @Published private(set) var dailyForecast: [DailyForecast] = []
    @Published private(set) var airQuality: AirQuality?
    @Published private(set) var lastUpdated: Date?

    @Published var savedCities: [FavoriteCity] = [] {
        didSet { persistSavedCities() }
    }

    @Published private(set) var favoriteSnapshots: [String: CityWeather] = [:] {
        didSet { persistFavoriteSnapshots() }
    }

    @Published var preferredUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(preferredUnit.rawValue, forKey: "PreferredUnitKey") }
    }

    @Published var preferredWindUnit: WindSpeedUnit {
        didSet { UserDefaults.standard.set(preferredWindUnit.rawValue, forKey: "PreferredWindUnitKey") }
    }

    private let service: any WeatherServiceProtocol
    private var fetchTask: Task<Void, Never>?

    init(service: any WeatherServiceProtocol = WeatherService()) {
        self.service = service
        self.savedCities = Self.loadSavedCities()
        self.preferredUnit = TemperatureUnit(
            rawValue: UserDefaults.standard.string(forKey: "PreferredUnitKey") ?? ""
        ) ?? .celsius
        self.preferredWindUnit = WindSpeedUnit(
            rawValue: UserDefaults.standard.string(forKey: "PreferredWindUnitKey") ?? ""
        ) ?? .kilometersPerHour
        self.favoriteSnapshots = Self.loadFavoriteSnapshots()
    }

    func fetchWeather(for location: WeatherLocation) {
        fetchTask?.cancel() // eski isteğin cevabı yeni ekranın üzerine yazmasın

        state = .loading
        hourlyForecast = []
        dailyForecast = []
        airQuality = nil

        fetchTask = Task {
            do {
                let bundle = try await service.fetchWeather(at: location)
                guard !Task.isCancelled else { return }

                let weather = location.applying(to: bundle.current)
                hourlyForecast = bundle.hourly
                dailyForecast = bundle.daily
                state = .success(weather)
                lastUpdated = .now

                recordFreshSnapshot(weather)

                airQuality = try? await service.fetchAirQuality(lat: weather.lat, lon: weather.lon)
            } catch is CancellationError {
                // iptal edilen isteğin hatası gösterilmez
            } catch {
                guard !Task.isCancelled else { return }
                state = .error((error as? WeatherError)?.errorDescription ?? "Beklenmedik bir hata oluştu.")
            }
        }
    }

    func refreshFavoriteSnapshots() {
        for favorite in savedCities {
            Task {
                if let bundle = try? await service.fetchWeather(at: favorite.location) {
                    favoriteSnapshots[normalized(favorite.name)] = favorite.location.applying(to: bundle.current)
                }
            }
        }
    }

    func toggleFavorite(name: String, weather: CityWeather?) {
        if isFavorite(name) {
            savedCities.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            favoriteSnapshots.removeValue(forKey: normalized(name))
        } else if let weather, weather.name.caseInsensitiveCompare(name) == .orderedSame {
            savedCities.append(FavoriteCity(name: weather.name, lat: weather.lat, lon: weather.lon))
            favoriteSnapshots[normalized(weather.name)] = weather
        }
    }

    func isFavorite(_ city: String) -> Bool {
        savedCities.contains { $0.name.caseInsensitiveCompare(city) == .orderedSame }
    }

    func updateFavorite(id: String, nickname: String?, accentColorName: String?) {
        guard let index = savedCities.firstIndex(where: { $0.id == id }) else { return }
        savedCities[index].nickname = nickname
        savedCities[index].accentColorName = accentColorName
    }

    func recordFreshSnapshot(_ weather: CityWeather) {
        guard isFavorite(weather.name) else { return }
        favoriteSnapshots[normalized(weather.name)] = weather
    }

    private func normalized(_ city: String) -> String {
        city.lowercased()
    }

    private static func loadFavoriteSnapshots() -> [String: CityWeather] {
        guard let data = UserDefaults.standard.data(forKey: "FavoriteSnapshotsKey"),
              let decoded = try? JSONDecoder().decode([String: CityWeather].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistFavoriteSnapshots() {
        guard let data = try? JSONEncoder().encode(favoriteSnapshots) else { return }
        UserDefaults.standard.set(data, forKey: "FavoriteSnapshotsKey")
    }

    // eski formatta düz isim listesi varsa koordinatsız favoriye çevirir
    private static func loadSavedCities() -> [FavoriteCity] {
        if let data = UserDefaults.standard.data(forKey: "SavedCitiesKey"),
           let decoded = try? JSONDecoder().decode([FavoriteCity].self, from: data) {
            return decoded
        }
        let legacyNames = UserDefaults.standard.stringArray(forKey: "SavedCitiesKey") ?? []
        return legacyNames.map { FavoriteCity(name: $0, lat: nil, lon: nil) }
    }

    private func persistSavedCities() {
        guard let data = try? JSONEncoder().encode(savedCities) else { return }
        UserDefaults.standard.set(data, forKey: "SavedCitiesKey")
    }

    func snapshotWeather(for location: WeatherLocation) async -> CityWeather? {
        guard let bundle = try? await service.fetchWeather(at: location) else { return nil }
        return location.applying(to: bundle.current)
    }
}
