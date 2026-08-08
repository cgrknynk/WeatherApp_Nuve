//
//  WeatherError.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - servisin fırlatabileceği hatalar
// eskiden tek tip bir hata mesajı vardı, şimdi sebebine göre kullanıcıya
// farklı ve anlaşılır bir mesaj gösterebiliyorum
enum WeatherError: LocalizedError {
    case cityNotFound
    case network
    case decoding
    case invalidResponse

    // bu mesajlar ekrana Text(errorMessage) gibi bir değişken üzerinden
    // basılıyor, düz yazı olarak değil. o yüzden swiftui'nin otomatik çeviri
    // sistemi burada işe yaramıyor, String(localized:) ile kendim çeviriyorum
    var errorDescription: String? {
        switch self {
        case .cityNotFound:
            return String(
                localized: "error.city_not_found",
                defaultValue: "Bu isimde bir şehir bulamadık. Yazımı kontrol edip tekrar dener misin?"
            )
        case .network:
            return String(
                localized: "error.network",
                defaultValue: "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
            )
        case .decoding:
            return String(
                localized: "error.decoding",
                defaultValue: "Veri okunurken bir sorun oluştu. Birazdan tekrar dene."
            )
        case .invalidResponse:
            return String(
                localized: "error.invalid_response",
                defaultValue: "Sunucudan beklenmedik bir yanıt geldi."
            )
        }
    }
}
