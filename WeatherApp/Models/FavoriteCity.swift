//
//  FavoriteCity.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import Foundation

// MARK: - favori bir şehir
// eskiden favoriler sadece bir isim listesiydi. bir favoriye her girdiğimde o
// ismi tekrar api'ye soruyordum ve yeniden bir koordinata çözüyordum. sorun şu:
// "kayseri" hem il hem şehir ismi, böyle yerlerde api bazen şehrin kendisi
// yerine ilin merkezine yakın farklı bir noktaya düşüyordu, bu da her seferinde
// biraz farklı bir sıcaklık göstermesine yol açıyordu. çözüm: favori eklenirken
// o anki doğru koordinatı da kalıcı olarak saklıyorum, bir daha asla isimle
// yeniden aramıyorum
struct FavoriteCity: Codable, Hashable, Identifiable {
    let name: String
    let lat: Double?
    let lon: Double?

    var id: String { name.lowercased() }

    // koordinat varsa onunla sorguluyorum, çünkü kesin sonuç veriyor. koordinat
    // yoksa (eski bir favoriyse, bu düzeltmeden önce eklenmiş) isimle aramaya
    // düşüyorum. kullanıcı böyle bir favoriyi silip tekrar eklerse o da artık
    // koordinatlı hale gelir
    var location: WeatherLocation {
        if let lat, let lon {
            return .coordinate(lat: lat, lon: lon, displayName: name)
        }
        return .name(name)
    }
}
