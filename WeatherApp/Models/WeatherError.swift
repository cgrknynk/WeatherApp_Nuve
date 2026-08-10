//
//  WeatherError.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

enum WeatherError: LocalizedError {
    case cityNotFound
    case network
    case decoding
    case invalidResponse

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
