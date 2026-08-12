import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var displayLocationName: String?
    @Published var apiSearchCityName: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    // uygulama ön plana her döndüğünde izni elle tekrar kontrol eder
    func refreshAuthorizationStatusIfNeeded() {
        let currentStatus = manager.authorizationStatus
        guard currentStatus != authorizationStatus else { return }

        authorizationStatus = currentStatus
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
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

        // CLGeocoder, MapKit'in iOS 26'ya özel adres api'sinden farklı olarak
        // iOS 18'den beri değişmeden var, bu yüzden tersine geocode için onu kullanıyoruz
        Task {
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(newLocation)
                guard let placemark = placemarks.first else { return }

                let locationString = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")

                await MainActor.run {
                    self.displayLocationName = locationString.isEmpty ? "Konum Bulunamadı" : locationString
                    self.apiSearchCityName = placemark.locality ?? locationString
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
