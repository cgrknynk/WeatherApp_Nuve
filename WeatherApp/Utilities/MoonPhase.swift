//
//  MoonPhase.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import Foundation

// MARK: - o geceki ay evresi
// hiçbir api'ye ihtiyaç yok, ayın evresi tamamen tahmin edilebilir bir
// döngü (~29.53 gün, "sinodik ay" denir) — bilinen bir yeni ay anından
// (2000-01-06 18:14 utc, astronomik olarak doğrulanmış bir referans) bu yana
// kaç gün geçtiğini bulup, o döngünün neresinde olduğumuza bakıyorum
enum MoonPhase: CaseIterable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, lastQuarter, waningCrescent

    var systemImageName: String {
        switch self {
        case .newMoon:         return "moonphase.new.moon"
        case .waxingCrescent:  return "moonphase.waxing.crescent"
        case .firstQuarter:    return "moonphase.first.quarter"
        case .waxingGibbous:   return "moonphase.waxing.gibbous"
        case .fullMoon:        return "moonphase.full.moon"
        case .waningGibbous:   return "moonphase.waning.gibbous"
        case .lastQuarter:     return "moonphase.last.quarter"
        case .waningCrescent:  return "moonphase.waning.crescent"
        }
    }

    var localizedName: String {
        switch self {
        case .newMoon:
            return String(localized: "moon.new", defaultValue: "Yeni Ay")
        case .waxingCrescent:
            return String(localized: "moon.waxing_crescent", defaultValue: "Büyüyen Hilal")
        case .firstQuarter:
            return String(localized: "moon.first_quarter", defaultValue: "İlk Dördün")
        case .waxingGibbous:
            return String(localized: "moon.waxing_gibbous", defaultValue: "Büyüyen Ay")
        case .fullMoon:
            return String(localized: "moon.full", defaultValue: "Dolunay")
        case .waningGibbous:
            return String(localized: "moon.waning_gibbous", defaultValue: "Küçülen Ay")
        case .lastQuarter:
            return String(localized: "moon.last_quarter", defaultValue: "Son Dördün")
        case .waningCrescent:
            return String(localized: "moon.waning_crescent", defaultValue: "Küçülen Hilal")
        }
    }

    // referans yeni ay: 2000-01-06 18:14 utc
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)
    private static let synodicMonthInDays = 29.530588853

    // döngünün neresinde olduğumuzu (0 ile sinodik ay uzunluğu arası, gün
    // cinsinden) hesaplıyor — hem evreyi hem aydınlanma yüzdesini bu tek
    // sayıdan türetiyoruz
    private static func age(for date: Date) -> Double {
        let daysSinceReference = date.timeIntervalSince(referenceNewMoon) / 86_400
        var age = daysSinceReference.truncatingRemainder(dividingBy: synodicMonthInDays)
        if age < 0 { age += synodicMonthInDays }
        return age
    }

    static func phase(for date: Date) -> MoonPhase {
        // döngüyü (0 ile sinodik ay arası) 8 eşit dilime bölüp, hangi dilime
        // düştüğümüzü buluyoruz. rounded() sayesinde her evrenin "en temsili"
        // anı (mesela tam dolunay günü) kendi diliminin ortasına denk geliyor
        let sliceIndex = Int((age(for: date) / synodicMonthInDays * 8).rounded()) % 8
        return allCases[sliceIndex]
    }

    // aydınlanan yüzeyin yüzdesi — standart bir kozinüs yaklaşıklığı: yeni
    // ayda (age=0) %0, dolunayda (age=yarım döngü) %100, ikisi arasında
    // yumuşak bir eğriyle geçiyor. evre ismi ("Küçülen Hilal" gibi) SADECE
    // 8 kaba kategori veriyordu, bu sayı "ne kadar" sorusuna da cevap veriyor
    static func illuminationPercent(for date: Date) -> Int {
        let fraction = (1 - cos(2 * Double.pi * age(for: date) / synodicMonthInDays)) / 2
        return Int((fraction * 100).rounded())
    }
}
