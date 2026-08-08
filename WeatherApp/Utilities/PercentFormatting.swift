//
//  PercentFormatting.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - yüzde işaretini doğru yere koyma
// türkçe'de yüzde işareti sayının önünde yazılır ("%40"), ingilizce'de sonunda
// ("40%"). düz metin birleştirseydim bu sıra hep sabit kalırdı, o yüzden dile
// göre değişen bir format metni kullanıyorum
extension Int {
    var percentFormatted: String {
        let format = String(localized: "format.percent", defaultValue: "%%%d")
        return String(format: format, self)
    }
}
