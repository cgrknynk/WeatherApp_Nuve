//
//  AppIconManager.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import UIKit

// MARK: - hava durumuna göre değişen uygulama ikonu
// apple'ın kendi hava durumu uygulamasında bile olmayan bir dokunuş: ana
// ekrandaki ikon, kullanıcının BULUNDUĞU yerin (mevcut konum) o anki
// havasına göre otomatik değişiyor. hangi şehre BAKILDIĞINA göre değil,
// bilerek sadece gerçek konuma göre — yoksa arama yaparken ikon sürekli
// zıplar, kullanıcıyı rahatsız ederdi
enum AppIconManager {
    // yeni ikon görselleri WeatherApp/AlternateIcons/ altında, dosya adları
    // info.plist'teki CFBundleAlternateIcons anahtarlarıyla birebir aynı
    private static func iconName(for conditionCode: Int) -> String? {
        switch conditionCode {
        case 200...232, 300...321, 500...531:
            return "AppIcon-Rainy"
        case 600...622:
            return "AppIcon-Snowy"
        case 701...781, 803...804:
            return "AppIcon-Cloudy"
        default:
            // 800-802: açık/az bulutlu, bunun için ayrı bir ikon yok —
            // sistemin birincil (varsayılan) ikonu zaten bu havayı temsil ediyor
            return nil
        }
    }

    @MainActor
    static func update(for conditionCode: Int) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let target = iconName(for: conditionCode)
        // zaten o ikondaysak sisteme tekrar sormuyoruz, gereksiz bir işlem
        guard UIApplication.shared.alternateIconName != target else { return }
        UIApplication.shared.setAlternateIconName(target, completionHandler: nil)
    }
}
