//
//  Typography.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - uygulamanın font sistemi
// önce rounded, sonra düz default fontu denedim ama rakamlarda ikisi neredeyse
// aynı göründüğü için fark hiç belli olmuyordu. şimdi apple'ın haberler/borsa
// gibi kendi uygulamalarında yaptığı gibi yapıyorum: new york (serif) sadece
// sayılarda (sıcaklık, nem, basınç), san francisco (sans) her yerde. böylece
// her sayı göründüğünde göze çarpıyor. hepsi sistemin kendi boyutlarını
// kullandığı için yazı büyütme ayarıyla birlikte büyüyüp küçülüyor
extension Font {
    // dev sıcaklık yazısı ("24°" gibi), new york fontu, ince ağırlık
    static let weatherHero = Font.system(size: 96, weight: .thin, design: .serif)

    // şehir ismi, sıcaklığın hemen üstünde, aynı serif aileden
    static let weatherCityName = Font.system(size: 34, weight: .regular, design: .serif)

    // sıcaklığın altındaki durum yazısı ("az bulutlu" gibi), bu sayı değil
    // kelime olduğu için sans kalıyor
    static let weatherCondition = Font.system(.title3, design: .default).weight(.medium)

    // "önümüzdeki günler" gibi bölüm başlıkları, büyük harf ve geniş aralıkla kullanılıyor
    static let weatherSectionHeader = Font.system(.caption, design: .default).weight(.semibold)

    // cam kartların içindeki etiket (sans) ve değer (serif, çünkü hep bir sayı) çifti.
    // değer eskiden title2'ydi, kutular altlarında boş yer bırakıyordu — title'a
    // büyütünce hem kutu daha dolu görünüyor hem sayı ilk bakışta daha net okunuyor
    static let weatherCardTitle = Font.system(.caption, design: .default).weight(.semibold)
    static let weatherCardValue = Font.system(.title, design: .serif).weight(.medium)

    // liste satırları (favoriler, arama sonuçları), isim sans, sıcaklık serif
    static let weatherRowTitle = Font.system(.title3, design: .default).weight(.semibold)
    static let weatherRowSubtitle = Font.system(.subheadline, design: .default).weight(.regular)
    static let weatherRowTemperature = Font.system(.title2, design: .serif).weight(.regular)

    // günlük tahminde min/max, saatlik grafikteki küçük sıcaklık yazıları
    static let weatherTemperatureSmall = Font.system(.subheadline, design: .serif).weight(.medium)

    // genel gövde ve küçük açıklama yazıları
    static let weatherBody = Font.system(.body, design: .default)
    static let weatherCaption = Font.system(.caption, design: .default)

    // "nuve" logosunun yazısı, serif olması ona biraz daha özel bir karakter
    // katıyor, geniş harf aralığıyla birlikte kullanılıyor (BrandHeader'a bak)
    static let weatherBrandWordmark = Font.system(size: 20, weight: .medium, design: .serif)
}

// MARK: - büyük harfli etiketler için ortak stil
// detay kartlarındaki ("NEM", "BASINÇ" gibi) etiketler hem büyük harf hem
// harfler arası boşluklu, ikisi birden "sistem etiketi" gibi hissettiriyor.
// font tek başına harf aralığı taşıyamadığı için Text'e küçük bir ek yaptım
extension Text {
    func weatherLabelStyle() -> Text {
        self.font(.weatherCardTitle).tracking(0.6)
    }
}
