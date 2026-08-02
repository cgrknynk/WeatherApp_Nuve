import Foundation
import Combine

// MARK: - Saatlik Tahmin Modeli (Grafik İçin Temiz Veri Şablonu)
struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let temperature: Double
}

// MARK: - Sayfa Durumları (State Machine)
enum WeatherViewState {
    case idle
    case loading
    case success(CityWeather)
    case error(String)
}

// MARK: - Uygulamanın Beyni (ViewModel)
class WeatherViewModel: ObservableObject, WeatherServiceDelegate {
    
    // Tüm durumları (yükleniyor, hata, başarılı) tek bir yapıdan yönetiyoruz
    @Published var state: WeatherViewState = .idle
    
    // Arayüzdeki (UI) "SwiftUI Charts" grafiğine güç verecek saatlik tahmin dizisi
    @Published var hourlyForecast: [HourlyForecast] = []
    
    // YENİ: 5 Günlük tahmin listemizi besleyecek dizi
    @Published var dailyForecast: [DailyForecast] = []
    
    // Favori şehirlerimizin listesi.
    @Published var savedCities: [String] = [] {
        didSet {
            UserDefaults.standard.set(savedCities, forKey: "SavedCitiesKey")
        }
    }
    
    private var weatherService = WeatherService()
    
    init() {
        self.weatherService.delegate = self
        self.savedCities = UserDefaults.standard.stringArray(forKey: "SavedCitiesKey") ?? []
    }
    
    func fetchWeather(for city: String) {
        state = .loading // Ekranı yükleniyor moduna geçir
        hourlyForecast = [] // Yeni arama yaparken eski şehrin grafiğini temizle
        dailyForecast = []  // YENİ: Eski şehrin 5 günlük verisini de temizle
        
        Task {
            // Hem ana hava durumunu hem de tahminleri eşzamanlı olarak çekiyoruz
            await weatherService.fetchWeather(for: city)
            await weatherService.fetchForecast(for: city)
        }
    }
    
    // MARK: - Favori Ekleme/Çıkarma Mantığı
    func toggleFavorite(city: String) {
        if savedCities.contains(city) {
            savedCities.removeAll { $0 == city }
        } else {
            savedCities.append(city)
        }
    }
    
    // MARK: - Delegate (Patron) Sözleşmesinin Gereklilikleri
    
    func weatherServiceDidFetchData(_ service: WeatherServiceProtocol, didUpdateWeather weather: CityWeather) {
        DispatchQueue.main.async {
            self.state = .success(weather) // Başarılı duruma geç ve veriyi UI'a aktar
        }
    }
    
    // GÜNCELLENDİ: Artık hem saatlik hem de günlük veriyi aynı anda alıyoruz
    func weatherServiceDidFetchForecast(_ service: WeatherServiceProtocol, hourly: [HourlyForecast], daily: [DailyForecast]) {
        DispatchQueue.main.async {
            self.hourlyForecast = hourly
            self.dailyForecast = daily
        }
    }
    
    func weatherServiceDidFail(_ service: any WeatherServiceProtocol, withError error: any Error) {
        DispatchQueue.main.async {
            self.state = .error("Bağlantı kurulamadı. İnternetinizi veya şehir adını kontrol edin.") // Hata durumuna geç
        }
    }
}
