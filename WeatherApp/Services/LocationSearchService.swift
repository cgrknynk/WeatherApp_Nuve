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
            // kullanıcı her harf yazdığında arama motoruna bu metni gönderiyorum
            searchCompleter.queryFragment = searchQuery
        }
    }

    @Published var searchResults: [MKLocalSearchCompletion] = []

    private var searchCompleter: MKLocalSearchCompleter

    override init() {
        searchCompleter = MKLocalSearchCompleter()
        super.init()

        searchCompleter.delegate = self
        // sadece adres/şehir arasın, işletme veya kafe önermesin diye
        searchCompleter.resultTypes = .address
    }

    // mapkit sonuçları bulunca bu fonksiyon otomatik çağrılıyor
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            // gelen sonuçları filtrelemeden hepsini alıyorum, ekranda listeleniyorlar
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Arama tamamlayıcı hatası: \(error.localizedDescription)")
    }

    // MARK: - seçilen sonucu koordinata çevirme
    // kullanıcı önerilen bir sonuca dokununca, sadece başlığı (mesela "izmir")
    // alıp o isimle sormak yerine gerçek bir koordinata çeviriyorum. böylece
    // isim eşleşmesi tutmama ihtimali tamamen ortadan kalkıyor.
    //
    // burada iki farklı yöntem denedim ve ikisi de işe yaramadı: önce mapkit'in
    // kendi arama motorunu kullandım ama o bir işletme/mekan arama motoru,
    // geniş bir şehir ismi verince şehrin kendisi yerine içindeki bir semti
    // döndürebiliyordu ("istanbul" yazınca "karaköy" çıkması gibi). sonra
    // eski clgeocoder'ı kullandım, o da bazen yavaş çalışıp hata verdi ve
    // "kadıköy" gibi net bir arama bile "üsküdar" gibi yanlış bir komşu
    // ilçeye çözülebildi. clgeocoder artık ios 26'da kullanımdan kaldırıldığı
    // (deprecated) için, aynı işi yapan yeni mapkit isteği olan
    // mkgeocodingrequest'e geçtim — mantık aynı kaldı, sadece api değişti
    func resolve(_ completion: MKLocalSearchCompletion) async -> WeatherLocation? {
        await geocode(text: completion.title, fallbackName: Self.shortName(from: completion.title))
    }

    // kullanıcı öneriler arasından seçmeyip klavyeden yazıp enter'a basarsa
    // elimde sadece serbest metin oluyor, onu da aynı şekilde koordinata
    // çevirmeye çalışıyorum, olmazsa isimle aramaya düşüyorum
    func resolve(freeText: String) async -> WeatherLocation? {
        await geocode(text: freeText, fallbackName: Self.shortName(from: freeText))
    }

    // MARK: - "istanbul, istanbul, türkiye" gibi uzun başlıkları kısaltma
    // şehir ile il ismi aynı olan yerlerde (istanbul hem şehir hem il, beşiktaş
    // istanbul'un bir ilçesi) mapkit başlığı bilerek uzun veriyor, mesela
    // "beşiktaş, istanbul, türkiye" gibi. ama kullanıcı sadece "beşiktaş"
    // görmek istiyor, o yüzden virgülle ayırıp ilk parçayı alıyorum, geri
    // kalanını atıyorum
    private static func shortName(from title: String) -> String {
        title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? title
    }

    private func geocode(text: String, fallbackName: String) async -> WeatherLocation? {
        guard let request = MKGeocodingRequest(addressString: text) else {
            return .name(fallbackName)
        }
        guard let mapItems = try? await request.mapItems, !mapItems.isEmpty else {
            return .name(fallbackName)
        }

        // dönen sonuçlar arasında aradığım isimle (büyük/küçük harf ve aksan
        // farketmeksizin) tam eşleşen biri varsa onu seçiyorum, yoksa
        // mapkit'in en olası dediği ilk sonuca düşüyorum
        let normalizedFallback = fallbackName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let mapItem = mapItems.first { item in
            [item.name, item.addressRepresentations?.cityName].compactMap { $0 }.contains {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedFallback
            }
        } ?? mapItems[0]

        // ekranda her zaman kullanıcının aradığı ismi gösteriyorum, mapkit'in
        // kendi ürettiği (bazen yanlış komşu semte kayabilen) ismi değil. böylece
        // koordinat tam istenen noktada olmasa bile görünen isim hep doğru olur
        let coordinate = mapItem.location.coordinate
        return .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: fallbackName)
    }
}

