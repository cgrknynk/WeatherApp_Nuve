# WeatherApp

SwiftUI ile yazılmış, iOS 26 hedefleyen bir hava durumu uygulaması. Liquid Glass tasarım dili, canlı gündüz/gece arka planları, favori şehirler, hava kalitesi ve 24 saatlik/günlük tahmin içeriyor.

## Kurulum

Projeyi derlemeden önce `WeatherApp/Services/Secrets.swift` dosyasını elle oluşturman gerekiyor (bu dosya `.gitignore`'da, repoya girmiyor):

```swift
enum Secrets {
    static let openWeatherAPIKey = "BURAYA_KENDI_ANAHTARIN"
}
```

Anahtarı [openweathermap.org](https://openweathermap.org/api)'dan ücretsiz alabilirsin.
