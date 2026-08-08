//
//  WeatherLocation.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import Foundation

// MARK: - bir yerin hava durumunu sorgulama şekli
// bir şehri iki şekilde sorgulayabiliyorum: sadece ismiyle (favoriler, klavyeden
// yazılan serbest metin) ya da koordinatla (arama sonucu, mevcut konum). koordinat
// her zaman kesin sonuç veriyor, ismiyle arama bazen tutmuyordu çünkü api'nin
// veritabanında tam eşleşme aramıyor, bu yüzden mümkün olan her yerde koordinat kullanıyorum
enum WeatherLocation: Hashable {
    case name(String)
    case coordinate(lat: Double, lon: Double, displayName: String)

    // favoriler artık koordinatla saklanıyor ama ekranda/favori listesinde
    // gösterilecek tek bir isme her zaman ihtiyacım var, onu buradan alıyorum
    var displayName: String {
        switch self {
        case .name(let name): return name
        case .coordinate(_, _, let displayName): return displayName
        }
    }

    // MARK: - ekrandaki ismi düzeltme
    // burada büyük bir hata vardı: openweather bana koordinatı verdiğimde, o
    // koordinata en yakın kayıtlı yerin ismini döndürüyordu, benim aradığım
    // şehrin ismini değil. mesela istanbul'u aradığımda ekranda karaköy
    // yazıyordu çünkü koordinat oraya denk geliyordu. arama tarafını ne kadar
    // düzeltirsem düzelteyim bu sorunu çözemedim çünkü sorun benim bulduğum
    // koordinatta değildi, api'nin o koordinata verdiği isimdeydi.
    //
    // çözüm: eğer elimde koordinat varsa (yani kullanıcı zaten bir şey seçti,
    // ona güveniyorum), gelen hava durumundaki ismi api'nin verdiğiyle değil
    // kullanıcının aradığı isimle değiştiriyorum. böylece ekranda hep doğru
    // isim görünüyor. sadece isimle arama yapıldıysa (elimde güvenilir bir
    // seçim yok) buna dokunmuyorum, api'nin verdiği isim zaten elimdeki en iyi bilgi
    func applying(to weather: CityWeather) -> CityWeather {
        guard case .coordinate = self else { return weather }
        var corrected = weather
        corrected.name = displayName
        return corrected
    }
}
