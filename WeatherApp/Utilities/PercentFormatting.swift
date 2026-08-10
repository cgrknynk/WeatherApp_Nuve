//
//  PercentFormatting.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

extension Int {
    var percentFormatted: String {
        let format = String(localized: "format.percent", defaultValue: "%%%d")
        return String(format: format, self)
    }
}
