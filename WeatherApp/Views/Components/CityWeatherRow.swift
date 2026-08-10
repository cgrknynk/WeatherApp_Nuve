//
//  CityWeatherRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

struct CityWeatherRow: View {
    let name: String
    let temperature: Double
    let systemIconName: String
    let unit: TemperatureUnit
    var timezoneOffsetSeconds: Int? = nil
    var conditionCode: Int? = nil
    var accentColor: Color? = nil

    private var notableWeatherIcon: (name: String, color: Color)? {
        guard let conditionCode else { return nil }
        switch conditionCode {
        case 200...232: return ("cloud.bolt.fill", .yellow)
        case 600...622: return ("snowflake", .white)
        case 502, 522, 531: return ("cloud.heavyrain.fill", .cyan)
        default: return nil
        }
    }

    private var cityTimeZone: TimeZone? {
        timezoneOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(name.capitalized)
                        .font(.weatherRowTitle)
                        .foregroundColor(.white)

                    if let notableWeatherIcon {
                        Image(systemName: notableWeatherIcon.name)
                            .font(.caption)
                            .foregroundColor(notableWeatherIcon.color)
                    }
                }

                if let cityTimeZone {
                    TimelineView(.everyMinute) { timeline in
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .medium))
                            Text(timeline.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone)))
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.55))
                    }
                }
            }

            Spacer()

            Image(systemName: systemIconName)
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .foregroundColor(.white)

            Text(unit.format(temperature))
                .font(.weatherRowTemperature)
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .weatherGlassCard(cornerRadius: 18, accentTint: accentColor)
    }
}
