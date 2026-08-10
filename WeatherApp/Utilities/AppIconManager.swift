//
//  AppIconManager.swift
//  WeatherApp
//

import UIKit

enum AppIconManager {
    private static func iconName(for conditionCode: Int) -> String? {
        switch conditionCode {
        case 200...232, 300...321, 500...531:
            return "AppIcon-Rainy"
        case 600...622:
            return "AppIcon-Snowy"
        case 701...781, 803...804:
            return "AppIcon-Cloudy"
        default:
            return nil
        }
    }

    @MainActor
    static func update(for conditionCode: Int) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let target = iconName(for: conditionCode)
        guard UIApplication.shared.alternateIconName != target else { return }
        UIApplication.shared.setAlternateIconName(target, completionHandler: nil)
    }
}
