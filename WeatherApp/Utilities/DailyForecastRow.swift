//
//  DailyForecastRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

struct DailyForecastRow: View {
    let day: DailyForecast
    let calendar: Calendar
    let unit: TemperatureUnit

    private var isSnowyDay: Bool {
        (600...622).contains(day.conditionCode)
    }

    var body: some View {
        HStack {
            Text(RelativeDayFormatter.label(for: day.date, calendar: calendar))
                .font(.weatherRowSubtitle)
                .foregroundColor(.white)
                .frame(width: 92, alignment: .leading)

            if day.pop >= 0.1 {
                HStack(spacing: 2) {
                    Image(systemName: isSnowyDay ? "snowflake" : "drop.fill")
                        .font(.caption2)
                    Text(Int(day.pop * 100).percentFormatted)
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundColor(isSnowyDay ? .white.opacity(0.85) : .cyan)
                .frame(width: 46, alignment: .leading)
            } else {
                Spacer().frame(width: 46)
            }

            Spacer()

            Image(systemName: day.systemIconName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)

            Spacer()

            HStack(spacing: 12) {
                Text(unit.format(day.minTemperature))
                    .font(.weatherTemperatureSmall)
                    .foregroundColor(.white.opacity(0.6))

                Capsule()
                    .fill(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 60, height: 4)

                Text(unit.format(day.maxTemperature))
                    .font(.weatherTemperatureSmall.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
    }
}
