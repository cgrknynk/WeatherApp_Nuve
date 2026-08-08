import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var displayLocationName: String? // örnek: "melikgazi, kayseri"
    @Published var apiSearchCityName: String?   // örnek: "kayseri"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    // kullanıcı uygulama arka plandayken ayarlar'dan konum iznini değiştirmiş
    // olabilir. sistemin kendi bildirimi buna her zaman güvenilir şekilde haber
    // vermiyor, o yüzden uygulama ön plana her döndüğünde izni burada elle
    // tekrar kontrol ediyorum. durum gerçekten değiştiyse harekete geçiyorum,
    // değişmediyse hiçbir şey yapmıyorum ki gereksiz bir istek atılmasın
    func refreshAuthorizationStatusIfNeeded() {
        let currentStatus = manager.authorizationStatus
        guard currentStatus != authorizationStatus else { return }

        authorizationStatus = currentStatus
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            // izin geri alınmış, elimdeki eski konum artık geçersiz, temizliyorum
            location = nil
            displayLocationName = nil
            apiSearchCityName = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        DispatchQueue.main.async {
            self.location = newLocation.coordinate
            self.manager.stopUpdatingLocation()
        }

        guard let request = MKReverseGeocodingRequest(location: newLocation) else { return }

        Task {
            do {
                let fetchedMapItems = try await request.mapItems

                if let mapItem = fetchedMapItems.first, let address = mapItem.address {

                    // shortAddress opsiyonel olabiliyor, o yüzden boş string'e düşürüyorum
                    let locationString = address.shortAddress ?? ""

                    await MainActor.run {
                        self.displayLocationName = locationString.isEmpty ? "Konum Bulunamadı" : locationString

                        // api'ye sadece şehir ismini göndermek için virgülle bölüp son parçayı alıyorum
                        let components = locationString.components(separatedBy: ",")
                        if let lastComponent = components.last?.trimmingCharacters(in: .whitespaces), !lastComponent.isEmpty {
                            self.apiSearchCityName = lastComponent
                        } else {
                            self.apiSearchCityName = locationString
                        }
                    }
                }
            } catch {
                print("Adres çözümlenemedi: \(error.localizedDescription)")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS Hatası: Konum alınamadı. \(error.localizedDescription)")
    }
}
