//
//  FavoriteCity.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

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

    // kullanıcının şehre kendi verdiği takma isim ve kart rengi (bkz.
    // EditFavoriteSheet.swift). ikisi de opsiyonel: eski, bu özellikten önce
    // kaydedilmiş favoriler bu alanlar olmadan geliyor, Codable bunları
    // otomatik olarak nil'e düşürüyor
    var nickname: String?
    var accentColorName: String?

    var id: String { name.lowercased() }

    // ekranda gösterilecek isim: takma isim varsa o, yoksa gerçek şehir ismi.
    // hava durumu sorgusu/navigasyon her zaman gerçek `name`/`location`
    // üzerinden yapılıyor, sadece GÖRÜNÜM değişiyor
    var displayName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? name : trimmed
    }

    var accentColor: Color? {
        accentColorName.flatMap { FavoriteCity.namedColors[$0] }
    }

    // sınırlı, isimli bir renk paleti — uygulamanın geri kalanında da hep
    // sabit, tanıdık SwiftUI renkleri kullanıldığı için (mesela WindDetailBox'ın
    // mint'i gibi) rastgele bir hex renk seçiciye göre daha tutarlı duruyor
    static let namedColors: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green,
        "mint": .mint, "teal": .teal, "cyan": .cyan, "blue": .blue,
        "indigo": .indigo, "purple": .purple, "pink": .pink
    ]

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
