//
//  LocationSearchService.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 31.07.2026.
//

import Foundation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published var searchQuery = "" {
        didSet {
            searchCompleter.queryFragment = searchQuery
        }
    }

    @Published var searchResults: [MKLocalSearchCompletion] = []

    private var searchCompleter: MKLocalSearchCompleter

    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()

        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Arama tamamlayıcı hatası: \(error.localizedDescription)")
    }

    // seçilen sonucu isim yerine gerçek bir koordinata çevirir
    func resolve(_ completion: MKLocalSearchCompletion) async -> WeatherLocation? {
        await geocode(text: completion.title, fallbackName: Self.shortName(from: completion.title))
    }

    func resolve(freeText: String) async -> WeatherLocation? {
        await geocode(text: freeText, fallbackName: Self.shortName(from: freeText))
    }

    // "istanbul, istanbul, türkiye" gibi başlıkları ilk parçaya indirger
    private static func shortName(from title: String) -> String {
        title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? title
    }

    // MKGeocodingRequest iOS 26'dan önce yok; MKLocalSearch iOS 18'den beri
    // aynı işi görüyor, bu yüzden geocode'u onun üzerinden yapıyoruz
    private func geocode(text: String, fallbackName: String) async -> WeatherLocation? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address

        guard let response = try? await MKLocalSearch(request: request).start(),
              !response.mapItems.isEmpty else {
            return .name(fallbackName)
        }

        let normalizedFallback = fallbackName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let mapItem = response.mapItems.first { item in
            [item.name, item.placemark.locality].compactMap { $0 }.contains {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedFallback
            }
        } ?? response.mapItems[0]

        // ekranda her zaman kullanıcının aradığı isim gösterilir
        let coordinate = mapItem.placemark.coordinate
        return .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: fallbackName)
    }
}
