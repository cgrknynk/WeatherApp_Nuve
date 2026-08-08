import Foundation
import Combine

// MARK: - saatlik tahmin, grafik için sade bir veri kalıbı
struct HourlyForecast {
    let time: Date
    let temperature: Double
}

// MARK: - ekranın durumları
enum WeatherViewState {
    case idle
    case loading
    case success(CityWeather)
    case error(String)
}

// MARK: - sıcaklık birimi
// api'den her zaman celsius alıyorum, fahrenayt'a sadece ekranda gösterirken
// çeviriyorum, birim değişince yeniden ağa istek atmama gerek kalmıyor
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

// MARK: - rüzgar hızı birimi
// api'den hep km/s alıyorum, mph'e sadece ekranda çeviriyorum
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

// MARK: - uygulamanın beyni
// eskiden bir delegate üzerinden haber alıyordum, servis zaten async/await
// kullandığı için buna gerek kalmadı, artık sonucu direkt bekleyip do/catch
// ile karşılıyorum
@MainActor
final class WeatherViewModel: ObservableObject {

    @Published private(set) var state: WeatherViewState = .idle
    @Published private(set) var hourlyForecast: [HourlyForecast] = []
    @Published private(set) var dailyForecast: [DailyForecast] = []
    @Published private(set) var airQuality: AirQuality?
    @Published private(set) var lastUpdated: Date?

    // favori şehirlerin listesi, her biri isim ve koordinat taşıyor, bir daha
    // asla sadece isimle yeniden aranmasınlar diye
    @Published var savedCities: [FavoriteCity] = [] {
        didSet { persistSavedCities() }
    }

    // favori şehirlerin en son bilinen hava durumu. ana ekrandaki satırlarda
    // her seferinde yeniden istek atmadan sıcaklık gösterebilmek için diskte tutuyorum
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
        // kullanıcı hızlıca başka bir şehre geçerse, eski (hâlâ devam eden)
        // isteğin cevabı yeni ekranın üzerine yazmasın diye eskisini iptal ediyorum
        fetchTask?.cancel()

        state = .loading
        hourlyForecast = []
        dailyForecast = []
        airQuality = nil

        fetchTask = Task {
            do {
                let bundle = try await service.fetchWeather(at: location)
                guard !Task.isCancelled else { return }

                // koordinatla sorgulandıysa ismi kullanıcının aradığı isimle
                // düzeltiyorum, api'nin kendi (bazen yanlış semte kayan) ismiyle değil
                let weather = location.applying(to: bundle.current)
                hourlyForecast = bundle.hourly
                dailyForecast = bundle.daily
                state = .success(weather)
                lastUpdated = .now

                // favori mi diye api'nin döndürdüğü kesin isimle kontrol ediyorum,
                // kullanıcının yazdığı arama metniyle değil
                recordFreshSnapshot(weather)

                // hava kalitesi ikincil bir bilgi, bu istek başarısız olsa bile
                // ekranı hataya düşürmesin diye ayrı tutuyorum
                airQuality = try? await service.fetchAirQuality(lat: weather.lat, lon: weather.lon)
            } catch is CancellationError {
                // iptal edilen bir isteğin hatasını kullanıcıya göstermeye gerek yok
            } catch {
                guard !Task.isCancelled else { return }
                state = .error((error as? WeatherError)?.errorDescription ?? "Beklenmedik bir hata oluştu.")
            }
        }
    }

    // ana ekran açıldığında tüm favori şehirlerin sıcaklığını sessizce tazeler,
    // kullanıcı hiçbir yere dokunmadan güncel değerleri görür. favorinin
    // koordinatı varsa onunla sorguluyorum, isimle yeniden aramanın
    // getirdiği sapmalar bir daha yaşanmasın diye
    func refreshFavoriteSnapshots() {
        for favorite in savedCities {
            Task {
                if let bundle = try? await service.fetchWeather(at: favorite.location) {
                    favoriteSnapshots[normalized(favorite.name)] = favorite.location.applying(to: bundle.current)
                }
            }
        }
    }

    // MARK: - favori ekleme/çıkarma
    // weather parametresi sadece ekleme için zorunlu, çünkü favoriyi doğru
    // koordinatla kaydedebilmem için elimde zaten yüklenmiş bir hava durumu
    // olması lazım. çıkarırken buna gerek yok, nil geçilebilir
    func toggleFavorite(name: String, weather: CityWeather?) {
        if isFavorite(name) {
            savedCities.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            favoriteSnapshots.removeValue(forKey: normalized(name))
        } else if let weather, weather.name.caseInsensitiveCompare(name) == .orderedSame {
            savedCities.append(FavoriteCity(name: weather.name, lat: weather.lat, lon: weather.lon))

            // şehir genelde detay ekranında yıldıza basılarak ekleniyor ve o
            // ekranda zaten taze bir veri var. ana ekrana dönünce boşuna yeni
            // bir istek beklemesin diye elimdeki veriyi hemen kaydediyorum
            favoriteSnapshots[normalized(weather.name)] = weather
        }
    }

    func isFavorite(_ city: String) -> Bool {
        savedCities.contains { $0.name.caseInsensitiveCompare(city) == .orderedSame }
    }

    // EditFavoriteSheet'ten gelen takma isim/renk değişikliğini kalıcı
    // favoriye yazıyorum. `savedCities` zaten didSet'inde diske kaydediyor,
    // burada ekstra bir persist çağrısına gerek yok
    func updateFavorite(id: String, nickname: String?, accentColorName: String?) {
        guard let index = savedCities.firstIndex(where: { $0.id == id }) else { return }
        savedCities[index].nickname = nickname
        savedCities[index].accentColorName = accentColorName
    }

    // bir şehrin taze verisi her geldiğinde (fetchWeather içinden) çağrılıyor,
    // favoriyse anlık görüntüyü hemen güncelliyor. bu olmasa, detay ekranında
    // doğru sıcaklığı görüp ana ekrana dönünce satır hâlâ eski değeri gösterirdi
    func recordFreshSnapshot(_ weather: CityWeather) {
        guard isFavorite(weather.name) else { return }
        favoriteSnapshots[normalized(weather.name)] = weather
    }

    private func normalized(_ city: String) -> String {
        city.lowercased()
    }

    // MARK: - favori önbelleğini diske kaydetme
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

    // MARK: - favori listesini diske kaydetme
    // eskiden burada düz bir isim listesi saklanıyordu. yeni format artık
    // koordinatı da tutuyor. eski formatta kayıt varsa onu okuyup koordinatsız
    // favorilere çeviriyorum, bunlar isimle aramaya düşmeye devam ediyor,
    // kullanıcı böyle bir favoriyi silip tekrar eklerse o da koordinatlı olur
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

    // ana ekrandaki "mevcut konum" kartı için tek seferlik, sessiz bir hava
    // durumu isteği. ana state'i etkilemiyor, o yüzden ayrı bir fonksiyon
    func snapshotWeather(for location: WeatherLocation) async -> CityWeather? {
        guard let bundle = try? await service.fetchWeather(at: location) else { return nil }
        return location.applying(to: bundle.current)
    }
}
