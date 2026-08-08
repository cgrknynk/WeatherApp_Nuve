//
//  RelativeDayFormatter.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - gün isimlerini yazdırma
// artık telefonun sistem diline göre çalışıyor, eskiden hep türkçe yazdırıyordum.
// apple'ın kendi hava durumu uygulamasındaki gibi bugün için "bugün", yarın
// için "yarın" yazıyorum, gerisi haftanın günü ismi
enum RelativeDayFormatter {
    static func label(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "day.today", defaultValue: "Bugün")
        }
        if calendar.isDateInTomorrow(date) {
            return String(localized: "day.tomorrow", defaultValue: "Yarın")
        }

        let locale = Locale.autoupdatingCurrent
        return date
            .formatted(.dateTime.weekday(.wide).locale(locale))
            .capitalized(with: locale)
    }
}
