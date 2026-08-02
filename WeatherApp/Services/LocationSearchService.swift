import Foundation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    
    @Published var searchQuery = "" {
        didSet {
            // Kullanıcı her harf girdiğinde arama motoruna bu metni gönderiyoruz
            searchCompleter.queryFragment = searchQuery
        }
    }
    
    @Published var searchResults: [MKLocalSearchCompletion] = []
    
    private var searchCompleter: MKLocalSearchCompleter
    
    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()
        
        searchCompleter.delegate = self
        // Sadece adresleri/şehirleri aramasını istiyoruz (işletmeleri veya kafeleri değil)
        searchCompleter.resultTypes = .address
    }
    
    // Apple bize sonuçları bulduğunda bu fonksiyon tetikleniyor
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            // Sadece başlığında veya alt başlığında virgül olanları (şehir/ülke formatı) filtreleyebiliriz
            // ya da doğrudan hepsini alabiliriz. Biz hepsini alalım:
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Arama tamamlayıcı hatası: \(error.localizedDescription)")
    }
}
//
//  LocationSearchService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 31.07.2026.
//

