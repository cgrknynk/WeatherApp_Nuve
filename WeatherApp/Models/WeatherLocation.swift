//
//  WeatherLocation.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

enum WeatherLocation: Hashable {
    case name(String)
    case coordinate(lat: Double, lon: Double, displayName: String)

    var displayName: String {
        switch self {
        case .name(let name): return name
        case .coordinate(_, _, let displayName): return displayName
        }
    }

    // koordinat varsa gösterilen ismi kullanıcının aradığı isimle sabitler
    func applying(to weather: CityWeather) -> CityWeather {
        guard case .coordinate = self else { return weather }
        var corrected = weather
        corrected.name = displayName
        return corrected
    }
}
