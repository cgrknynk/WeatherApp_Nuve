//
//  AirQuality.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - hava kalitesi
// api'nin ayrı ve ücretsiz kirlilik servisinden gelen endeksi (1: iyi, 5: çok
// kötü) ekranda göstermek için hazırladığım küçük model
struct AirQuality {
    let aqi: Int

    // bu metin ekrana Text(airQuality.label) gibi bir değişken üzerinden
    // basılıyor, düz yazı değil, o yüzden String(localized:) ile kendim çeviriyorum
    var label: String {
        switch aqi {
        case 1: return String(localized: "aqi.good", defaultValue: "İyi")
        case 2: return String(localized: "aqi.moderate", defaultValue: "Orta")
        case 3: return String(localized: "aqi.unhealthy_sensitive", defaultValue: "Hassas Gruplar İçin Sağlıksız")
        case 4: return String(localized: "aqi.unhealthy", defaultValue: "Sağlıksız")
        case 5: return String(localized: "aqi.very_unhealthy", defaultValue: "Çok Kötü")
        default: return String(localized: "aqi.unknown", defaultValue: "Bilinmiyor")
        }
    }

    var tintColor: Color {
        switch aqi {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .purple
        }
    }
}
