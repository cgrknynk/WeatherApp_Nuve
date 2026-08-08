# Kod Rehberi — Kendime Notlar

Bu dosya, projeyi bir süre sonra tekrar açtığımda "ben burada ne yapmıştım, bu satır neden böyle" diye
uğraşmamak için tuttuğum notlar. Hem Swift'in genel söz dizimini (syntax) hem de bu projedeki her
dosyanın ne iş yaptığını, satır satır mantığını buraya yazıyorum. Amaç ders kitabı değil — kendi
projemi kendime anlatmak.

**Üç kardeş dosya var**: bu dosya (yüksek seviye mimari/kararlar), `Satir-Satir-Kod-Aciklamasi.md`
(her satırın Swift SÖZ DİZİMİ kuralı — bu neden `guard`, bu neden `@Published`) ve
`Ekrana-Yansiyan-Kod.md` (aynı satırların gerçek cihazda EKRANDA tam olarak neyi ürettiği, gerçek
ekran görüntüleriyle numaralandırılmış). Üçü birlikte okunmalı.

---

## 1. Genel Mimari

Uygulama klasik bir **MVVM** (Model - View - ViewModel) düzeninde:

```
WeatherApp/
├── Models/               → Sadece veri. Mantık yok, sadece "şu bilgiler var" diyen struct'lar.
├── Services/              → Ağ (network) ve konum gibi dış dünyayla konuşan katman.
├── Utilities/              → Saf, durumsuz (stateless) yardımcı fonksiyonlar (tarih/gün hesaplama vb.)
├── ViewModels/            → Ekranın "beyni". Servisten veri ister, View'a sunulacak hale getirir.
├── DesignSystem/          → Tipografi, renk paleti, arka plan/animasyon gibi görsel dil.
└── Views/                → Ana ekranlar (Home, WeatherView, Settings, Filter...).
    └── Components/        → Birden fazla yerde ya da bir ekranın İÇİNDE tekrar kullanılan,
                              kendi başına anlamlı küçük View'lar (bir kart, bir liste satırı gibi).
```

`Views/Components/` ayrı bir katman gibi görünse de aslında `Views/`in bir alt kümesi — ayrımın amacı
şu: bir ekranın ANA dosyası (örn. `WeatherView.swift`) sadece o ekranın YERLEŞİMİNİ ve akışını anlatmalı;
"bu kart nasıl çiziliyor" gibi detaylar oraya gömülürse dosya çok büyüyüp okunması zorlaşıyor. Bir View,
SADECE bir ekranın içinde kullanılıyor olsa bile, kendi başına "bir şeyi temsil eden" bir bileşense
(örn. bir istatistik kartı, bir liste satırı) `Components/`e taşınıyor; ekrana özgü, başka hiçbir yerde
anlamı olmayan yerleşim kodu ise ana dosyada kalıyor.

Veri akışı hep aynı yönde: **View → ViewModel'e "bana veri getir" der → ViewModel Service'i çağırır →
Service ağdan veri çeker → ViewModel veriyi işler → @Published değişkenler güncellenir → View
otomatik olarak yeniden çizilir.** View hiçbir zaman doğrudan ağa istek atmaz, Service hiçbir zaman
ekranla ilgili bir şey bilmez. Bu ayrım sayelinde herhangi bir katmanı tek başına değiştirebiliyoruz.

Eskiden Service katmanı bir "delegate" (temsilci) üzerinden ViewModel'e haber veriyordu — yani
"işim bitince sana haber veririm" diyen ayrı bir sözleşme (protokol) vardı. Servis zaten `async/await`
kullandığı için bu ekstra katman gereksizdi; şimdi Service fonksiyonları doğrudan sonucu döndürüyor
(`return`) ya da hata fırlatıyor (`throw`). Daha az kod, daha az "bu veri nereden geldi" sorusu.

---

## 2. Swift Söz Dizimi — Bu Projede Kullanılanlar

### `struct` vs `class`

- `struct CityWeather` gibi tanımlar **değer tipi**dir: birine atadığında ya da bir fonksiyona
  gönderdiğinde KOPYALANIR. İçinde mutlaka mantık değil "veri" olmalı.
- `class WeatherViewModel` gibi tanımlar **referans tipi**dir: kopyalanmaz, aynı nesneye işaret eden
  birden fazla değişken olabilir. `ObservableObject` olması gereken her şey (ekranın "hafızası") class
  olmak zorunda, çünkü SwiftUI'ın onu referans olarak takip edebilmesi lazım.
- `WeatherService` bilinçli olarak `struct`: içinde hiç değişen bir durumu (state) yok, sadece sabit
  bir API anahtarı tutuyor. Durumsuz olduğu için class olmasına gerek yok.

### `protocol`

Bir "sözleşme" — "bunu uygulayan her şey şu fonksiyonlara sahip olmalı" demek.
`WeatherServiceProtocol` sayesinde `WeatherViewModel`, gerçek `WeatherService` yerine testler için
sahte (mock) bir servis de kullanabilir; ViewModel sadece "protokole uyan bir şey" bekler, gerçek
tipi umursamaz.

```swift
protocol WeatherServiceProtocol: Sendable {
    func fetchCurrentWeather(for cityName: String) async throws -> CityWeather
    func fetchCurrentWeather(lat: Double, lon: Double) async throws -> CityWeather
}
```

### `async` / `await` ve `throws`

- `async` = "bu fonksiyon zaman alabilir, beklemek gerekebilir" (ağ isteği gibi).
- `await` = "bu noktada bekle, sonucu bekleyen fonksiyonun bitmesini iste".
- `throws` = "bu fonksiyon hata fırlatabilir"; çağıran taraf `try` yazmak zorunda, genelde
  `do { let x = try await ... } catch { ... }` şeklinde kullanılır.

`WeatherViewModel.fetchWeather(for:)` içindeki akış tam olarak bu üçlüyü kullanıyor:

```swift
do {
    switch location {
    case .name(let name): weather = try await service.fetchCurrentWeather(for: name)
    case .coordinate(let lat, let lon, _): weather = try await service.fetchCurrentWeather(lat: lat, lon: lon)
    }
    ...
} catch {
    state = .error(...)
}
```

### `Task` ve iptal (cancellation)

`Task { ... }` bir arka plan işi başlatır. Kullanıcı hızlıca bir şehirden diğerine geçerse, önceki
(yavaş kalan) isteğin cevabı yeni ekranı ezmesin diye eski `Task`'ı `.cancel()` ile iptal ediyoruz.
Swift bir `await`'in ortasında olan işi otomatik durdurmaz — `Task.isCancelled` bayrağını kontrol
etmemiz gerekiyor, `fetchWeather(for:)` içindeki `guard !Task.isCancelled else { return }` satırları
tam olarak bunu yapıyor.

### `@MainActor`

Ekranla ilgili her şey (özellikle `@Published` değişkenler) ana iş parçacığında (main thread)
güncellenmeli, yoksa arayüz garip davranabilir. `@MainActor` işareti "bu class'ın/fonksiyonun her
zaman ana iş parçacığında çalıştığından emin ol" demek. `WeatherViewModel` ve `LocationManager` bu
yüzden `@MainActor`. `WeatherService` ise bilerek `nonisolated` — ağ isteği ve JSON çözümleme (decode)
işi ana iş parçacığını meşgul etmesin diye. (Not: Bu proje Xcode'un yeni "varsayılan olarak her şey
MainActor" ayarını kullanıyor — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — bu yüzden Service
katmanında `nonisolated` yazmazsak, aksi belirtilmediği sürece o da MainActor'a kayardı. Aynı sebeple
`WeatherService.swift` içindeki DTO struct'ları da `private nonisolated` — yoksa onlar da MainActor'a
kayıp, nonisolated servis içinde çözümlenirken uyarı/hata veriyorlardı.)

### Property Wrapper'lar (`@` ile başlayanlar)

| Wrapper | Ne işe yarar | Nerede kullandık |
|---|---|---|
| `@Published` | Değer değişince ekranı otomatik yeniler | `WeatherViewModel.state` |
| `@StateObject` | Bir class'ı View'ın YAŞAM DÖNGÜSÜNE bağlar, bir kere yaratılır | `WeatherAppApp` içindeki `viewModel` |
| `@EnvironmentObject` | Üstteki bir View'ın `.environmentObject(...)` ile verdiği nesneyi alır | `HomeView`, `WeatherView` |
| `@State` | View'a ÖZEL, basit bir değişkenin durumu | Arama metni, animasyon anahtarları |
| `@Environment` | Sistemin sağladığı bir değeri okur (renk şeması, "hareketi azalt" ayarı vb.) | `accessibilityReduceMotion` |
| `@Namespace` | Farklı View'lar arası animasyon eşleştirmesi için ortak bir "kimlik alanı" | Liste → detay yakınlaştırma geçişi |

### `enum` ve "durum makinesi" (state machine)

```swift
enum WeatherViewState: Equatable {
    case idle
    case loading
    case success(CityWeather)   // "associated value" — case'in yanında veri taşıyor
    case error(String)
}
```

Bir ekranın olabileceği TÜM durumları tek bir yerde topluyoruz. `switch viewModel.state { case .success(let weather): ... }`
yazınca, Swift bize "başka bir durumu unutmadın mı" diye derleme zamanında (compile-time) haber verir.
Bu, "hem yükleniyor hem hata var" gibi imkansız durumların oluşmasını baştan engelliyor.

---

## 3. Dosya Dosya Açıklama

### `WeatherAppApp.swift`
Uygulamanın giriş noktası (`@main`). `WeatherViewModel`'i burada TEK BİR KERE yaratıp
`.environmentObject(...)` ile tüm alt ekranlara veriyoruz, doğrudan `HomeView`'ı gösteriyoruz. Ayrı bir
karşılama/"Başla" ekranı bilerek yok — konum izni sistem penceresi, `HomeView` ilk göründüğünde
otomatik geliyor (Apple'ın kendi Hava Durumu uygulamasının davrandığı gibi); `LocationManager` da
artık sadece `HomeView`'ın kendi `@StateObject`'i.

`.preferredColorScheme(.dark)`: Uygulamanın tasarımı zaten HER YERDE renkli/koyu bir arka plan +
açık renkli yazı varsayıyor (sistemin açık/koyu mod ayarına göre uyarlanan bir tasarım DEĞİL). Bu
satır olmadan, cihaz sistem AÇIK moddaysa bazı sistem kontrolleri (örn. `Picker`'ın kendi etiket
metni, varsayılan `Text` rengi) kendi "açık mod" renklerine (siyaha) dönüyordu — bu da bazı yazıların
okunaksız (siyah zemin üstünde siyah yazı gibi) çıkmasına ve `List` satırlarının bazen koyu bazen açık
karışık görünmesine (sistem, hücreleri yeniden kullanırken rengi tutarsız çözüyordu) yol açıyordu. Bu
tek satır, uygulamanın görünümünü sistem ayarından tamamen bağımsız, hep koyu modda sabitliyor.

### `Models/CityWeather.swift`
Bir şehrin o anki hava durumunu tutan ana model. `isNight` hesaplanan (computed) bir özellik:
gündoğumu/günbatımı saatleriyle şu anki zamanı karşılaştırıp gece mi gündüz mü olduğuna karar veriyor.
`systemIconName` bu bilgiyi kullanarak gece açık havada güneş yerine ay ikonu gösteriyor — ikon seçme
mantığının kendisi artık burada değil, `Utilities/WMOWeatherCode.systemIconName(for:isNight:)`'ta (bkz.
aşağısı); `DailyForecast.systemIconName` de (gece farkı olmadan) AYNI fonksiyonu çağırıyor, eskiden
ikisi ayrı ayrı, neredeyse birebir aynı switch'i tekrar yazıyordu.
`conditionCodes` API'nin döndürdüğü TÜM eş zamanlı durumları tutuyor (`conditionCode` bunun ilk/birincil
elemanı) — arka plandaki parçacık katmanı, örn. kar + sis gibi nadir ama gerçek kombinasyonları aynı
anda gösterebilsin diye. `localizedCountryName`, ülkenin ISO kodunu (`"TR"` gibi) kullanıcının sistem
diline göre okunabilir bir isme (`"Türkiye"`/`"Turkey"`) çeviriyor. `dewPoint`, sıcaklık ve nemden
Magnus-Tetens yaklaşıklığıyla hesaplanan bir computed property — ekstra bir API isteği gerektirmiyor.
`DailyForecast` ise günlük tahmin listesindeki tek bir günü temsil ediyor; `pop` o günün en yüksek
yağış olasılığı (0 ile 1 arası, ekranda yüzdeye çeviriyoruz).

**Temizlik**: `id: Int` (OpenWeather'ın şehir numarası) ve `Identifiable` uygunluğu kaldırıldı —
`CityWeather` hiçbir yerde bir listede (`ForEach`, `.sheet(item:)` vb.) TEKİL bir öğe olarak
kullanılmıyordu, hep tekil bir değer ya da isimle anahtarlanmış bir sözlük değeri (`[String: CityWeather]`)
olarak geçiyordu — yani hem alan hem protokol tamamen ölü koddu. `isFavorite: Bool` alanı da aynı
sebeple kaldırıldı: favori durumu zaten TAMAMEN ayrı bir yerden (`WeatherViewModel.isFavorite(_:)`,
isme göre) okunuyordu, bu alan hiç okunmuyor/yazılmıyordu.

### `Models/WeatherError.swift`, `AirQuality.swift`
- `WeatherError`: `LocalizedError`'a uyuyor, yani `error.localizedDescription` yerine kendi
  (`errorDescription`) mesajımızı döndürebiliyoruz — bu mesajlar da `String(localized:defaultValue:)`
  ile sistem diline göre değişiyor. "Şehir bulunamadı" ile "internet yok" artık farklı mesajlar.
- `AirQuality`: OpenWeather'ın 1-5 arası hava kalitesi endeksini yerelleştirilmiş bir etikete ve bir
  renge çeviriyor (`label`, `Text(airQuality.label)` gibi bir DEĞİŞKEN üzerinden gösterildiği için
  `String(localized:)` kullanıyor — bkz. Yerelleştirme bölümü).

### `Models/WeatherLocation.swift`
Bir yerin hava durumunu iki şekilde sorgulayabiliyoruz: `.name(String)` (klavyeden serbest metin,
MapKit onu bir koordinata çözemediğinde düşülen SON çare) ya da `.coordinate(lat:lon:displayName:)`
(arama sonucu seçildiğinde, mevcut konumda, VE artık favorilerde de — bkz. `FavoriteCity`). Koordinat
KESİN sonuç verirken isimle arama OpenWeather'ın kendi veritabanındaki tam eşleşmeye bağlı — "bazı
şehirlerin hava durumu çekilemiyor" şikayetinin kök nedeni tam olarak buydu (bkz. aşağıdaki
`LocationSearchService` ve `WeatherService` notları). `displayName`, konum türü ne olursa olsun favori
listesinde/paylaşımda kullanılacak TEK bir ismi veriyor.

**`applying(to:)` — asıl "İstanbul yerine Karaköy geliyor" düzeltmesi BURADA**: Arama tarafında
(`LocationSearchService`) koordinatı NE KADAR doğru çözersek çözelim, EKRANDA gösterilen isim aslında
`WeatherLocation.displayName` DEĞİL, `CityWeather.name` — yani OpenWeather'ın O koordinata bakıp KENDİ
veritabanından döndürdüğü isim. Büyük metropollerde (İstanbul, Londra) bu isim aradığımız şehrin
kendisi değil, o koordinata EN YAKIN kayıtlı bir semt/ilçe ("Karaköy", "Üsküdar", "Kennington" gibi)
olabiliyor — arama tarafındaki HİÇBİR düzeltme (MKLocalSearch, MKGeocodingRequest, CLGeocoder, hiçbiri)
bunu KENDİ BAŞINA çözemez, çünkü sorun bizim bulduğumuz koordinatta değil, OpenWeather'ın O koordinata
verdiği İSİMDE. Gerçek çözüm: `.coordinate` durumunda (kullanıcının zaten aradığı/seçtiği, GÜVENDİĞİMİZ
bir isim varsa) `applying(to:)`, `CityWeather.name`'i OpenWeather'ın etiketiyle DEĞİL bu `displayName`
ile DEĞİŞTİRİYOR — `WeatherViewModel.fetchWeather(for:)`, `refreshFavoriteSnapshots()` ve
`snapshotWeather(for:)` HEPSİ bu fonksiyonu çağırıyor. Bunun için
`CityWeather.name` `let` değil `var` yapıldı. `.name` durumunda (elimizde GÜVENİLİR bir kullanıcı
seçimi yok) bu müdahale YAPILMIYOR — API'nin kendi ismi zaten elimizdeki en iyi bilgi.

### `Models/FavoriteCity.swift`
**Yaşanan bir hata**: Favoriler eskiden sadece bir isim dizisiydi (`[String]`) — bir favoriye her
girildiğinde (favoriler listesinden dokunulduğunda ya da arka planda `refreshFavoriteSnapshots()`
çalıştığında) o isim OpenWeather'a TEKRAR soruluyor, yeniden bir koordinata çözülüyordu. Türkiye'de il
ile aynı adı taşıyan şehirlerde ("Kayseri" hem il hem şehir, "Kahramanmaraş" da öyle) OpenWeather'ın
isimle arama sonucu bazen şehrin kendisi yerine İLİN merkezine yakın ama FARKLI bir noktaya
düşebiliyor — kullanıcı "favorilerimde Kahramanmaraş Province çıkıyor, gerçek şehirle arasında 5 derece
fark var" diye fark etti. Bu, arama ekranı için zaten çözülmüş olan (`WeatherLocation.coordinate`)
AYNI sorunun favorilere hiç uygulanmamış hâliydi.

**Çözüm**: `FavoriteCity` artık isimle BİRLİKTE koordinatı da (`lat`/`lon`, opsiyonel) saklıyor. Bir
favori eklendiği ANDAKİ (zaten doğru şekilde yüklenmiş) `CityWeather.lat`/`lon` kalıcı olarak
kopyalanıyor — `location` computed property, koordinat biliniyorsa HER ZAMAN `.coordinate(...)`
döndürüyor, bir daha asla isimle yeniden aramıyor. Koordinat yoksa (bu düzeltmeden ÖNCE eklenmiş eski
bir favoriyse) `.name(...)`'e düşüyor — eskisi gibi davranmaya devam ediyor, ama artık yeni eklenen
HİÇBİR favori bu soruna düşmüyor. Eski/bozuk bir favoriyi düzeltmenin yolu: silip arama üzerinden
yeniden eklemek (bu sayede koordinat kilitli hâle gelir).

### `Models/WeatherConditionCategory.swift`
Favori listesi filtresi için KABA bir sınıflandırma (`clear`/`cloudy`/`rain`/`storm`/`snow`/`fog`) —
`CityWeather.systemIconName`/`WeatherParticleStyle`'daki ince ayrımlardan (drizzle/rain/storm gibi)
BİLEREK ayrı tutuyoruz; bir filtre seçeneği o kadar ince olmamalı, kullanıcı sadece "yağmurlu" görmek
istiyor, drizzle ile storm'u ayrı seçenek olarak sunmak gereksiz karmaşıklık olurdu. `WeatherFilter`,
kategori seçimini VE sıcaklık aralığını (her zaman Celsius saklanıyor, ekranda tercih edilen birime
çevriliyor) tutan, `matches(_:)` ile bir `CityWeather?`'ın filtreye uyup uymadığına karar veren saf bir
struct — bu kontrol artık HomeView'ın listesini anlık daraltmıyor, sadece "Uygula"ya basıldığında
`FilterResultsView`'ın sonuçları hesaplarken kullanılıyor (bkz. aşağısı).

### `Services/LocationManager.swift`, `Services/LocationSearchService.swift`
- `LocationManager`: `CLLocationManager`'ı sarmalıyor, konum izni ister ve `location`
  (`CLLocationCoordinate2D?`) ile yeni `MKReverseGeocodingRequest` (iOS 26) üzerinden çözümlenen
  `displayLocationName` gibi yayınlanmış (published) değerler sunuyor.
  `refreshAuthorizationStatusIfNeeded()`: kullanıcı uygulama ARKA PLANDAYKEN sistem Ayarlar'ından
  konum iznini değiştirip geri dönebiliyor; `CLLocationManager`'ın kendi delegate geri çağrımı
  (`locationManagerDidChangeAuthorization`) bu durumu her zaman güvenilir şekilde haber vermiyor. Bu
  yüzden `HomeView`, `scenePhase` her `.active` olduğunda bu metodu çağırıyor: metot
  `manager.authorizationStatus`'u AÇIKÇA yeniden okuyup önceki değerle karşılaştırıyor — durum
  GERÇEKTEN değiştiyse (yeni izin verildi/geri alındı) harekete geçiyor (konum güncellemesini
  başlatıyor ya da eski konumu temizliyor), değişmediyse hiçbir şey yapmıyor. Bu, "ne zaman konum
  güncellendi, ne zaman API isteği atmalıyım" sorusunu net bir kurala bağlıyor: SADECE durum
  gerçekten değiştiğinde.
- `LocationSearchService`: `MKLocalSearchCompleter`'ı sarmalıyor (kullanıcı yazdıkça öneri listesi —
  bu kısım hiç değişmedi). `resolve(_:)` ve `resolve(freeText:)`, seçilen öneriyi ya da yazılan serbest
  metni TAM bir konuma (enlem/boylam + `MKMapItem`'ın kendi verdiği kanonik isim) çözüyor; bu çözümleme
  başarısız olursa (nadiren) sessizce isimle aramaya (`.name(fallbackName)`) düşüyor. Bu, arama
  sonuçlarının isim yerine koordinatla sorgulanmasını sağlayan asıl mekanizma.

  **Yaşanan bir hata (üç denemede çözüldü)**: "İstanbul" yazıp seçince "Karaköy", "Kadıköy" yazıp
  seçince "Üsküdar" gibi, aranan/seçilen yer DEĞİL, komşu bir semt/ilçe geliyordu — üstüne bir de
  bazı aramalar YAVAŞ (onlarca saniye) çalışıp "veri okunamadı" hatası veriyordu.
  1. İLK denemede kök nedeni "`MKLocalSearch`'ün döndürdüğü ilk sonuç yanlış" sanıp sonuçlar arasında
     isim eşleşmesi ARAMAYA çalıştık — YETMEDİ, çünkü `MKLocalSearch` bir POI/İŞLETME arama motoru;
     geniş bir yerleşim ismi verildiğinde şehrin/ilçenin KENDİSİNİ hiç döndürmeyebiliyordu.
  2. İKİNCİ denemede iOS 26'nın YENİ `MKGeocodingRequest`'ine geçtik — ama CANLI testte hem YAVAŞ
     çalıştı hem de HATA verdi hem de SPESİFİK bir arama ("Kadıköy") bile YANLIŞ, komşu bir sonuca
     ("Üsküdar") çözülebildi. Yani bu API da güvenilir çıkmadı.
  3. GERÇEK/kalıcı çözüm: `CLGeocoder` — Apple'ın 10+ yıldır TAM OLARAK bu iş (isim/adres → koordinat)
     için kullanılan, olgun ve MapKit'in POI aramasına hiç BULAŞMAYAN klasik API'si. iOS 26'da
     DEPRECATED işaretli (yerine `MKGeocodingRequest` öneriliyor) ama BİLİNÇLİ bir tercih: yeni API
     canlı testte güvenilmez çıktı, eski API on yıllardır KANITLANMIŞ — burada doğruluk, bir derleyici
     uyarısından daha ÖNEMLİ. Aynı isim-eşleştirme güvence katmanını (`.folding(...)`, Türkçe İ/ı için)
     koruduk. Burada `displayName`'i `fallbackName`'e SABİTLEDİK — ama bu TEK BAŞINA sorunu ÇÖZMEDİ,
     kullanıcı "İstanbul arayıp tıklayınca hâlâ Karaköy geliyor" diye BİLDİRMEYE devam etti!
  4. **Asıl kök neden BAŞKA YERDEYMİŞ**: bu dosyadaki `displayName` hiçbir zaman EKRANA basılan isim
     DEĞİLMİŞ — ekranda gösterilen `CityWeather.name`, yani OpenWeather'ın koordinata bakıp KENDİ
     veritabanından döndürdüğü isim. Koordinatı ne kadar doğru bulursak bulalım, OpenWeather o
     koordinatı KENDİ etiketiyle ("Karaköy" gibi) döndürüyordu — bu servisin çözdüğü isim hiç
     KULLANILMIYORDU bile. Gerçek düzeltme `Models/WeatherLocation.swift`'teki `applying(to:)`'ta
     (bkz. o bölüm) — `CityWeather.name`'i BURADAKİ `displayName` ile değiştiriyor.
  5. **Bir ayrıntı daha çıktı**: isim ARTIK doğru şehri gösteriyordu ama BİLEŞİK/hiyerarşik geliyordu —
     "İstanbul, İstanbul, Türkiye", "Beşiktaş, İstanbul, Türkiye" gibi. Sebep: şehir İLE il/provins
     ismi AYNI olan yerlerde (İstanbul HEM şehir HEM il) MapKit'in completer'ı `title`'ı BİLEREK
     hiyerarşik veriyor. Çözüm: `shortName(from:)` — `displayName` İÇİN kullanılan METNİ, virgülle
     ayrılmış İLK parçaya (gerçek yer ismi) indirgiyoruz; GEOCODING İÇİN gönderilen METİN ise (`text`
     parametresi) HÂLÂ TAM hiyerarşik hâliyle kalıyor — daha İYİ bir konum çözümlemesi için MapKit'e
     mümkün olduğunca FAZLA bağlam (il/ülke) vermeye devam ediyoruz, sadece EKRANDA gösterileni
     sadeleştiriyoruz.
  6. **CLGeocoder'dan `MKGeocodingRequest`'e geri dönüş**: Xcode, `CLGeocoder`/`geocodeAddressString`
     için "iOS 26.0'da kullanımdan kaldırıldı" uyarısı vermeye devam ediyordu — derleme başarılı olsa
     da bu uyarıları temizlemek istedik. Yukarıdaki 2. maddede `MKGeocodingRequest`'i canlı testte
     güvenilmez bulup terk etmiştik, ama asıl sorunun kaynağı (4. madde) o zaman zaten `LocationSearchService`
     DEĞİL, `Models/WeatherLocation.swift`'teki isim eşlemesiymiş — yani `MKGeocodingRequest`'in kendisi
     hiç suçlu değilmiş. `displayName`'i zaten `fallbackName`'e sabitlediğimiz ve isim eşleştirme
     güvence katmanını (`.folding(...)`) koruduğumuz için, koordinatı sağlayan API'nin `CLGeocoder` ya
     da `MKGeocodingRequest` olması sonucu pratikte değiştirmiyor. Bu yüzden `MKGeocodingRequest`'e geri
     döndük: `MKGeocodingRequest(addressString:)` ile istek kuruyoruz, `try await request.mapItems`
     (bu, Objective-C tarafındaki completion-handler'lı metodun Swift'e `async throws` bir computed
     property olarak yansımış hâli) ile `[MKMapItem]` alıyoruz; eski `placemark.name`/`placemark.locality`
     karşılaştırması artık `mapItem.name`/`mapItem.addressRepresentations?.cityName` üzerinden, eski
     `placemark.location` de `mapItem.location` (artık optional bile değil) üzerinden yapılıyor. Mantık
     birebir aynı kaldı, sadece deprecated API'nin yerini iOS 26'nın kendi MapKit isteği aldı.

### `Services/WeatherService.swift`
**İKİ SAĞLAYICILI mimari** (bu turda değişti — bkz. gerekçe aşağıda): OpenWeather artık SADECE
"neresi" sorusuna (isim/ülke/koordinat) cevap veriyor; asıl hava durumu SAYILARI (sıcaklık, nem,
rüzgar, günlük/saatlik tahmin) **Open-Meteo**'dan (`api.open-meteo.com`, tamamen ücretsiz, API anahtarı
bile gerektirmiyor) geliyor.

**Neden değişti**: OpenWeather'ın ücretsiz güncel-hava-durumu uç noktasındaki `temp_min`/`temp_max`
alanları GERÇEK günlük en düşük/en yüksek değil — kendi belgelerinde de "o anki ölçüme yakın bir
değer" olduğu belirtiliyor. Büyük şehirler dışında (küçük/orta ilçeler gibi) bu değer neredeyse
anlamsızlaşıyor ve her istek attığında (sıcaklık gerçekte değişmese bile) sıçrayabiliyor — "Kahramanmaraş
birden 37'den 31'e düştü" gibi şikayetlerin kök nedeni tam olarak buydu. Open-Meteo'nun günlük
değerleri ise o günün TÜM saatlik model verisinin gerçek toplamı/özeti; küçük yerleşimlerde de
tutarlı kalıyor. Open-Meteo bir "şehir arama" servisi SUNMUYOR (sadece enlem/boylam kabul ediyor) —
OpenWeather'ın isim/koordinat çözümlemesi zaten kanıtlanmış ve sorunsuz çalıştığı için o kısmı
değiştirmeye gerek yoktu, sadece hava durumu sayılarını daha güvenilir bir kaynağa taşıdık.

**Akış**: `fetchWeather(for cityName:)` / `fetchWeather(lat:lon:)` önce `fetchLocationIdentity(urlString:)`
ile OpenWeather'dan `name`/`country`/`coord` çekiyor (bu, isimle aramada OpenWeather'ın kendi
veritabanındaki tam eşleşmeye bağlı kalmaya devam ediyor — ama artık SADECE kimlik için, hava durumu
verisi için değil), sonra o koordinatla `fetchWeather(identity:)` ile Open-Meteo'ya tek bir istek
atıyor. Open-Meteo'nun cevabı `current` + `hourly` + `daily`'yi TEK seferde veriyor — bu üçü artık
`WeatherBundle` adlı küçük bir paket içinde birlikte dönüyor (bkz. aşağısı), ViewModel artık İKİ AYRI
ağ isteği (önce güncel durum, sonra tahmin) yapmak zorunda değil. (Temizlik: OpenWeather'ın döndürdüğü
`id` alanı `LocationIdentityResponse`/`LocationIdentity`'den `CityWeather`'a kadar taşınıyordu ama
hiçbir yerde okunmuyordu — tüm zincirden kaldırıldı.)

Hepsi aynı deseni izliyor: URL kur → `URLSession.shared.data(from:)` ile veriyi çek → `JSONDecoder` ile
API'nin verdiği alan adlarıyla eşleşen `private` DTO (Data Transfer Object) struct'larına çöz → o
DTO'yu bizim asıl modelimize (`CityWeather`/`HourlyForecast`/`DailyForecast`) dönüştür. DTO'ların hepsi
`private` çünkü sadece bu dosyanın bir iç detayı; dışarıya asla sızmıyorlar.

`requestData(from:)` tüm fonksiyonların tekrarladığı `URLSession` çağrısını tek yere topluyor ve
bağlantı hatalarını `WeatherError.network`'e çeviriyor.

**Zaman ayrıştırma**: Open-Meteo'nun `time` dizileri ("2026-08-03T14:00" gibi) `timezone=auto`
sayesinde ZATEN o konumun kendi yerel saatinde geliyor. `formatter(dateFormat:timeZone:)` bu metinleri,
cihazın DEĞİL konumun kendi UTC farkına (`utc_offset_seconds`, API'nin döndürdüğü) göre mutlak bir
`Date`'e çeviriyor — `en_US_POSIX` locale'i, sabit biçimli bir tarih ayrıştırmanın cihazın bölgesel
ayarlarından etkilenmemesi için standart bir güvenlik önlemi. Saatlik ("yyyy-MM-dd'T'HH:mm") ve günlük
("yyyy-MM-dd") ayrıştırma eskiden iki ayrı, neredeyse birebir aynı fonksiyondu (`dateTimeFormatter`/
`dayFormatter`); format string'i parametre yapıp TEK fonksiyona indirdik.

**Hava kodu**: OpenWeather'ın kendi kod seti yerine artık Open-Meteo'nun standart WMO (Dünya
Meteoroloji Örgütü) kodu geliyor — bunu `WMOWeatherCode.legacyConditionCode(for:)` ile uygulamanın
geri kalanının (ikon, arka plan rengi, parçacık efekti, filtre) hâlâ bildiği ESKİ OpenWeather aralık
mantığına çeviriyoruz (bkz. `Utilities/WMOWeatherCode.swift`), böylece o dosyaların HİÇBİRİNE
dokunmamıza gerek kalmadı. Open-Meteo hazır bir açıklama metni de vermiyor (sadece sayısal kod), bu
yüzden `conditionDescription`'ı artık KENDİMİZ üretiyoruz (`WMOWeatherCode.localizedDescription(for:)`)
— bu aslında OpenWeather'ın çevirisine güvenmekten daha tutarlı, çünkü doğrudan uygulamanın kendi
`Localizable.xcstrings` kataloğundan geliyor.

**Kaybolan bir ayrıntı**: OpenWeather bazen `weather` dizisinde aynı anda birden fazla durum
döndürebiliyordu (kar + sis gibi, nadir ama gerçekti) — Open-Meteo tek bir `weather_code` veriyor, bu
yüzden `conditionCodes` artık her zaman TEK elemanlı. `WeatherParticleStyle`'ın çoklu katman gösterme
YETENEĞİ hâlâ tamamen duruyor (kod silinmedi), sadece artık nadiren birden fazla stille tetiklenecek.
Sıcaklık doğruluğu kazanımı yanında kabul edilebilir bir ödün.

**Rüzgar birimi**: Open-Meteo'ya `wind_speed_unit=kmh` parametresiyle istekte bulunuyoruz — API rüzgar
hızını doğrudan km/s cinsinden veriyor, uygulamanın geri kalanının zaten varsaydığı birimle (bkz.
`WindSpeedUnit`) baştan tutarlı.

**Hava kalitesi değişmedi**: `fetchAirQuality(lat:lon:)` hâlâ OpenWeather'ın ayrı, ücretsiz
`air_pollution` uç noktasını kullanıyor — bu hiç şikayet konusu olmadığı ve zaten sorunsuz çalıştığı
için dokunmadık.

**`WeatherServiceProtocol.fetchWeather(at:)`**: protokolün kendi `extension`'ı — `WeatherLocation`'ın
`.name`/`.coordinate` durumuna göre hangi somut fonksiyonun çağrılacağına karar veren switch'i TEK bir
yerde topluyor. `WeatherViewModel`'in üç fonksiyonu da (`fetchWeather`, `refreshFavoriteSnapshots`,
`snapshotWeather`) bu tek uzantıyı çağırıyor — aynı switch üç farklı yerde tekrar tekrar yazılmıyor.

### `Utilities/WMOWeatherCode.swift`
Open-Meteo'nun standart WMO hava kodunu (0-99) uygulamanın geri kalanının bildiği ESKİ OpenWeather
aralık mantığına (`legacyConditionCode(for:)`) ve kendi ürettiğimiz yerelleştirilmiş bir açıklama
metnine (`localizedDescription(for:)`) çeviren küçük, durumsuz bir yardımcı. Tek amacı bu köprüyü
kurmak — `CityWeather.systemIconName`, `WeatherConditionCategory`, `WeatherPalette`,
`WeatherParticleStyle` gibi ikon/renk/parçacık/filtre mantığının HİÇBİRİNE dokunmadan Open-Meteo'ya
geçebilmemizi sağladı (bkz. `WeatherService.swift`'teki gerekçe notu).

Ekrandaki ikonun adını seçen `systemIconName(for:isNight:)` de buraya taşındı — `CityWeather` (gece
farkı var) ile `DailyForecast` (hep gündüz ikonu) aynı switch'i neredeyse birebir tekrar ediyordu,
tek yere toplayıp `isNight` parametresine varsayılan `false` verdik.

**Not**: Bu proje genelinde varsayılan aktör izolasyonu MainActor olduğu için (`SWIFT_DEFAULT_ACTOR_ISOLATION`),
sadece `static` fonksiyonlar içeren bu `enum` bile MainActor'a kayıyordu — nonisolated `WeatherService`
içinden senkron çağrıldığında derleyici uyarısına yol açıyordu. `nonisolated enum` olarak işaretleyip
çözdük (aynı DTO'larda yaptığımız düzeltmenin bir benzeri).

**Yerelleştirme tuzağı (yaşanan bir hata)**: Bu dosyadaki `String(localized: "wmo.rain", defaultValue: "Yağmurlu")`
gibi çağrıları `Localizable.xcstrings`'e eklerken sadece "en" (İngilizce) çeviriyi elle yazmıştım,
KAYNAK dil olan "tr" için ayrı bir `stringUnit` eklemeyi atlamıştım — projedeki HER ÖNCEKİ anahtarda
(örn. `error.city_not_found`) hem "en" hem "tr" için ayrı birer kayıt var, bu yüzden bu bir istisna/
tutarsızlıktı. Sonucu: cihaz Türkçe olsa bile şehir detay ekranındaki hava durumu yazısı ("Yağmurlu"
gibi) İngilizce ("Rainy") görünüyordu — çünkü katalogda "tr" için hiç kayıt yoktu, sistem de mevcut
TEK çeviriye (İngilizce) düşüyordu. Çözüm: her `wmo.*` anahtarına, defaultValue ile BİREBİR aynı
metni taşıyan bir "tr" kaydı (`"state": "new"`) eklemek — artık her yeni sembolik anahtar eklerken bu
ikisini birlikte yazmak gerekiyor, sadece "en" yetmiyor.

### `Utilities/RelativeDayFormatter.swift`
Gün isimlerini artık sistem diline göre gösteriyor (`Locale.autoupdatingCurrent`) — eskiden
`Locale(identifier: "tr_TR")` ile sabitlenmişti, uygulama tüm dillerde çalışacağı için bu kaldırıldı.
Bugün için "Bugün"/"Today", yarın için "Yarın"/"Tomorrow" özel durumu var (bu iki kelime de
`String(localized:)` üzerinden geliyor), gerisi haftanın günü ismi.

### `Utilities/PercentFormatting.swift`
Küçük ama önemli bir detay: Türkçe'de yüzde işareti sayının ÖNÜNDE ("%40"), İngilizce'de SONUNDA
("40%") yazılır. `Int.percentFormatted`, bunu düz string birleştirme yerine yerelleştirilmiş bir
format dizesiyle (`format.percent` anahtarı) çözüyor — dil değişince sıra da doğru değişiyor.

### `ViewModels/WeatherViewModel.swift`
Uygulamanın beyni. `state` o an ekranda ne gösterileceğini belirliyor (yükleniyor/başarılı/hata).
`fetchWeather(for location: WeatherLocation)` artık düz bir isim değil, `.name`/`.coordinate` seçenekli
bir `WeatherLocation` alıyor. Servisten dönen tek bir `WeatherBundle` (`current`/`hourly`/`daily`
birlikte) üzerinden hem `state` hem `hourlyForecast` hem `dailyForecast` dolduruluyor — eskiden bunun
için İKİ AYRI servis çağrısı (önce güncel durum, sonra ham tahmin listesi) gerekiyordu, Open-Meteo
ikisini birlikte verdiği için artık tek çağrı yetiyor. `.name`/`.coordinate` dallanması artık burada
DEĞİL — `WeatherServiceProtocol.fetchWeather(at:)` (bkz. `WeatherService.swift`) bunu TEK bir yerde
topluyor, `.name`/`.coordinate` switch'i tek bir yerde yaşıyor. `favoriteSnapshots`,
favori şehirlerin en son bilinen hava durumunu bir sözlükte
(`[String: CityWeather]`) tutuyor ki Home ekranındaki liste her açıldığında yeniden ağ isteği atmadan
sıcaklık/ikon gösterebilsin. `preferredUnit`, Celsius/Fahrenheit seçimini tutuyor; API'den HER ZAMAN
Celsius alıyoruz, Fahrenheit'a sadece ekranda (`TemperatureUnit.format`) çeviriyoruz — birim
değiştirmek için ağa tekrar gitmiyoruz. `preferredWindUnit` de aynı mantıkla km/s ↔ mph arasında
sadece EKRANDA çeviriyor (`WindSpeedUnit.format`).

**`savedCities: [FavoriteCity]`**: eskiden `[String]`'di, artık her favori isim+koordinat taşıyor
(bkz. `Models/FavoriteCity.swift` — favorilerin neden koordinat kilitli hâle getirildiğinin tam
gerekçesi orada). Diskteki eski format (`UserDefaults`'ta düz bir isim dizisi) otomatik olarak
`loadSavedCities()` içinde okunup koordinatsız `FavoriteCity`'lere çevriliyor — kullanıcı hiçbir şey
kaybetmiyor, sadece o favoriler koordinat kilidine kavuşana kadar (silinip yeniden eklenene kadar)
eski (isimle arama) davranışını sürdürüyor.

`toggleFavorite(name:weather:)`: bir şehir favoriye eklenirken `weather` parametresi ZORUNLU (nil
olamaz, favori eklenmez) — çünkü favoriyi doğru koordinatla kilitleyebilmemiz için elimizde zaten
yüklenmiş bir `CityWeather` olması şart. Çıkarırken (`weather: nil` geçilir) buna ihtiyaç yok, sadece
isimle eşleştirip listeden siliyor. Ekleme anında, `state` içindeki ZATEN yüklü veriyi (genelde tam
olarak budur — kullanıcı WeatherView'dayken yıldıza basıyor) HEMEN `favoriteSnapshots`'a da yazıyoruz.
Eskiden bu satır yoktu: favori eklenince Home ekranına dönüldüğünde satır, `refreshFavoriteSnapshots()`
(pull-to-refresh) ya da bir sonraki tam yenileme gelene kadar boş (dönen bir `ProgressView`) kalıyordu
— "favoriye ekleyince derece/simgenin çıkması uzun sürüyor" şikayetinin kök nedeni tam olarak buydu.
Elimizde zaten olan veriyi kullanmak, gereksiz bir ağ isteği beklemeden anında göstermemizi sağlıyor.

`recordFreshSnapshot(_:)`: `fetchWeather(for:)`'ın İÇİNDEKİ "veri favoriyse önbelleğe yaz" mantığının
AYRI bir fonksiyona çıkarılmış hâli — `fetchWeather(for:)` başarılı olduğu HER an otomatik çağrılıyor
(bkz. altta), bu yüzden `WeatherView`'da hangi şehir gösteriliyorsa (favori listesinden ya da alt
şeritten seçilmiş olsun) o şehrin taze verisi favoriler listesine de HER ZAMAN anında yansıyor. Bu
fonksiyon artık `public` kalmaya devam ediyor ama ayrıca bir yerden ELLE çağrılmıyor — mimari
sadeleştikten (bkz. `Views/WeatherView.swift` bölümündeki not) sonra `fetchWeather(for:)` TEK giriş
noktası oldu.

### `DesignSystem/Typography.swift`
Uygulamanın tek bir tipografi kimliği olsun diye `Font` üzerine adlandırılmış sabitler ekliyoruz
(`.weatherHero`, `.weatherCardTitle` gibi). Önce `.rounded`, sonra düz `.default` denedik — ama rakamlarda
ikisi neredeyse AYNI göründüğü için (rounded/default farkı harflerde belirgin, rakamlarda çok az) font
değişikliği fark edilmiyordu. Şimdi Apple'ın kendi News/Journal/Stocks gibi uygulamalarında kullandığı
eşleştirmeyi uyguluyoruz: **New York (serif) SADECE sayısal değerlerde** (sıcaklık, nem, basınç gibi —
`weatherHero`, `weatherCityName`, `weatherCardValue`, `weatherRowTemperature`, `weatherTemperatureSmall`),
**San Francisco (sans) ise TÜM etiket/başlık/UI metinlerinde**. Bu ikili karşıtlık hem her sayı
göründüğünde anında fark ediliyor hem de Apple'ın kendi tipografi dilinden (first-party bir font
eşleştirmesi) kopmuyor. `Text.weatherLabelStyle()`, büyük harfli kart etiketlerine ("HUMIDITY" gibi)
geniş harf aralığı (tracking) ekleyip Apple'ın "sistem etiketi" hissini tamamlıyor. Hepsi semantic
boyutlarla (`.title`, `.caption` gibi) kurulu, yani Dynamic Type ile birlikte büyüyüp küçülüyor.

`weatherBrandWordmark`: sadece `BrandHeader`'daki "Nuve" yazısı için — hero sıcaklıkla AYNI serif
aileden ama küçük boyutta, marka yazısına biraz editöryel bir karakter katıyor.

### `DesignSystem/BrandHeader.swift` ve Uygulama İkonu
Ana ekranın gezinme çubuğundaki düz `"Nuve"` yazısı (kullanıcının kendisinin "Hava Durumu" başlığının
yerine koyduğu metin) çok sıradan duruyordu. `BrandHeader`, bunun yerine `.principal` konumuna
yerleştirilen özel bir View: uygulamanın kendi işareti (`Assets.xcassets/BrandMark` — küçük bir yörünge
halkasıyla sarılmış bir küre, aşağıda anlatılan uygulama ikonuyla AYNI motif) + geniş harf aralıklı,
ince bir "Nuve" yazısı yan yana duruyor. `navigationTitle("Nuve")` kod tarafında hâlâ duruyor ama artık
SADECE VoiceOver duyurusu ve bu ekrandan başka bir sayfaya geçildiğinde "geri" butonunun etiketi için —
görsel olarak `BrandHeader` onun yerini alıyor.

**Uygulama ikonu**: Önceden boş slotlardı (bkz. eski "Daha Sonra Eklenebilecekler" notu). Artık üç
görünüm (`icon-light`, `icon-dark`, `icon-tinted` — iOS 18+'ın açık/koyu/tek renkli "tinted" simge
modlarının üçü de) `AppIcon.appiconset` içinde dolu. Motif TAMAMEN özgün: gradyan bir zemin (gece/gündüz
kimliğiyle aynı ruhta, lacivertten sıcak turuncuya) üstünde beyaz bir küre + onu yörünge gibi saran ince,
kesik bir halka + halkanın bir ucunda küçük bir "uydu" noktası. Bilinçli olarak ne bir güneş/bulut/ay
(Apple Hava Durumu'nun kendi dili) ne de klişe bir hava durumu simgesi — "atmosfer/yörünge" hissi veren,
soyut ve kendine özgü bir işaret. `BrandMark` görüntü seti aynı motifin şeffaf/tek renkli (template)
hâli — uygulama içinde `.renderingMode(.template)` ile istenen renge boyanabiliyor, `BrandHeader` bunu
kullanıyor.

### `DesignSystem/GlassCard.swift`
Tüm cam kartların TEK ortak tanımı. Eskiden her yerde ayrı ayrı `.glassEffect(...)` çağrılıyordu; hem
tekrar hem de parlak arka planlarda (açık gündüz turuncusu gibi) beyaz yazının okunması zordu.
`.weatherGlassCard()` camı hafifçe karartıyor (`.tint(.black.opacity(...))`) — arka plan ne kadar
parlak olursa olsun kontrast sabit kalsın diye — artı ince bir kenarlık ve yumuşak bir gölge ekliyor.
Opsiyonel `accentTint` parametresi verilirse (örn. nem kartı için `.blue`), kartın arkasına o renkte
yumuşak bulanık bir parıltı ekleniyor ve kenarlık o rengin tonuna bürünüyor — kutunun kendisi de artık
sadece ikonla değil, hafif bir renk kimliğiyle tanınıyor. `WeatherDetailBox`/`WindDetailBox`/
`SunTimesBox`/`AirQualityCard` her biri kendi ikon rengini (`iconColor`) `accentTint` olarak veriyor.

**Dokunma alanı düzeltmesi (`.contentShape`)**: Bir kart bir `Button`/`NavigationLink`'in etiketiyse,
SwiftUI varsayılan olarak sadece İÇERİĞİN (yazı, ikon gibi) kapladığı alanı dokunulabilir sayar —
kartın `.frame(maxWidth: .infinity)` ile doldurduğu boş kısımları DEĞİL. Bu yüzden arama sonucu
kartlarında "isim yazan yere dokununca açılıyor ama sağındaki boş alana dokununca hiçbir şey olmuyor"
gibi bir hataya yol açıyordu. Modifier zincirinin sonuna eklenen
`.contentShape(.rect(cornerRadius: cornerRadius, style: .continuous))`, kartın TÜM görünür alanını
(görünen köşe yuvarlaklığıyla birebir) dokunulabilir yapıyor. Bu düzeltme TEK bir yerde (burada)
yapıldığı için uygulamadaki her kart (favori satırı, arama sonucu, konum kartı, filtre sonucu
şehirleri...) otomatik olarak düzeliyor — ayrı ayrı her View'da tekrarlamaya gerek kalmadı.

**`hiddenListRow(insets:)`**: `List` satırlarının varsayılan beyaz arka planını/ayırıcı çizgisini
gizleyen `.listRowBackground(Color.clear) + .listRowSeparator(.hidden)` üçlüsü (bazen özel bir
`.listRowInsets(...)` ile birlikte) `HomeView`, `WeatherFilterView`, `SettingsView`,
`FilterResultsView`'da tek tek, aynen tekrar ediliyordu (12+ yerde). Tek bir View uzantısına
topladık — `insets` verilmezse sistemin varsayılan satır boşluğu korunuyor, verilirse (camlı bir kart
satırı gibi) o boşluk uygulanıyor. `@ViewBuilder` kullanılmasının sebebi: iki dal (`if let`/`else`)
farklı somut View tipleri döndürüyor, `@ViewBuilder` bunları tek bir `some View` altında birleştiriyor.

### `DesignSystem/WeatherBackground.swift`
- `WeatherPalette`: hava koduna VE gece/gündüz bilgisine göre iki renkli bir gradyan seçiyor.
  `chromeColors`, Ayarlar/Filtre/Sonuçlar gibi hava durumuna bağlı olmayan ekranlar için nötr bir
  palet — parlak hava durumu renklerini ödünç almıyor (okunabilirlik + kendine has kimlik).
  **Yaşanan bir hata**: bu palet eskiden `static let` ile SABİT, hep aynı koyu lacivertti — gündüz
  vakti ana ekran açık/aydınlık bir gradyanla dururken, Ayarlar'a dokununca aniden zifiri karanlığa
  düşmesi tutarsız/rahatsız edici bir GEÇİŞ hissi veriyordu. Çözüm: `chromeColors` artık `static var`
  (hesaplanan), `isCurrentlyNight` (saat 19:00-06:00 arası) durumuna göre `chromeColorsDay`/
  `chromeColorsNight` arasında SEÇİM yapıyor — ikisi de hâlâ nötr/muted tonlar (ana ekranın parlak
  turuncu/mavi gündüz renklerini KULLANMIYOR), sadece açıklık seviyesi saatle birlikte değişiyor.
  `isCurrentlyNight` artık BURADA, tek bir yerde tanımlı — eskiden `HomeView` kendi özel kopyasını
  tutuyordu, o kopya SİLİNİP `WeatherPalette.isCurrentlyNight`'a yönlendirildi (aynı hesaplamanın iki
  yerde tekrarlanmasını önlemek için).
- `WeatherParticleStyle.styles(forConditionCodes:isNight:)`: API'nin `weather` dizisi bazen birden
  fazla eş zamanlı durum döndürüyor (nadir ama gerçek — örn. kar + sis). Tekil bir stil yerine, tüm
  kodlara bakıp benzersiz stillerin listesini çıkarıyor; `WeatherParticleField` bu listedeki her stil
  için ayrı bir katmanı üst üste bindiriyor.
- `WeatherParticleLayer`: yağmur/kar/yıldız/bulut/sis/fırtına gibi hafif bir doku katmanı. Kritik nokta —
  her parçacığın konumu her karede SIFIRDAN üretilmiyor, `ParticleSeed` ile bir kere rastgele üretilip
  sonra sadece GEÇEN SÜREYE göre ileri kaydırılıyor (`sin`, `truncatingRemainder` gibi saf matematik).
  Böylece `Canvas` tek bir çizim çağrısıyla onlarca parçacığı ucuza çiziyor, zamanla artan bir bellek
  sızıntısı da olmuyor. Yağmurun düşüş açısı artık `windDeg`'e göre hafifçe eğiliyor. Her parçacığın
  ayrıca bir `depth`'i var (0 = uzak, 1 = yakın) — yakın damla/taneler daha büyük/hızlı/belirgin, uzaklar
  daha küçük/yavaş/soluk düşüyor. Bu basit "paralaks" hilesi, yeni parçacık eklemeden gökyüzüne bir
  derinlik hissi katıyor. Bulutlu havada (`.clouds`) birkaç büyük, yumuşak bulut yığını yavaşça kayıyor —
  önceden bulutlu hava hiç doku almıyordu.
- `LightningFlashOverlay`: fırtınalı havada (`.storm` stili) ekranı ara sıra kısacık aydınlatan beyaz bir
  flaş. Süreklilik yine SAF bir zaman fonksiyonundan geliyor (sabit döngü uzunluğu + kısa bir
  yükseliş/sönüş eğrisi), hiçbir durum biriktirilmiyor.
- `AmbientBackgroundView`: gradyan üstünde yavaşça kayan iki bulanık daire + kenarlara doğru hafif bir
  vinyet (`RadialGradient`) — göz ekranın ortasındaki asıl bilgiye (sıcaklık, ikon) çekiliyor.
- `WeatherBackground`: hepsini birleştirip şehir detay ekranına veriyor. Bu zenginleştirilmiş katman
  BİLEREK sadece detay ekranında var; Home ekranı sade kalıyor (pil + "detay ekranı daha özel hissettirsin" kararı).

### `Views/HomeView.swift`
Ana ekran. Arama kutusu boşken saate göre selamlama + favoriler + konum kartı, doluyken arama sonuçları
gösteriliyor. `FavoriteCityRow`/`SearchResultRow`, cam efektini `.listRowBackground` üzerinde değil,
satırın kendi İÇERİĞİNDE uyguluyor (`.weatherGlassCard()`) — `List`'in satır arka planı geometrisi cam
şeklin köşe yuvarlaklığıyla tam örtüşmediği için, eskiden arama sonuçlarında görülen hizasızlığın kök
nedeni tam olarak bu ayrımdı. `heroNamespace`, bir satıra dokunulduğunda detay ekranına "yakınlaşarak"
geçiş yapmamızı sağlıyor (`.matchedTransitionSource` + `WeatherView`'daki `.navigationTransition(.zoom(...))`
eşleşmesiyle). `LocationManager` artık burada `@StateObject` — ayrı bir onboarding ekranı olmadığı için
paylaşılmasına gerek kalmadı.

**Arama sonrası geri dönüş**: Eskiden bir sonuca dokunulunca `searchService.searchQuery = ""` ile arama
metnini TEMİZLİYORDUK — bu yüzden detay ekranından "geri" ye basınca kullanıcı arama sonuçlarını değil,
temizlenmiş/boş ana ekranı görüyordu. Artık metni temizlemiyoruz; geri dönüş tam olarak bırakıldığı
arama sonuçlarına oluyor.

**Koordinatla arama**: Bir sonuca dokunulduğunda (`selectSearchResult`) ya da klavyeden yazıp Enter'a
basıldığında (`onSubmit`), `LocationSearchService.resolve(...)` ile önce bir `WeatherLocation` çözmeye
çalışıyoruz — bu genelde `.coordinate(...)` oluyor. Mevcut konum kartı da artık `apiSearchCityName`
(isim) yerine doğrudan `locationManager.location` (koordinat) kullanıyor. Bu, "bazı şehirlerin hava
durumu çekilemiyor" sorununun kök çözümü.

**Filtre**: `filter: WeatherFilter` durumu ve `showFilter` sheet'i (`WeatherFilterView`) açılıyor.
Home'un kendi favori listesi ARTIK filtreye göre daralmıyor — filtre tamamen kendi akışında yaşıyor
(bkz. `WeatherFilterView`/`FilterResultsView`). Araç çubuğundaki filtre ikonu sadece `filter.isActive`
olup olmadığını (kullanıcının en son bıraktığı kriterler boş mu değil mi) gösteriyor.

**Saate göre selamlama + gece/gündüz arka plan**: `greeting`, günün saatine göre "Günaydın/İyi Günler/
İyi Akşamlar/İyi Geceler" arasında değişen basit bir metin; `isCurrentlyNight` de Home'un arka plan
gradyanının artık sabit "gündüz" değil, gerçek saate göre gece/gündüz arasında geçiş yapmasını sağlıyor.

**Favorilerin otomatik tazelenmesi**: Eskiden favori satırındaki sıcaklık/ikon, kullanıcı o şehre
DOKUNUP girene ya da elle aşağı çekip (pull-to-refresh) yenileyene kadar güncellenmiyordu. Artık
`.onAppear` (uygulama ilk açıldığında) VE `scenePhase` her `.active` olduğunda (uygulama arka plandan
öne her dönüşünde) `viewModel.refreshFavoriteSnapshots()` çağrılıyor — favori satırları hiçbir şeye
dokunulmadan kendiliğinden güncelleniyor. `scenePhase` geçişinde ayrıca `locationManager.
refreshAuthorizationStatusIfNeeded()` de çağrılıyor (bkz. `LocationManager` notları) — ikisi birlikte,
uygulamayı her ön plana getirdiğinde hem konum izninin hem favori verilerinin güncel olmasını sağlıyor.

**Favori satırına dokununca**: `NavigationLink(destination: WeatherView(location: favorite.location, zoomNamespace: heroNamespace, zoomSourceID: favorite.name, favorites: viewModel.savedCities))`
— arama sonucu/mevcut konumla BİREBİR aynı, sade `WeatherView` açılıyor. `favorites:` parametresi
SADECE `WeatherView`'ın kendi içindeki dokunmatik favori-değiştirme şeridine (bkz. aşağıdaki
`Views/WeatherView.swift` notu) TÜM listeyi vermek için var — burada artık bir "karusel"/kaydırma
YOK (bkz. o bölümdeki gerekçe). `ForEach`, index'e erişebilmek için `Array(...enumerated())`
kullanıyor (`FavoriteCity.id` zaten var ama index'e ayrıca ihtiyacımız var, o yüzden `id: \.element.id`).

### `Views/WeatherView.swift`
Şehir detay ekranı — ama artık SADECE "çerçeve" (chrome): arka plan (`WeatherBackground`), gezinme
çubuğu (yıldız/paylaş butonları), yakınlaşma geçişi (`.navigationTransition(.zoom(...))`), ve (favoriler
listesinden açıldıysa) altta bir favori-değiştirme şeridi. Asıl İÇERİK (hero, grafik, günlük tahmin,
detay ızgarası) artık burada DEĞİL — `WeatherStateScaffold` + `WeatherContentView` bileşenlerine
taşındı (bkz. aşağıdaki `Views/Components/` notları) — bu SADECE dosyayı kısa/okunur tutmak için,
`WeatherContentView`'ın artık başka bir tüketicisi YOK.

**Favoriler arası gezinme — kaydırma/karusel YERİNE dokunma (mimari karar)**: Bir favoriden diğerine
"kaydırarak" (swipe) geçebilmek için `FavoritesCarouselView` adında AYRI bir ekran vardı — bu, bir
şehir sayfasını yatayda kaydırılabilir yapıp üstüne kendi göstergemizi (bir isim şeridi) SABİT bir
yere yerleştirmeye çalışıyordu. ON BİR farklı teknik yaklaşım (TabView, ScrollView, overlay,
safeAreaInset, VStack, ZStack, GeometryReader, toolbar'ın `.principal` konumu ve bunların çeşitli
kombinasyonları) denendi, HİÇBİRİ canlı cihazda güvenilir/öngörülebilir çalışmadı — şerit ya içerikle
çakıştı ya ekranın ortasına düştü ya da aralarında koca bir boşluk oluştu. Kök sebep: bir YATAY
kaydırma/sayfalama katmanının (favoriler arası geçiş) İÇİNE, HER SAYFANIN kendi DİKEY kaydırma
katmanını (o sayfanın kendi içerik listesi) koymak, ve bunların ÜSTÜNE bir de SABİT bir üçüncü katman
(isim şeridi) eklemek — üç kaydırma/konumlandırma katmanının etkileşimi SwiftUI'da tutarlı sonuç
vermedi. KARAR: kaydırma/karusel jestini TAMAMEN kaldırdık — `FavoritesCarouselView.swift` ve
`ViewModels/CarouselPageModel.swift` SİLİNDİ. Favoriler artık BU ekranı (`WeatherView`), TIPKI arama
sonucu gibi, TEKİL ve SABİT açıyor. Favoriler arasında geçiş isteyen kullanıcı için bunun yerine
ekranın ALTINDA `FavoriteSwitcherStrip` var — kaydırma DEĞİL, DOKUNMA ile geçiş. Bu ekranda artık TEK
bir kaydırma katmanı (içeriğin kendi dikey listesi) olduğu için, şeridi `.safeAreaInset(edge: .bottom)`
ile yerleştirmek YUKARIDAKİ hiçbir soruna YOL AÇMIYOR — bu, tam olarak o API'nin standart/kanıtlanmış
kullanım şekli (tek bir scroll view'ın altına sabit bir çubuk eklemek).

**`favorites: [FavoriteCity]`** (varsayılan `[]`): favoriler listesinden açıldıysa TÜM liste burada;
arama sonucu/mevcut konum gibi TEKİL girişlerde boş kalıyor ve alt şerit hiç GÖRÜNMÜYOR (`favorites.count > 1`
koşulu). `@State private var activeLocation`/`activeName`: ekranda O AN gösterilen konum — `init`'te
girilen `location`'la kuruluyor, kullanıcı alt şeritten başka bir favoriye dokununca DEĞİŞİYOR.
`.onChange(of: activeName)`, yeni ismi `favorites` içinde arayıp bulduğu `FavoriteCity.location`'ı
`viewModel.fetchWeather(for:)`'a veriyor — PAYLAŞILAN `viewModel.state` yeniden dolduruluyor, AYRI bir
"sayfa modeli" gerekmiyor (eskiden bu iş için `CarouselPageModel` vardı, artık gerek yok).

`favoriteKey`: favori ekleme/çıkarma ve yıldız ikonunun durumu bu üzerinden kontrol ediliyor (veri
gelmişse `weather.name`, gelmediyse `activeLocation.displayName`).

**Yıldız butonu**: Eskiden favoriye eklenince `.scaleEffect(1.2)` ile büyüyordu — bu istenmeyen bir
"zıplama" hissi veriyordu. Artık boyut SABİT; dolgu (fill/boş) geçişindeki yumuşak animasyonu
`.contentTransition(.symbolEffect(.replace))` sağlıyor.

### `Views/WeatherView.swift` — `FavoriteSwitcherStrip` (private)
Eski karuselin YERİNE geçen, kaydırma İÇERMEYEN gezinme yöntemi: ekranın altında yatayda kayan (favori
sayısı çoksa) bir kapsül şeridi — ama sayfa DEĞİŞTİRME kaydırma JESTİYLE DEĞİL, bir kapsüle DOKUNARAK
oluyor. `ScrollViewReader`, aktif favori DEĞİŞTİĞİNDE (`onChange(of: activeName)`) o kapsülü
`.scrollTo(_:anchor: .center)` ile otomatik ORTALIYOR — kullanıcı elle kaydırmadan hep aktif favoriyi
görüyor. Aktif kapsül BEYAZ + sıcaklık gösteriyor, diğerleri SADECE isim (soluk kapsül) — tıpkı eski
`CityChipStrip`'teki görsel dil gibi, ama artık `.safeAreaInset(edge: .bottom)` üzerinden GÜVENİLİR bir
şekilde yerleşiyor (bkz. yukarıdaki mimari karar notu).

**Yaşanan bir hata (görsel ince ayar)**: `.background(.ultraThinMaterial)` doğrudan tüm şeride
uygulanınca, ekranın UCUNDAN UCUNA uzanan, köşeleri TAMAMEN keskin (yuvarlatılmamış) bir çubuk ortaya
çıkıyordu — hem kalın/ağır hem de camdan çok "katı" bir levha gibi görünüyordu. Çözüm: (1) malzemeyi
artık düz `.background(.ultraThinMaterial)` yerine `RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial)`
İLE bir arka plan olarak veriyoruz — malzeme artık YUVARLAK hatlı bir şekle KIRPILIYOR; (2) dış
`.padding(.horizontal, 16)` ile şeridi ekranın kenarlarından İÇERİ çekip YÜZEN bir hap görünümü
kazandırdık (artık ekranın tam kenarına yapışık DEĞİL); (3) iç dolgu (`.padding(.vertical, 10)` →
`6`) azaltılarak şerit daha İNCE hale geldi; (4) arka plandaki malzemeye `.opacity(0.8)` eklenerek
biraz daha ŞEFFAF hissettirildi — bu opaklık SADECE arka plan katmanına uygulanıyor, chip'lerin
kendi metni/rengi ETKİLENMİYOR.

### `Views/Components/WeatherContentView.swift`
Şehir detay içeriğinin TAMAMI (hero + 24 saatlik grafik + günlük tahmin + hava kalitesi + detay
ızgarası) burada — tamamen SAF, hiçbir ViewModel'e bağımlı değil, sadece parametre olarak verilen
`weather`/`hourly`/`daily`/`airQuality`/`unit`/`windUnit`/`lastUpdated`/`onRefresh`'i gösteriyor. Detay
ızgarasında çiğ noktası ve gündoğumu/günbatımı saatleri de var (`SunTimesBox`), hero'nun altında günün
ölçülen en düşük/yüksek sıcaklığı gösteriliyor. `WeatherDetailBox`'ın `iconColor`'ı, her ikonun kendi
anlamına uygun bir renk taşımasını sağlıyor (nem mavi, basınç mor, hissedilen turuncu gibi); aynı renk
kartın kendisine de `accentTint` olarak geçiliyor. Her detay kutusundaki
`.accessibilityElement(children: .combine)`, VoiceOver'ın ikon/etiket/değeri "Nem, %65" gibi TEK bir öğe
olarak okumasını sağlıyor. `WindDetailBox`/`WeatherDetailBox`/`SunTimesBox`'ın sabit yüksekliği 138 —
rüzgar kutusundaki hamle (gust) satırının taşmaması için üçü de aynı değerde.

**24 saatlik grafikteki etiket sıklığı**: Open-Meteo'ya geçince (bkz. `WeatherService.swift`)
`hourly` artık GERÇEK saatlik veri (24 nokta, 1'er saat arayla) — eskiden OpenWeather'ın 3 saatlik
listesinden sadece 8 nokta alıyorduk, bu da zaten x eksenindeki 3 saatlik işaretlerle örtüşüyordu. 24
noktanın HER birine bir sıcaklık etiketi koymaya devam edince etiketler üst üste binip "karman çorman"
görünüyordu. Çözüm: `AreaMark`/`LineMark` hâlâ tüm 24 noktayı kullanıyor (çizgi pürüzsüz kalsın diye),
ama `PointMark` + sıcaklık etiketi SADECE 3'e bölünen indekslerde (`index % 3 == 0`) çiziliyor — yani
eksendeki 3 saatlik işaretlerle birebir aynı hizada.

**Canlı yerel saat**: Şehir başlığının altına, o şehrin KENDİ saat diliminde (telefonun değil —
`weather.timezoneOffsetSeconds`'tan kurulan `cityTimeZone` üzerinden) her dakika kendini tazeleyen
küçük bir saat satırı eklendi. Bunu `TimelineView(.everyMinute)` sağlıyor — sistemin, dakika sınırına
TAM hizalı şekilde tetiklenen hazır bir zamanlayıcısı; elle `Timer` kurup `@State` güncellemekten hem
daha az kod hem daha pil dostu. Aynı `TimelineView`, 24 saatlik grafiğin ETRAFINI da sarmalıyor —
grafiğin içine, "şu an" konumunu gösteren kesik çizgili bir `RuleMark` eklendi, üstünde de o anki saat
yazıyor. `RuleMark`'ın x değeri gerçek `Date()` — `hourly` verisi zaten "şu andan itibaren 24 saat"
mantığıyla çekildiği için, bu çizgi grafiğin SOL ucundan başlayıp, saatler geçtikçe (her dakika
yenilendiği için) sağa doğru kayıyor.

**Yaşanan bir hata (görsel ince ayar)**: İlk halinde iki sorun vardı: (1) başlıktaki saat yazısı ÇOK
küçük/soluktü (`caption2` + `%55` opaklık), göze hiç çarpmıyordu; (2) grafikteki "şu an" çizgisinin
üstündeki saat etiketi, HEMEN üstündeki "24 SAATLİK TAHMİN" başlığıyla ÇAKIŞIP karman çorman
görünüyordu. **Çözüm**: (1) başlıktaki saat artık `weatherRowSubtitle.bold()` fontunda, %92 opaklıkla,
ince bir cam HAP (`Capsule` + hafif dolgu + ince kenarlık) içinde — uygulamanın zaten kullandığı çip
görünümüyle (bkz. `WeatherView.swift`'teki favori şeridi) TUTARLI, ama artık gerçekten göze çarpıyor.
(2) Grafikteki etiket de artık kendi küçük, yarı saydam SİYAH kapsülü içinde (`annotation(position:
.top, spacing: 2)` + `.background(Capsule().fill(.black.opacity(0.35)))`) — hem ARKA plandan (grafiğin
kendi degrade alanından) ayrışıyor hem de `Chart`'ın ÜSTÜNE eklenen `.padding(.top, 20)` sayesinde
artık başlığa DEĞMEYECEK kadar boşluğu var.

### `Views/Components/WeatherStateScaffold.swift`
`.idle`/`.loading`/`.success`/`.error` durumlarının ortak iskeleti — `WeatherView`'ın gövdesinden
BİLEREK ayrılmış, tek başına test edilebilir küçük bir View. `.loading`'de `WeatherLoadingSkeleton`
(gelecek ekranın hatlarını andıran, üzerinde ışık gezen bir yer tutucu) gösteriyoruz — boş bir döner
çark yerine kullanıcıya "birazdan böyle bir şey göreceksin" hissi veriyor. `.success` durumundaki
içerik generic bir `successContent` closure'ından geliyor (genelde `WeatherContentView`) — bu sayede
scaffold'un kendisi HANGİ içeriğin gösterileceğini bilmiyor, sadece "hangi DURUMDA ne gösterileceğini"
biliyor.

Bu dosya (`WeatherView.swift`) bir ara 500+ satıra çıkmıştı — hem ANA ekranı hem de altı farklı kart/
satır bileşenini aynı yerde tutuyordu. Mimariyi sadeleştirmek için `WeatherDetailBox`, `WindDetailBox`,
`SunTimesBox`, `DailyForecastRow`, `WeatherLoadingSkeleton` (+ içindeki `ShimmerModifier`) artık
`Views/Components/` altında kendi dosyalarında; şimdi de asıl içerik (`WeatherContentView`) ve
durum-iskeleti (`WeatherStateScaffold`) aynı şekilde ayrıştı. Aynı ayrımı `HomeView.swift` için de
yaptık: `FavoriteCityRow` ve `SearchResultRow` da `Views/Components/`e taşındı.

### `Views/Components/` (WeatherDetailBox, WindDetailBox, SunTimesBox, DailyForecastRow,
### WeatherLoadingSkeleton, FavoriteCityRow, SearchResultRow, CityWeatherRow)
Her biri tek bir dosyada, tek bir View — hiçbiri kendi başına bir "ekran" değil, bir ekranın İÇİNDE
tekrar tekrar çizilen küçük bir parça. Aralarında ortak bir mimari kural var: hiçbiri `@EnvironmentObject`
KULLANMIYOR, sadece kendilerine parametre olarak geçirilen veriyi gösteriyorlar (örn. `WindDetailBox`
bir `CityWeather` almıyor, sadece `speedKmh`/`degrees`/`gustKmh`/`unit` alıyor). Bu BİLİNÇLİ bir tercih:
bir bileşen dışarıdaki "beyne" (ViewModel) doğrudan bağımlı olmadıkça, onu Xcode Preview'ında tek
başına, farklı örnek verilerle kolayca test edebiliyoruz ve nerede kullanıldığını değiştirmeden başka
bir ekrana taşıyabiliyoruz.

**`CityWeatherRow`**: isim solda, ikon + sıcaklık sağda, hepsi `.weatherGlassCard(cornerRadius: 18)`
içinde — bu tam olarak hem `FavoriteCityRow`'un (veri geldiyse gösterdiği hali) hem de
`FilterResultsView`'daki şehir satırının görünümüydü, iki dosyada harfiyen aynı kod tekrarlanıyordu.
Şimdi ikisi de bu TEK, sade bileşeni çağırıyor. `FavoriteCityRow`, veri henüz gelmediyse (snapshot
`nil`) kendi başına bir isim + `ProgressView` satırı gösteriyor — bu "yükleniyor" durumu
`FilterResultsView`'da hiç YAŞANMIYOR (filtre sonuçları zaten yüklenmiş anlık görüntülerden anlık
hesaplanıyor, hiçbir zaman `nil`/loading olmuyor), bu yüzden `CityWeatherRow`'un kendisi opsiyonellik
taşımıyor; `FavoriteCityRow` sadece "veri var mı yok mu" dallanmasını kendi üstünde tutup varsa
`CityWeatherRow`'a devrediyor.

**`SearchResultRow`**: Eskiden MapKit'in kendi ham `completion.subtitle` metnini de (başlığın altında,
ikinci bir satır olarak) gösteriyordu. Sorun: MapKit bu metni uygulamanın kendi diline göre değil
KENDİ veritabanına göre üretiyor — Türkçe'de arama yapılsa bile bazı idari bölge sonuçlarında
"Kayseri Province, Turkey" gibi İngilizce kelimeler ("Province" gibi) çıkabiliyordu. Bunu güvenilir
şekilde temizlemek mümkün değil (uygulama artık dünya genelinde, herhangi bir sistem dilinde arama
yapılabildiği için, hangi ülkede MapKit'in hangi İngilizce idari terimi kullanacağını önceden bilemeyiz
— "Province" için özel bir filtre yazsak bile başka bir ülkede "District"/"State"/"County" gibi başka
bir terimle aynı sorun tekrar çıkardı). Bu yüzden subtitle'ı TAMAMEN kaldırdık; kart artık sadece
şehir ismini gösteriyor — daha sade ve her zaman güvenilir.

### `Views/WeatherFilterView.swift`
Filtre KRİTERLERİNİ düzenlediğimiz taslak ekran — burada hiçbir sonuç hesaplanmıyor, sadece `filter`
durumu düzenleniyor. Hava durumu kategorileri (`WeatherConditionCategory`) `ConditionChip` adlı AYRI
bir View struct olarak çiziliyor (eskiden bir fonksiyondu — her chip'in `isSelected`'ının KENDİ
parametresinden geldiğinden emin olmak ve seçili durumu çok daha belirgin göstermek için ayrı bir
struct'a çevirdik: seçiliyken dolgun beyaz arkaplan + siyah yazı + onay işareti, önceki ince opaklık
farkından çok daha net). `ConditionChip`, `GlassCard`'ı KULLANMIYOR (kendi `Capsule()` şeklini elle
kuruyor) — bu yüzden yukarıdaki aynı dokunma alanı hatasını burada da ayrıca `.contentShape(Capsule())`
ile düzelttik. Sıcaklık aralığı iki `Slider` ile gösteriliyor; `Binding`'leri KENDİ
YAZDIĞIMIZ `get`/`set` çiftleriyle kuruluyor: değer her zaman `filter` içinde Celsius saklanıyor,
kaydırıcıya gösterilirken/kaydırıcıdan okunurken kullanıcının tercih ettiği birime (`unit`) göre anlık
çeviriliyor — `min <= max` sınırı da bu `set` closure'ları içinde korunuyor. En altta bir "Uygula"
butonu var; ona basılana kadar hiçbir sonuç hesaplanmıyor/gösterilmiyor —
`.navigationDestination(isPresented: $showResults)` ile `FilterResultsView`'a geçiliyor.

### `Views/FilterResultsView.swift`
"Uygula"ya basınca gösterilen TEK ekranlı sonuç listesi. Uygulamanın elindeki tek canlı veri kaynağı
FAVORİ şehirler (dünyadaki tüm şehirleri tarayan ücretsiz bir API yok) — bu yüzden "ne kadar ülke varsa
gelsin" isteği, filtreye uyan FAVORİLERİN ülkelerine göre gruplanması olarak karşılanıyor.
`FilterResultsView`, `viewModel.savedCities` + `favoriteSnapshots`'ı `filter.matches(...)`'tan geçirip
`Dictionary(grouping:by:)` ile ülkeye göre gruplayıp `[CountryGroup]` üretiyor; her `CountryGroup` bir
`List` `Section`'ı oluyor — ülke adı SADECE bölüm başlığı (düz `Text`, dokunulamaz), altındaki şehirler
doğrudan görünüyor ve her biri bir `NavigationLink` olarak `WeatherView`'a gidiyor.

İLK TASARIMDA burada iki ayrı ekran vardı: önce bir ÜLKE listesi, ülkeye dokununca AYRI bir ekranda o
ülkenin şehirleri. Bu hem gereksiz bir ekstra adımdı hem de kafa karıştırıcı bir gezinme davranışına
yol açıyordu (ülkeye dokunulunca yeni ekranın başlığı da yine aynı ülke ismi olduğu için sanki "aynı
şey tekrar geliyor" gibi görünüyordu). Şimdi TEK bir liste var, ülke sadece bir ayırıcı/başlık.

`FilteredCity`/`CountryGroup`, sadece görüntülemek için gereken bilgiyi tutan küçük `Identifiable`
struct'lar — `CityWeather`'ın tamamını taşımak yerine sadece isim/sıcaklık/ikon/ülke/`location` gibi
gösterim ve gezinme için gereken alanları içeriyorlar. `location` alanı `favorite.location`'dan
(bkz. `FavoriteCity`) geliyor — bir şehre dokununca `WeatherView`'a KOORDİNATLA gidiliyor, tekrar
isimle aranmıyor. Her şehir satırı artık kendi `HStack`'ini elle kurmuyor, paylaşılan
`CityWeatherRow` bileşenini (bkz. `Views/Components/` notları) çağırıyor.

**Yaşanan bir hata (liste yavaşça yukarı aşağı kayıyordu)**: `groups` başta düz bir computed
property'ydi, yani `body` her çağrıldığında baştan hesaplanıyordu. Sorun şu ki `@EnvironmentObject`
kullanan bir View, ona bağlı nesnedeki HERHANGİ bir `@Published` alan değiştiğinde TÜM body'sini
yeniden çalıştırır — bu ekranla hiç ilgisi olmayan bir alan (mesela farklı bir sayfanın sıcaklık
verisi) değişse bile `FilterResultsView.body` yeniden çalışıp `groups`'u sıfırdan hesaplıyordu.
Arka plandaki `AmbientBackgroundView`'ın sürekli dönen (5 saniyelik, sonsuz tekrarlı) animasyonu
AÇIKKEN, bu sık tekrarlanan (ama İÇERİK olarak hep AYNI sonucu üreten) yeniden hesaplama, SwiftUI'ın
o an aktif olan animasyon bağlamını bu YENİ satır dizisine de uygulamasına yol açtı — kullanıcı
buna "liste yavaşça yukarı aşağı kayıyor" diye baktı. Çözüm: `groups`'u artık bir `@State` değişkeni
yaptık, sonucu `recomputeGroups()` fonksiyonuyla SADECE `.onAppear` ve `viewModel.favoriteSnapshots`/
`viewModel.savedCities` GERÇEKTEN değiştiğinde (`.onChange(of:)` ile) hesaplıyoruz — ekranla ilgisiz
bir `@Published` değişikliği artık `body`'yi tetiklese bile `groups` aynı kalıyor, liste kaymıyor.

`.toolbarColorScheme(.dark, for: .navigationBar)`: gezinme çubuğunun (navigation bar) rengini de
açıkça koyu moda sabitliyoruz. `.preferredColorScheme(.dark)` (bkz. `WeatherAppApp.swift`) çoğu şeyi
hallediyor ama gezinme çubuğunun kendi UIKit tabanlı görünümü bazen ekran ilk açıldığında kısa bir kare
boyunca kendi varsayılan rengini gösterip hemen ardından bizim temamıza geçebiliyor — bu da başlığın
kısacık siyah görünüp "titremiş" gibi hissettiriyordu. Bu satır o ilk kare titremesini ortadan kaldırıyor;
aynı satırı `HomeView`, `SettingsView`, `WeatherFilterView` ve `WeatherView`'a da ekledik.

### `Views/SettingsView.swift`
Küçük bir ayarlar sayfası: sıcaklık VE rüzgar birimi seçimi, sürüm bilgisi. `Picker`'ların `selection`
parametreleri doğrudan `viewModel.preferredUnit`/`preferredWindUnit`'e bağlı; kullanıcı seçince
ViewModel otomatik günceller ve `UserDefaults`'a yazar. Arka planı artık hava durumu renklerini DEĞİL,
`WeatherPalette.chromeColors` (nötr bir palet, artık saate göre gündüz/gece arası GEÇİŞ yapıyor — bkz.
`DesignSystem/WeatherBackground.swift`) kullanıyor — hem okunabilirlik hem tutarlı bir marka kimliği
için.

### `Views/GlassWarningView.swift`
Boş/hata durumları için tekrar kullanılan küçük bir "cam kart": ikon + mesaj. Eskiden isteğe bağlı bir
"tekrar dene" butonu da vardı ama hiçbir gerçek çağrı yeri (boş favori listesi, konum izni yok, arama
sonucu yok) bu butonu hiç kullanmadı — sadece dosyanın kendi `#Preview`'ı deniyordu. Kullanılmayan
parametreleri (`actionTitle`, `action`) ve buton dalını kaldırdık.

### `Views/AirQualityCard.swift`
Hava kalitesi endeksini küçük bir cam kartta gösteriyor; rengi endekse göre yeşilden mora kayıyor.

---

## 4. Liquid Glass Notları (iOS 26)

Eskiden her cam görünüm `.background(.ultraThinMaterial) + .cornerRadius(...)` ikilisiyle elle
yapılıyordu. iOS 26 ile gelen native `.glassEffect(.regular, in: .rect(cornerRadius:))` bunun yerini
alıyor — sistemin kendi ışık/bulanıklık motorunu kullanıyor. Artık hepsi `DesignSystem/GlassCard.swift`
içindeki tek bir `.weatherGlassCard()` modifier'ından geçiyor (bkz. yukarısı). Birden fazla kartın aynı
arka plan geçişini paylaşması gerektiğinde (`WeatherDetailBox` ızgarası gibi) hepsini tek bir
`GlassEffectContainer` içine alıyoruz; aksi halde her kart kendi başına bulanıklaştırma yapardı.
Ana çağrı-eylem (call to action) butonlarında (`"Tekrar Dene"` gibi) elle cam efekti kurmak yerine
sistemin hazır `.buttonStyle(.glassProminent)` stilini kullanıyoruz.

---

## 5. Yerelleştirme (Localization)

Uygulama artık sadece Türkçe değil — sistem dili neyse o dilde açılıyor (şu an Türkçe kaynak dil +
İngilizce çeviri var, başka bir dilse Türkçe'ye düşüyor). Bunun perde arkası:

- `Text("Ayarlar")` gibi DÜZ STRING LİTERAL'LER, SwiftUI'da otomatik olarak `LocalizedStringKey`
  üzerinden `Localizable.xcstrings` dosyasında aranıyor — kod tarafında hiçbir şey değiştirmeden
  çalışıyor. Aynı otomasyon `Button(_:)`, `.navigationTitle(_:)`, `Label(_:systemImage:)` için de geçerli.
- **Önemli bir tuzak**: bu otomasyon sadece Text/Button/vb.'e DOĞRUDAN geçirilen literal'lerde çalışıyor.
  `WeatherDetailBox(title: "NEM", ...)` gibi kendi View'larımıza bir parametre olarak geçirilen bir
  literal, parametrenin tipi `String` ise otomatik ARANMIYOR (çünkü artık o çağrı yerinde "literal"
  sayılmıyor). Bu yüzden `WeatherDetailBox.title` ve `sectionHeader(_:icon:)`'un `title`'ı bilerek
  `LocalizedStringKey` tipinde — aynı otomasyonu bu iç bileşenlere de taşımak için.
  `AirQuality.label`, `WeatherError.errorDescription` gibi bir DEĞİŞKEN üzerinden gösterilen metinler
  (`Text(airQuality.label)`) ise hiç otomatik aranmıyor; onlarda açıkça `String(localized: "anahtar",
  defaultValue: "...")` kullanıyoruz.
- Dinamik/enterpolasyonlu metinlerde (örn. "sonuç bulunamadı" mesajı, yüzde gösterimi, rüzgar hamlesi)
  enterpolasyonun ürettiği anahtarı tahmin etmek yerine `String(format: String(localized: "anahtar",
  defaultValue: "..."), deger)` deseniyle KENDİ anahtarımızı kullanıyoruz — hem daha güvenilir hem de
  Türkçe'de "%40" İngilizce'de "40%" gibi sıra farkı gerektiren durumları (bkz. `PercentFormatting.swift`)
  doğru çözebiliyor.
- `Localizable.xcstrings` (String Catalog) anahtarlarını ELLE YAZMADIM — `xcodebuild
  -exportLocalizations` ile derleyicinin koddan harfiyen çıkardığı anahtarları kullandım. Türkçe'nin
  noktalı/noktasız İ/ı harfleri (`FAVORİ` gibi) elle yazımda sessizce yanlış eşleşmeye yol açabiliyordu.
- `InfoPlist.xcstrings`, Info.plist'ten gelen (`NSLocationWhenInUseUsageDescription` gibi) metinleri
  ayrıca yerelleştiriyor — bu, genel `Localizable.xcstrings`'in kapsamadığı ayrı bir katalog.
- Hava durumu açıklaması (`conditionDescription`) artık OpenWeather'dan DEĞİL, kendi
  `WMOWeatherCode.localizedDescription(for:)`'umuzdan geliyor (bkz. `Utilities/WMOWeatherCode.swift`) —
  Open-Meteo'ya geçince bunu KENDİMİZ üretmemiz gerekti, ama bu aslında daha tutarlı: doğrudan
  uygulamanın kendi `Localizable.xcstrings` kataloğundan geliyor.
- **Marka adı istisnası**: `CFBundleDisplayName`/`CFBundleName` ("Nuve"/"WeatherApp") ve `BrandHeader`
  içindeki düz `"Nuve"` yazısı BİLEREK çevrilmiyor — sadece kaynak dil (`tr`) kaydı var, `en` kaydı YOK.
  Marka adı hangi dilde olursa olsun aynı kalmalı; `-exportLocalizations` çıktısında bu üçünün "eksik"
  görünmesi normal/beklenen bir durum, hata değil.

---

## 6. Daha Sonra Eklenebilecekler

Aklımda kalsın diye, şu an kapsam dışında bıraktıklarım:

- **Daha fazla dil**: Şu an sadece Türkçe + İngilizce çevrili; İspanyolca, Almanca gibi diller
  `Localizable.xcstrings`'e yeni bir `localizations` girdisi eklemek kadar basit ama içerik güvenilir
  bir çeviri gerektiriyor.
- **Widget**: Kilit ekranı / ana ekran widget'ı için ayrı bir Xcode hedefi (target) eklemek gerekiyor.
- **Bildirimler**: Ani hava değişimi / günlük özet bildirimi.
- **Birim testleri**: `WeatherServiceProtocol` sayesinde sahte bir servisle `WeatherViewModel`'i test
  etmek zaten kolay olurdu, henüz bir test hedefi (target) yok.

(Gerçek bir uygulama ikonu artık YAPILDI — bkz. `DesignSystem/BrandHeader.swift` notları. Şehirler
arası kaydırmalı/karusel geçiş de DENENDİ ama ON BİR farklı yaklaşımın hiçbiri güvenilir çalışmadığı
için TAMAMEN kaldırıldı — bkz. `Views/WeatherView.swift` bölümündeki mimari karar notu; favoriler
arası geçiş artık dokunmatik bir şeritle yapılıyor.)
