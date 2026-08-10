//
//  WeatherDetailBox.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

struct WeatherDetailBox: View {
    var icon: String
    var iconColor: Color
    var title: LocalizedStringKey
    var value: String
    var note: String? = nil
    var trend: WeatherTrend? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.weatherCardTitle)
                    .foregroundColor(iconColor)
                Text(title)
                    .weatherLabelStyle()
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 5) {
                Text(value)
                    .font(.weatherCardValue)
                    .foregroundColor(.white)

                if let trend {
                    Image(systemName: trend.systemImageName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(iconColor)
                }
            }

            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: weatherDetailBoxHeight)
        .weatherGlassCard(accentTint: iconColor)
        .accessibilityElement(children: .combine)
    }
}
