//
//  Typography.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// sayılarda serif (New York), geri kalanında sans (San Francisco)
extension Font {
    static let weatherHero = Font.system(size: 96, weight: .thin, design: .serif)
    static let weatherCityName = Font.system(size: 34, weight: .regular, design: .serif)
    static let weatherCondition = Font.system(.title3, design: .default).weight(.medium)
    static let weatherSectionHeader = Font.system(.caption, design: .default).weight(.semibold)
    static let weatherCardTitle = Font.system(.caption, design: .default).weight(.semibold)
    static let weatherCardValue = Font.system(.title, design: .serif).weight(.medium)
    static let weatherRowTitle = Font.system(.title3, design: .default).weight(.semibold)
    static let weatherRowSubtitle = Font.system(.subheadline, design: .default).weight(.regular)
    static let weatherRowTemperature = Font.system(.title2, design: .serif).weight(.regular)
    static let weatherTemperatureSmall = Font.system(.subheadline, design: .serif).weight(.medium)
    static let weatherBody = Font.system(.body, design: .default)
    static let weatherCaption = Font.system(.caption, design: .default)
    static let weatherBrandWordmark = Font.system(size: 20, weight: .medium, design: .serif)
}

extension Text {
    func weatherLabelStyle() -> Text {
        self.font(.weatherCardTitle).tracking(0.6)
    }
}
