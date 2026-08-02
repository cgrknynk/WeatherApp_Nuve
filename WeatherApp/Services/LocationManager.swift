import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var displayLocationName: String? // Örn: "Melikgazi, Kayseri"
    @Published var apiSearchCityName: String?   // Örn: "Kayseri"
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
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
                    
                    // ÇÖZÜM BURADA: shortAddress'in opsiyonel olduğunu artık kesin biliyoruz.
                    // Güvenli bir şekilde ?? "" ile unwrap ediyoruz.
                    let locationString = address.shortAddress ?? ""
                    
                    await MainActor.run {
                        self.displayLocationName = locationString.isEmpty ? "Konum Bulunamadı" : locationString
                        
                        // API için sadece şehri almak adına virgülle ayırıp son parçayı (Örn: Kayseri) alıyoruz
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
