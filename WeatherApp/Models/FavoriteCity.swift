//
//  FavoriteCity.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

struct FavoriteCity: Codable, Equatable, Identifiable {
    let name: String
    let lat: Double?
    let lon: Double?

    var nickname: String?
    var accentColorName: String?

    var id: String { name.lowercased() }

    var displayName: String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? name : trimmed
    }

    var accentColor: Color? {
        accentColorName.flatMap { FavoriteCity.namedColors[$0] }
    }

    static let namedColors: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green,
        "mint": .mint, "teal": .teal, "cyan": .cyan, "blue": .blue,
        "indigo": .indigo, "purple": .purple, "pink": .pink
    ]

    var location: WeatherLocation {
        if let lat, let lon {
            return .coordinate(lat: lat, lon: lon, displayName: name)
        }
        return .name(name)
    }
}
