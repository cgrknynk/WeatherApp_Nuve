# Satır Satır Kod Açıklaması — Referans Dosyası

`Kod-Rehberi.md` genel mimariyi ve "neden böyle yaptım" kararlarını anlatıyor; bu dosya ondan TAMAMEN
ayrı ve çok daha ayrıntılı bir amaç güdüyor: projedeki HER dosyayı, mümkün olduğunca satır satır (ya da
birbirine sıkı bağlı birkaç satırı bir grup olarak) açıklamak — hatta kullanılan Swift/SwiftUI sözdiziminin
(syntax) KENDİSİNİN ne anlama geldiğini bile. Amaç: bu projeye dair herhangi bir satır hakkında soru
gelirse ("bu neden `guard let` kullanıyor", "`@Published` ne yapıyor", "bu closure'daki `$0` ne") tek
bir yerden, hiçbir dış kaynağa bakmadan cevap verebilmek.

Okuma sırası: önce **Bölüm 1** (sözdizimi sözlüğü) — burada her Swift/SwiftUI yapısını BİR KERE, derinlemesine
açıklıyorum. Dosya dosya anlatırken aynı yapı tekrar geçtiğinde onu yeniden baştan anlatmıyorum, sadece
"(bkz. Bölüm 1 — Optional)" gibi geri referans veriyorum — yoksa bu dosya okunamayacak kadar
tekrarlı olurdu. **Bölüm 2**'den itibaren her dosyayı, projedeki klasör sırasına göre, yukarıdan aşağıya
anlatıyorum.

---

## Bölüm 1: Swift ve SwiftUI Sözdizimi Sözlüğü

### `import`
Dosyanın başındaki `import SwiftUI`, `import Foundation` gibi satırlar: "bu dosyada şu kütüphanenin
sağladığı tipleri/fonksiyonları kullanacağım" demek. `Foundation` temel veri tipleri (`Date`, `String`,
`URL`, `JSONDecoder`...) sağlıyor; `SwiftUI` arayüz (View, Text, VStack...) sağlıyor; `Combine`
`@Published`/`ObservableObject`'in altyapısını sağlıyor; `MapKit` harita/arama/geocoding; `CoreLocation`
GPS/konum izinleri; `Charts` grafik çizimi.

### `struct` vs `class`
- `struct`, bir **değer tipi**dir: bir değişkene atadığında ya da bir fonksiyona parametre olarak
  gönderdiğinde İÇERİĞİ KOPYALANIR — iki değişken aynı struct'ı "paylaşamaz", her biri kendi bağımsız
  kopyasına sahip olur. Projede `CityWeather`, `FavoriteCity`, `WeatherLocation` (aslında enum ama aynı
  mantık), `HourlyForecast`, `DailyForecast` gibi SAF VERİ taşıyan her şey `struct`.
- `class`, bir **referans tipi**dir: kopyalanmaz, birden fazla değişken AYNI nesneye işaret edebilir; biri
  değiştirirse hepsi görür. SwiftUI'da `ObservableObject` olması gereken HER ŞEY (`WeatherViewModel`,
  `LocationManager`, `LocationSearchService`) `class` OLMAK ZORUNDA — çünkü SwiftUI
  bir View'ın bu nesneyi "izlemesi" için onu referans olarak takip edebilmeli; bir struct kopyalanınca
  orijinal ile kopya birbirinden kopar, izleme mantığı çalışmaz.

### `enum`
"Şunlardan biri" demenin tipli yolu. `enum WeatherViewState { case idle; case loading; case success(CityWeather); case error(String) }`
gibi bir tanım, bir değişkenin SADECE bu dört durumdan birinde olabileceğini garanti ediyor — beşinci,
"hem yükleniyor hem hata var" gibi imkansız bir durum OLUŞTURULAMAZ bile (constructor/derleyici izin
vermiyor). `.success(CityWeather)` ve `.error(String)` gibi parantezli kısımlara **associated value**
(ilişkili değer) denir — case'in kendisi bir veri TAŞIYOR. Bunu okumak için `switch`/`if case` kullanılır:
```swift
switch state {
case .success(let weather): // artık `weather` burada bir CityWeather
case .error(let message):   // `message` burada bir String
default: break
}
```
`case 5..<12:` gibi bir satır ise bir ARALIK (Range) ile eşleştirme yapıyor — "saat 5 ile 12 arasındaysa".

### `protocol`
Bir "sözleşme": "Bunu uygulayan HER ŞEY şu fonksiyonlara/özelliklere sahip OLMAK ZORUNDA" demek.
`protocol WeatherServiceProtocol { func fetchWeather(for cityName: String) async throws -> WeatherBundle }`
gibi bir tanım, bu protokole uyan (conform eden) HERHANGİ bir tipin bu fonksiyona sahip olacağını
garanti ediyor — gerçek tipin `struct` mü `class` mı, `WeatherService` mi yoksa test için yazılmış sahte
(mock) bir servis mi olduğunu ÖNEMSEMİYORUZ. `WeatherViewModel`, somut `WeatherService` yerine SADECE
"bu protokole uyan bir şey" (`any WeatherServiceProtocol`) bekliyor.

### `extension`
Var olan bir tipe SONRADAN yeni fonksiyon/computed property eklemek. `extension Int { var percentFormatted: String { ... } }`
gibi bir tanım, Swift'in kendi `Int` tipine (bizim tanımlamadığımız, dilin kendi tipi) bizim
KENDİ fonksiyonumuzu ekliyor — artık her `Int` değeri `.percentFormatted` diyebiliyor. Projede ayrıca
bir PROTOKOLE extension de var (`extension WeatherServiceProtocol { func fetchWeather(at:) ... }`) — bu,
protokole uyan HER TİP için otomatik olarak ORTAK bir varsayılan uygulama sağlıyor, her tipin ayrı ayrı
yazmasına gerek kalmıyor.

### `var` vs `let`
`let` = sabit, bir kere değer verilir, bir daha DEĞİŞTİRİLEMEZ. `var` = değişken, sonradan değeri
değiştirilebilir. Projede struct'ların çoğu alanı `let` (örn. `CityWeather.name`) — bir hava durumu
sonucu geldikten sonra ismi değişmez; `@Published var state` gibi ViewModel alanları ise `var` — zamanla
değişmesi GEREKEN şeyler (yükleniyor → başarılı gibi).

### Computed Property (Hesaplanan Özellik)
`var isNight: Bool { ... bir hesaplama ... }` gibi — bir DEĞER SAKLAMIYOR, her okunduğunda YENİDEN
HESAPLIYOR. `CityWeather.isNight`, `.localizedCountryName`, `.dewPoint` hep bu türden: arka planda ekstra
bir alan tutmuyorlar, sadece var olan diğer alanlardan (sunrise/sunset, country, temperature/humidity)
anlık olarak türetiliyorlar.

### Optional (`?`, `!`, `??`)
Swift'te bir değer YA vardır YA DA YOKTUR (`nil`) — bunu tip sisteminin kendisi zorluyor.
`var sunrise: Date?` demek "ya bir Date var ya da hiç yok (nil)" demek; bu tip düz `Date` DEĞİL,
`Optional<Date>`. Bir optional'ı kullanmadan önce içindekini "açmak" (unwrap) gerekiyor:
- `if let sunrise { ... }` — sunrise nil DEĞİLSE bloğun içine gir, içindeki gerçek değeri kullan.
- `guard let sunrise else { return }` — sunrise nil'SE hemen çık (fonksiyonun geri kalanını çalıştırma);
  DEĞİLSE devam et. `guard`'ın `if let`'ten farkı: "olumsuz durumu en başta eleyip devamında OPTIONAL
  OLMAYAN değeri kullanmaya devam etmek" — kod içeride iç içe girintilenmiyor.
- `??` (nil coalescing) — "eğer nil ise şunu kullan": `location.displayName ?? "Konum"`.
- `?.` (optional chaining) — "eğer nil değilse devam et, nil ise TÜM zincir nil olsun":
  `currentWeather?.name`.
- `!` (force unwrap) — "kesinlikle nil DEĞİL, eğer yanılıyorsam UYGULAMA ÇÖKSÜN" demek; bu projede
  neredeyse hiç kullanılmıyor (bilerek — çökme riskini `if let`/`guard let`/`??` ile ortadan
  kaldırıyoruz).

### Closure (Kapanış)
Süslü parantez içine yazılan, bir DEĞİŞKENE atanabilen ya da bir fonksiyona PARAMETRE olarak
geçirilebilen isimsiz bir fonksiyon. `Button { viewModel.toggleFavorite(...) } label: { Image(...) }`
gibi bir çağrıda, süslü parantez içindeki her şey bir closure — "bu butona basılınca ÇALIŞTIR" diyoruz.
`onRefresh: () -> Void` gibi bir parametre tipi, "parametre olarak hiçbir şey almayan, hiçbir şey
döndürmeyen bir closure bekliyorum" demek. `.compactMap { city in ... }` gibi yerlerde closure'ın
PARAMETRESİNE (`city`) isim veriyoruz; isim vermeyip `$0` da yazılabilirdi ama isim vermek okunurluğu
artırıyor.

### Generic'ler (`<T>`)
Bir tipin/fonksiyonun BİRDEN FAZLA farklı somut tip için çalışabilmesini sağlıyor.
`struct WeatherStateScaffold<SuccessContent: View>` demek: "bu View'ı HERHANGİ bir `SuccessContent` View
tipiyle kullanabilirsin, ben içeriğin TAM olarak ne olduğunu bilmek zorunda değilim, sadece bir View
OLDUĞUNU biliyorum" demek. Çağrıldığı yerde Swift, `successContent` closure'ının döndürdüğü tipe bakarak
`SuccessContent`'in NE olduğunu kendisi çıkarıyor (type inference) — biz elle yazmıyoruz.

### `some View` vs `any`
`var body: some View` — "bu bir View döndürüyor ama TAM OLARAK HANGİ View olduğunu dışarıya açıklamak
istemiyorum (ki gerçekte VStack/HStack/ZStack'lerin iç içe geçmiş KARMAŞIK bir tipidir), sadece BİR View
olduğunu garanti ediyorum" demek — derleyici gerçek tipi kendi biliyor, dışarıya sızdırmıyor.
`any WeatherServiceProtocol` ise "protokole uyan HERHANGİ bir somut tip, hangisi olduğu ÇALIŞMA ZAMANINDA
belli olacak" demek — `WeatherViewModel.init(service: any WeatherServiceProtocol = WeatherService())`
gibi, gerçek/sahte servis arasında seçim yapılabilsin diye.

### `@ViewBuilder`
Bir fonksiyon/closure parametresinin İÇİNDE birden fazla View'ı ART ARDA (SwiftUI'ın kendi `VStack`
içindeki gibi) yazabilmemizi sağlayan özel bir işaretleyici. `WeatherStateScaffold`'daki
`@ViewBuilder let successContent: (CityWeather) -> SuccessContent` sayesinde çağıran taraf
`{ weather in WeatherContentView(...) }` gibi DOĞAL bir closure yazabiliyor.

### Property Wrapper'lar (`@` ile başlayan özellikler)
Bir değişkenin ÖNÜNE `@` ile yazılan ekler, o değişkenin DAVRANIŞINI kökten değiştiriyor:

| Wrapper | Ne yapıyor | Nerede kullanılıyor |
|---|---|---|
| `@Published` | Değer değişince, bu nesneyi izleyen HER View otomatik yeniden çiziliyor | `WeatherViewModel.state` |
| `@StateObject` | Bir `class`'ı (ObservableObject) View'ın YAŞAM DÖNGÜSÜNE bağlıyor — View bir kere yaratıldığında BİR KERE kurulup View yok olana kadar YAŞIYOR | `WeatherAppApp.viewModel`, `HomeView.locationManager` |
| `@ObservedObject` | `@StateObject`'e benzer ama nesneyi View KENDİSİ YARATMIYOR, dışarıdan alıyor (bu projede pek kullanılmıyor, `@EnvironmentObject` tercih edilmiş) | — |
| `@EnvironmentObject` | Üstteki bir View'ın `.environmentObject(...)` ile "ortama bıraktığı" bir nesneyi, aradaki HİÇBİR View'a elle parametre geçirmeden alıyor | `HomeView`, `WeatherView`, `SettingsView` içindeki `viewModel` |
| `@State` | View'a ÖZEL, basit bir değerin (metin, sayı, bool) durumunu tutuyor; View yeniden çizildiğinde KAYBOLMUYOR | Arama metni, `@State private var showSettings` |
| `@Binding` | Bir `@State`'in KENDİSİNE değil, ona giden bir "kapıya" sahip olmak — değişikliği doğrudan kaynağa yazıyor | `WeatherFilterView`'daki `@Binding var filter` |
| `@Environment` | Sistemin kendi sağladığı bir değeri okumak (renk şeması, "hareketi azalt" ayarı, `dismiss` fonksiyonu) | `@Environment(\.scenePhase)`, `@Environment(\.dismiss)` |
| `@Namespace` | Farklı View'lar arasında animasyon eşleştirmesi (matched geometry/zoom transition) için ortak bir "kimlik alanı" | `heroNamespace` |

### `async` / `await` / `Task` / `throws` / `try`
- `async`: "bu fonksiyon zaman alabilir (ağ isteği gibi), çağıran taraf BEKLEMEYE hazır olmalı" demek.
- `await`: "burada dur, bu async fonksiyonun bitmesini BEKLE" demek — çağrıldığı yerde kod akışı
  DURAKLIYOR ama uygulamanın geri kalanı (arayüz) KİLİTLENMİYOR.
- `throws`: "bu fonksiyon bir HATA fırlatabilir" demek; çağıran taraf `try` yazmak ZORUNDA.
- `try`: "bunu dene, hata fırlatırsa YUKARI ilet" — genelde `do { let x = try await ... } catch { ... }`
  içinde kullanılır.
- `try?`: "bunu dene, hata olursa SESSİZCE `nil` döndür" — hatayı görmezden gelmek istediğimizde
  (örn. hava kalitesi ikincil bir bilgi, başarısız olursa ekranı bozmasın).
- `Task { ... }`: arka planda BAĞIMSIZ bir iş başlatıyor; içinde `await` kullanılabiliyor. Kullanıcı
  hızlıca başka bir şehre geçerse önceki `Task`'ı `.cancel()` ile iptal ediyoruz;
  `guard !Task.isCancelled else { return }` iptal edilmiş bir işin sonucu ekranı EZMESİN diye.
- `CancellationError`: bir `Task` iptal edildiğinde fırlatılan özel hata — kullanıcıya GÖSTERMEMİZ
  gerekmiyor (kasıtlı bir iptal, gerçek bir hata değil).

### `@MainActor` / `nonisolated`
iOS uygulamalarında arayüzle ilgili HER ŞEY (özellikle `@Published` değişkenler) ANA İŞ PARÇACIĞINDA
(main thread) güncellenmeli — aksi halde arayüz garip/tutarsız davranabilir, hatta çökebilir.
`@MainActor` işareti "bu class'ın/fonksiyonun HER ZAMAN ana iş parçacığında çalıştığından emin ol" demek
— derleyici bunu KENDİSİ garanti ediyor, biz elle "ana thread'e geç" yazmıyoruz. Bu proje Xcode'un
"varsayılan olarak HER ŞEY MainActor" ayarını kullanıyor (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) —
yani AKSİ BELİRTİLMEDİKÇE her yeni `struct`/`class`/`enum` otomatik olarak MainActor'a kayıyor.
`nonisolated`, bu varsayılanı TERSİNE çeviren işaret: "HAYIR, bu tip ana iş parçacığına bağlı DEĞİL,
istediğin arka plan thread'inden kullanabilirsin" demek. `WeatherService` (ağ isteği + JSON çözme işi
ana thread'i MEŞGUL ETMESİN diye) ve DTO (Data Transfer Object) struct'ları bu yüzden `nonisolated`.

### `Codable` / `Decodable` / `Encodable`
Bir tipin JSON ↔ Swift struct'ı arasında OTOMATİK dönüştürülebileceğini işaretliyor. `Codable`, aslında
`Decodable & Encodable`'ın kısayolu. `CityWeather: Codable` sayesinde `JSONEncoder()/JSONDecoder()` bu
tipi elle yazılmış hiçbir dönüştürme kodu OLMADAN JSON'a çevirebiliyor/JSON'dan okuyabiliyor — favori
anlık görüntülerini (`favoriteSnapshots`) diske kaydederken kullanıyoruz.

### `Equatable` / `Hashable` / `Identifiable`
- `Equatable`: "bu tipin iki örneğini `==` ile karşılaştırabilirsin" demek.
- `Hashable`: "bu tipi bir `Set`'e ya da `Dictionary` ANAHTARI olarak koyabilirsin" demek.
- `Identifiable`: "bu tipin BENZERSİZ bir `id`'si var" demek — SwiftUI'ın `List`/`ForEach`'i, hangi
  satırın hangi veriye ait olduğunu bu `id` ile takip ediyor (satırlar yeniden sıralansa/silinse bile
  animasyon doğru öğeyi takip ediyor).

### Access Control (Erişim Denetimi)
`private` = SADECE bu dosyanın/tipin İÇİNDEN erişilebilir. Hiçbir şey yazılmazsa varsayılan `internal`
(aynı HEDEF/target içindeki her yerden erişilebilir — bu proje TEK bir target olduğu için pratikte
"her yerden erişilebilir" demek). Bu projede DTO'lar ve iç yardımcı fonksiyonlar genelde `private` —
sadece o dosyanın kendi iç detayı oldukları, dışarıya SIZMAMASI gerektiği için.

### `Self` (büyük S)
Bir tipin İÇİNDE, o tipin KENDİSİNE referans vermek için kullanılıyor — özellikle `static` fonksiyonlar
içinde. `WeatherService.dateTimeFormatter(...)` gibi bir `static` fonksiyonu AYNI tipin başka bir
`static` fonksiyonundan çağırırken `Self.dateTimeFormatter(...)` yazılıyor.

### `LocalizedStringKey` vs `String`
SwiftUI'ın `Text(_:)`, `Button(_:)`, `.navigationTitle(_:)` gibi fonksiyonları, kendilerine DOĞRUDAN bir
metin LİTERAL'İ (`"Ayarlar"` gibi, bir değişken DEĞİL) geçirildiğinde bunu OTOMATİK olarak
`Localizable.xcstrings` kataloğunda arıyor — bu otomasyonun çalışması için parametrenin tipi
`LocalizedStringKey` olmalı (düz `String` değil). Kendi View'larımızda (`WeatherDetailBox.title` gibi)
bu OTOMASYONU miras almak istiyorsak, o parametreyi de bilerek `LocalizedStringKey` yapıyoruz. Bir metin
bir DEĞİŞKEN üzerinden geliyorsa (`Text(airQuality.label)` gibi), bu otomasyon ARTIK devreye girmiyor —
o durumda `String(localized: "anahtar", defaultValue: "...")` ile KENDİMİZ kataloğa bakıyoruz.

---

## Bölüm 2: Dosya Dosya, Satır Satır

Klasör sırası: `WeatherAppApp.swift` (giriş noktası) → `Models/` → `Services/` → `Utilities/` →
`ViewModels/` → `DesignSystem/` → `Views/` → `Views/Components/`.

### `WeatherAppApp.swift`
```swift
import SwiftUI

@main
struct WeatherAppApp: App {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
```
- `@main`: "uygulama BURADAN başlasın" işareti — iOS'a giriş noktasının bu struct olduğunu söylüyor,
  klasik `main()` fonksiyonunun SwiftUI'daki karşılığı.
- `struct WeatherAppApp: App`: `App` bir PROTOKOL — "bir uygulama olmak için `body: some Scene`
  sağlamalısın" diyor.
- `@StateObject private var viewModel = WeatherViewModel()`: uygulamanın BEYNİ burada, en tepede, TEK BİR
  KERE yaratılıyor. `@StateObject` olduğu için `WeatherAppApp` struct'ı her yeniden değerlendirildiğinde
  (SwiftUI bunu sık sık yapar) bu nesne YENİDEN YARATILMIYOR — bir kere kurulup uygulama kapanana kadar
  aynı örnek yaşıyor.
- `var body: some Scene`: `App` protokolünün istediği tek şey — "uygulamanın SAHNESİ (pencere/pencereler)
  ne gösteriyor" sorusunun cevabı.
- `WindowGroup { ... }`: "bir pencere aç, içine şunu koy" — iOS'ta genelde TEK bir pencere/ekran demek.
- `HomeView()`: uygulamanın gösterdiği İLK ve TEK kök ekran — ayrı bir "hoş geldin"/onboarding ekranı
  BİLEREK yok, konum izni sistem penceresi `HomeView` ilk göründüğünde otomatik geliyor.
- `.environmentObject(viewModel)`: bu `viewModel`'i, `HomeView` VE onun ALTINDAKİ (push/sheet ile açılan)
  HER ekranın `@EnvironmentObject` ile erişebileceği "ortak bir ortam nesnesi" yapıyor — elle her
  ekrana tek tek parametre olarak geçirmemize gerek KALMIYOR.
- `.preferredColorScheme(.dark)`: uygulamanın tasarımı zaten HER YERDE koyu arka plan + açık renkli yazı
  varsayıyor; bu satır olmadan cihaz sistem AÇIK moddaysa bazı sistem kontrolleri (Picker etiketi gibi)
  kendi "açık mod" renklerine (siyaha) dönüp okunaksız görünüyordu — bu satır uygulamayı SİSTEM
  ayarından bağımsız, hep koyu modda sabitliyor.

---

## Models/

### `Models/CityWeather.swift`
```swift
struct CityWeather: Codable, Equatable {
    var name: String
    let country: String
    let temperature: Double
    let feelsLike: Double
    let pressure: Int
    let visibility: Int
    let cloudiness: Int
    let sunrise: Date?
    let sunset: Date?
    let conditionDescription: String
    let conditionCode: Int
    let conditionCodes: [Int]
    let humidity: Int
    let windSpeed: Double
    let windDeg: Int?
    let windGust: Double?
    let tempMin: Double
    let tempMax: Double
    let lat: Double
    let lon: Double
    let timezoneOffsetSeconds: Int
    ...
}
```
- `Codable, Equatable`: (bkz. Bölüm 1) `Codable` sayesinde diske (`favoriteSnapshots`) kaydedip geri
  okuyabiliyoruz; `Equatable` sayesinde `WeatherViewState: Equatable`'ın `.success(CityWeather)` case'i
  karşılaştırılabiliyor. **Temizlik**: eskiden `Identifiable`'a da uyuyordu ve OpenWeather'ın şehir
  numarasını tutan bir `id: Int` alanı vardı — ama `CityWeather` hiçbir yerde bir `List`/`ForEach`
  içinde TEKİL bir öğe olarak kullanılmıyor, hep tekil bir değer ya da isimle anahtarlanmış bir sözlük
  değeri (`[String: CityWeather]`) olarak geçiyor; yani `Identifiable` hiç GEREKMİYORDU. Aynı sebeple
  hiç okunmayan `id` alanı da, onu besleyen `WeatherService.swift`'teki `LocationIdentityResponse`/
  `LocationIdentity` alanlarıyla BİRLİKTE kaldırıldı.
- `name` neden TEK `var` alan (geri kalan hepsi `let`): bir `CityWeather` bir kere geldikten sonra
  İÇİNDEKİ diğer hiçbir şey DEĞİŞMİYOR (hava durumu güncellenince eskisi ATILIP YENİ bir `CityWeather`
  yaratılıyor); ama `name`'i sonradan `applying(to:)` ile ÜZERİNE YAZMAMIZ gerekiyor (bkz.
  `WeatherLocation.swift`), o yüzden tek istisna bu.
- `sunrise`/`sunset` neden `Date?` (opsiyonel): Open-Meteo'nun günlük listesi boş dönerse (nadir bir
  ağ/veri sorunu) bu alanları dolduramayız; `nil` bu durumu temsil ediyor, uygulamayı ÇÖKERTMEK yerine.
- `conditionCodes: [Int]`: bir DİZİ — API bazen (nadiren) birden fazla eş zamanlı durum bildirebiliyordu
  (kar + sis gibi); `conditionCode` bu dizinin İLK/birincil elemanı, ikon/renk SEÇİMİ bunu kullanıyor,
  parçacık katmanı ise TÜM diziye bakabiliyor.
- `windDeg`/`windGust` neden `Int?`/`Double?`: API bu alanları HER ZAMAN vermiyor (rüzgar yoksa yön
  anlamsız, hamle bazen hiç ölçülmemiş olabilir).

```swift
var isNight: Bool {
    guard let sunrise, let sunset else { return false }
    let now = Date()
    return now < sunrise || now > sunset
}
```
- Computed property (bkz. Bölüm 1) — HER okunduğunda YENİDEN hesaplanıyor, bir "gece mi" bayrağı
  SAKLAMIYORUZ, çünkü zaman geçtikçe bu cevap KENDİLİĞİNDEN değişmeli.
- `guard let sunrise, let sunset else { return false }`: TEK bir `guard` içinde İKİ optional'ı BİRDEN
  açıyoruz (virgülle ayırarak) — ikisi de nil DEĞİLSE devam, biri bile nil'se `false` döndür (gündüz
  varsay).
- `now < sunrise || now > sunset`: `Date` tipi `Comparable`, yani `<`/`>` ile karşılaştırılabiliyor —
  "şu an gündoğumundan ÖNCE mi ya da günbatımından SONRA mı" = gece.

```swift
var systemIconName: String {
    WMOWeatherCode.systemIconName(for: conditionCode, isNight: isNight)
}
```
- İkonu seçen switch'in KENDİSİ artık burada değil — `Utilities/WMOWeatherCode.swift`'teki
  `systemIconName(for:isNight:)`'ta (bkz. o bölüm). **Temizlik**: eskiden bu switch hem burada hem
  `DailyForecast.systemIconName`'de neredeyse BİREBİR aynı şekilde tekrar yazılıyordu (aralar sadece
  gece/gündüz farkında ayrışıyordu); tek yere toplayıp `isNight` parametresine varsayılan `false`
  verdik, `CityWeather` gerçek `isNight` değerini yolluyor, `DailyForecast` hiç vermiyor (varsayılana
  düşüyor).

```swift
var localizedCountryName: String {
    Locale.current.localizedString(forRegionCode: country) ?? country
}
```
- `country` bir ISO kodu ("TR" gibi); `Locale.current.localizedString(forRegionCode:)` bunu KULLANICININ
  sistem diline göre okunabilir bir isme ("Türkiye"/"Turkey") çeviriyor. Çeviremezse (`nil` dönerse) ham
  kodu (`country`) geri veriyoruz — `??` ile.

```swift
var dewPoint: Double {
    guard humidity > 0 else { return temperature }
    let b = 17.625
    let c = 243.04
    let gamma = (b * temperature) / (c + temperature) + log(Double(humidity) / 100)
    return (c * gamma) / (b - gamma)
}
```
- Çiğ noktası — sıcaklık ve nemden HESAPLANIYOR, ekstra bir API isteği GEREKTİRMİYOR. `b`/`c`,
  Magnus-Tetens yaklaşıklığının SABİT katsayıları (fizik formülü, uydurma değil). `log(...)`,
  `Foundation`'ın doğal logaritma fonksiyonu. `guard humidity > 0` — nem sıfırsa formül matematiksel
  olarak ANLAMSIZLAŞIR (log(0) tanımsız), o durumda sadece gerçek sıcaklığı geri veriyoruz.

```swift
struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let minTemperature: Double
    let maxTemperature: Double
    let conditionCode: Int
    let pop: Double
    var systemIconName: String { WMOWeatherCode.systemIconName(for: conditionCode) }
}
```
- `let id = UUID()`: her `DailyForecast` yaratıldığında RASTGELE, BENZERSİZ bir kimlik üretiliyor —
  `Identifiable` için gereken `id` bu; günün TARİHİNİ değil rastgele bir kimliği kullanmamızın nedeni
  basit: `ForEach` için birbirinden ayırt edilebilir OLMASI yeterli, tarihin kendisi zaten ayrı bir alan.
- `pop`: "probability of precipitation" (yağış olasılığı), 0 ile 1 arası bir `Double` — ekranda
  `Int(pop * 100).percentFormatted` ile yüzdeye çevriliyor.

### `Models/WeatherError.swift`, `AirQuality.swift`
```swift
enum WeatherError: LocalizedError {
    case cityNotFound
    case network
    case decoding
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .cityNotFound: return String(localized: "error.city_not_found", defaultValue: "...")
        ...
        }
    }
}
```
- `LocalizedError`, `Error` protokolüne uyan (yani `throw` edilebilen) tiplerin KULLANICIYA gösterilecek
  bir METİN sağlamasını isteyen bir protokol. `errorDescription: String?` bu METNİ sağlıyor — `nil`
  dönebildiği için `?` ile opsiyonel (bu projede HER zaman bir metin döndürüyoruz ama protokol yine de
  opsiyonel istiyor).
- Dört `case`, servisin fırlatabileceği DÖRT farklı hata TÜRÜNÜ temsil ediyor — kullanıcıya "şehir
  bulunamadı" ile "internet yok" FARKLI mesajlar olarak gösterilebiliyor, hepsi TEK bir genel mesaj
  yerine.

```swift
struct AirQuality: Equatable {
    let aqi: Int
    var label: String { switch aqi { case 1: ...; default: ... } }
    var tintColor: Color { switch aqi { case 1: return .green; ...; default: return .purple } }
}
```
- `aqi`: OpenWeather'ın 1 (İyi) ile 5 (Çok Kötü) arası endeksi, HAM sayı olarak saklanıyor.
- `label`/`tintColor`: bu ham sayıyı KULLANICIYA gösterilecek bir metne ve bir renge çeviren İKİ AYRI
  computed property — endeks DEĞİŞMEDEN, gösterim İSTENDİĞİNDE türetiliyor.

### `Models/WeatherLocation.swift`
```swift
enum WeatherLocation: Hashable {
    case name(String)
    case coordinate(lat: Double, lon: Double, displayName: String)

    var displayName: String {
        switch self {
        case .name(let name): return name
        case .coordinate(_, _, let displayName): return displayName
        }
    }

    func applying(to weather: CityWeather) -> CityWeather {
        guard case .coordinate = self else { return weather }
        var corrected = weather
        corrected.name = displayName
        return corrected
    }
}
```
- **Yaşanan bir hata — asıl kök neden**: "İstanbul" arayıp seçince "Karaköy" gösterilmeye devam ediyordu
  — arama tarafında (`LocationSearchService`) koordinatı ne kadar İYİLEŞTİRSEK de (MKLocalSearch →
  MKGeocodingRequest → CLGeocoder, üç FARKLI API denendi) sorun HİÇ bitmedi. Sebep: ekranda gösterilen
  isim bu `displayName` DEĞİL, `CityWeather.name` — yani OpenWeather'ın KOORDİNATA bakıp KENDİ
  veritabanından döndürdüğü isim. Büyük metropollerde OpenWeather bu koordinatı en YAKIN kayıtlı
  semte ("Karaköy" gibi) göre ETİKETLİYORDU — hangi API'yle çözersek çözelim koordinat DOĞRU olsa bile
  bu ETİKET yanlış kalıyordu.
- `func applying(to weather: CityWeather) -> CityWeather`: `.coordinate` durumunda (KULLANICININ zaten
  aradığı/seçtiği, GÜVENDİĞİMİZ bir isim varsa) gelen `weather`'IN bir KOPYASINI alıp `.name`'İNİ
  OpenWeather'ın etiketi YERİNE bu `displayName` ile DEĞİŞTİRİYOR. `guard case .coordinate = self else
  { return weather }`: `.name` durumunda (elimizde GÜVENİLİR bir kullanıcı seçimi YOK, serbest metin
  arama) bu müdahaleyi YAPMIYORUZ, API'nin kendi ismini AYNEN kullanıyoruz.
- `var corrected = weather; corrected.name = displayName`: bu YÜZDEN `CityWeather.name`'İ `let`'TEN
  `var`'A çevirdik — struct'IN GERİ KALANI hâlâ DEĞİŞMEZ, sadece bu TEK alan artık düzeltilebiliyor.
  `WeatherViewModel.fetchWeather(for:)`, `refreshFavoriteSnapshots()` ve `snapshotWeather(for:)` —
  hava durumu verisinin GÖSTERİLDİĞİ/SAKLANDIĞI HER yer bu fonksiyonu çağırıyor, böylece favori adı,
  favori-değiştirme şeridi, paylaşım metni GİBİ HER ŞEY tutarlı kalıyor.
- Bir yerin hava durumunu sorgulamanın İKİ YOLUNU temsil eden bir enum — `.name` (klavyeden serbest
  metin, MapKit çözemezse son çare) ya da `.coordinate` (arama sonucu, mevcut konum, favoriler — KESİN
  sonuç). `.coordinate`'in üç ilişkili değeri var (`lat`, `lon`, `displayName`) — parantez içinde
  ETİKETLİ (isimlendirilmiş) associated value'lar bunlar.
- `case .coordinate(_, _, let displayName)`: `_` (alt çizgi) "bu değeri ÖNEMSEMİYORUM, isim vermeye bile
  gerek yok" demek — sadece `displayName`'i açıyoruz.
- `Hashable`: `WeatherLocation` bir `@State`/`Set` içinde kullanılabilsin diye (örn.
  `@State private var searchedLocation: WeatherLocation?` ve `.navigationDestination(item:)`).

### `Models/FavoriteCity.swift`
```swift
struct FavoriteCity: Codable, Hashable, Identifiable {
    let name: String
    let lat: Double?
    let lon: Double?
    var id: String { name.lowercased() }

    var location: WeatherLocation {
        if let lat, let lon {
            return .coordinate(lat: lat, lon: lon, displayName: name)
        }
        return .name(name)
    }
}
```
- `lat`/`lon` NEDEN opsiyonel: bu düzeltmeden ÖNCE eklenmiş eski favoriler için koordinat BİLİNMİYOR
  (eski format sadece isim diziisiydi) — `nil` bu "bilmiyorum" durumunu temsil ediyor.
- `var id: String { name.lowercased() }`: `Identifiable` için gereken `id` — ismi KÜÇÜK harfe çevirip
  kullanıyoruz ki "Kayseri" ile "kayseri" AYNI favori sayılsın (`ForEach`/karşılaştırma tutarlı olsun).
- `location`: `if let lat, let lon` İKİ optional'ı BİRDEN açıyor (bkz. Bölüm 1 — Optional); ikisi de
  doluysa KESİN koordinatla sorgula, biri bile eksikse isimle aramaya (`.name`) düş. `Codable` sayesinde
  bu struct diziler hâlinde JSON'a çevrilip `UserDefaults`'a yazılabiliyor.

### `Models/WeatherConditionCategory.swift`
```swift
enum WeatherConditionCategory: String, CaseIterable, Identifiable {
    case clear, cloudy, rain, storm, snow, fog
    var id: String { rawValue }

    static func category(forConditionCode conditionCode: Int) -> WeatherConditionCategory {
        switch conditionCode {
        case 200...232: return .storm
        case 300...531: return .rain
        ...
        }
    }
    var label: String { ... }  // yerelleştirilmiş, KULLANICIYA gösterilen isim
    var icon: String { ... }   // SF Symbol adı
}
```
- `: String`: bu enum'un HER case'inin bir `rawValue`'su (ham değeri) var VE bu ham değer bir `String`
  ("clear", "cloudy" gibi, otomatik olarak case isminin KENDİSİ). `rawValue` özelliği bunu okuyor.
- `CaseIterable`: "bu enum'un TÜM case'lerini bir dizi olarak bana ver" (`WeatherConditionCategory.allCases`)
  — filtre ekranındaki chip listesini OLUŞTURMAK için kullanılıyor.
- `static func category(forConditionCode:)`: `static` demek "bir ÖRNEĞE değil, TİPİN KENDİSİNE ait" —
  `WeatherConditionCategory.category(forConditionCode: 500)` gibi, bir `WeatherConditionCategory`
  ÖRNEĞİ yaratmadan çağrılabiliyor.

```swift
struct WeatherFilter: Equatable {
    var categories: Set<WeatherConditionCategory> = []
    var minTemperatureCelsius: Double = -30
    var maxTemperatureCelsius: Double = 50

    var isActive: Bool {
        !categories.isEmpty || minTemperatureCelsius > -30 || maxTemperatureCelsius < 50
    }

    func matches(_ weather: CityWeather?) -> Bool {
        guard isActive else { return true }
        guard let weather else { return false }
        if !categories.isEmpty {
            let category = WeatherConditionCategory.category(forConditionCode: weather.conditionCode)
            if !categories.contains(category) { return false }
        }
        if weather.temperature < minTemperatureCelsius || weather.temperature > maxTemperatureCelsius {
            return false
        }
        return true
    }
}
```
- `Set<WeatherConditionCategory>`: bir KÜME — aynı kategori İKİ KERE eklenemez, sıralama ÖNEMSİZ (bir
  `Array`'den farklı). Kullanıcı birden fazla hava durumu türü seçebildiği için `Set` uygun.
  `Set` kullanabilmek için `WeatherConditionCategory`'nin `Hashable` olması GEREKİYOR — `Identifiable`
  zaten dolaylı olarak bunu sağlıyor (enum'lar varsayılan `Hashable`).
  `isActive`: "kullanıcı HERHANGİ bir kritere dokunmuş mu" — filtre uygulanmamışsa `matches` her zaman
  `true` dönsün diye ayrı bir bayrak.
- `matches(_:)`: parametre `CityWeather?` (opsiyonel) çünkü favori satırı HENÜZ yüklenmemiş (veri gelmemiş)
  olabilir; `guard isActive else { return true }` filtre KAPALIYSA her satırı göster; `guard let weather
  else { return false }` filtre AKTİFKEN veri yoksa satırı GİZLE (belirsiz bırakmak yerine).

---

## Services/

### `Services/WeatherService.swift` (en büyük/karmaşık dosya)

```swift
private nonisolated struct LocationIdentityResponse: Codable {
    let name: String
    let coord: Coord
    let sys: Sys
    struct Coord: Codable { let lat: Double; let lon: Double }
    struct Sys: Codable { let country: String }
}
```
- Bu bir **DTO** (Data Transfer Object) — API'den gelen HAM JSON'ın Swift karşılığı, birebir OpenWeather'ın
  alan adlarıyla (`coord`, `sys` gibi) eşleşiyor. `Coord`/`Sys` İÇ İÇE (nested) struct'lar — sadece bu
  DTO'nun İÇİNDE anlamlı oldukları için ayrı, üst düzey tipler yapılmadı.
- `private`: bu DTO SADECE bu dosyanın bir iç detayı, dışarıya (View'lara) hiç SIZMIYOR — dışarıya
  sızan tek şey işlenmiş `CityWeather`/`WeatherBundle`.
- `nonisolated`: (bkz. Bölüm 1 — `@MainActor`) `JSONDecoder().decode(...)` bu tipi SENKRON olarak
  çözüyor; tip varsayılan MainActor izolasyonunu miras alsaydı, nonisolated `WeatherService` içinden
  senkron çağrıldığında derleyici HATASI/uyarısı verirdi.
- Sadece `name`, `coord`, `sys.country` var — ESKİDEN bu DTO çok daha kalabalıktı (sıcaklık, rüzgar,
  bulutluluk...); Open-Meteo'ya geçince bu alanlara ARTIK gerek kalmadı, sadece "neresi" sorusuna
  (kimlik/koordinat) cevap vermesi yeterli. **Temizlik**: OpenWeather'ın döndürdüğü `id` alanı da vardı
  ama `CityWeather`'a kadar taşınıp hiç OKUNMUYORDU — tüm zincirden (`LocationIdentityResponse` →
  `LocationIdentity` → `CityWeather`) kaldırıldı.

```swift
private nonisolated struct OpenMeteoResponse: Codable {
    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Codable {
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let apparent_temperature: Double
        let weather_code: Int
        let cloud_cover: Int
        let pressure_msl: Double
        let visibility: Double
        let wind_speed_10m: Double
        let wind_direction_10m: Int
        let wind_gusts_10m: Double?
    }
    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation_probability: [Double]
        let weather_code: [Int]
    }
    struct Daily: Codable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Double]
        let sunrise: [String]
        let sunset: [String]
    }
}
```
- Alan adları `snake_case` (alt çizgili) — Swift'in kendi kuralı (`camelCase`) DEĞİL, çünkü bunlar
  Open-Meteo'nun JSON'daki BİREBİR alan adları; `Codable`'ın otomatik eşleşmesi için isimlerin AYNEN
  uyması gerekiyor (elle bir `CodingKeys` yazmaktan kaçınmak için).
- `Hourly`/`Daily` içindeki `time`/`temperature_2m` gibi alanların HEPSİ birer DİZİ (`[String]`,
  `[Double]`) — Open-Meteo verinin kendisini "saat 1: şu değer, saat 2: bu değer" şeklinde AYRI AYRI
  nesneler olarak DEĞİL, "24 saatin HER ALANI kendi paralel dizisinde" şeklinde veriyor. Yani
  `hourly.time[3]` ile `hourly.temperature_2m[3]` AYNI saate ait — index'ler birbirine PARALEL.
- `wind_gusts_10m: Double?`: bu alan bazen JSON'da `null` gelebiliyor, `?` bunu güvenle karşılıyor.

```swift
private nonisolated struct AirPollutionResponse: Codable {
    let list: [Item]
    struct Item: Codable {
        let main: Main
        struct Main: Codable { let aqi: Int }
    }
}
```
- OpenWeather'ın hava kirliliği uç noktasının cevabı `list` adlı bir DİZİ İÇİNDE geliyor (genelde tek
  elemanlı) — `decoded.list.first` ile ilk (ve tek) ölçümü alıyoruz.

```swift
struct WeatherBundle: Sendable {
    let current: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}
```
- Bu DTO DEĞİL — işlenmiş, TEMİZ sonuç. Open-Meteo TEK bir istekte anlık durum + saatlik + günlük tahmini
  BİRLİKTE verdiği için, bunları TEK bir pakette taşıyoruz; `WeatherViewModel` bunu TEK bir `await` ile
  alıp üç ayrı `@Published` alana dağıtıyor.
- `Sendable`: "bu tipin bir örneği, farklı iş parçacıkları/actor'lar ARASINDA güvenle paylaşılabilir"
  demek — `async` fonksiyonlardan MainActor'a dönerken Swift'in eşzamanlılık denetleyicisi bunu istiyor.

```swift
nonisolated protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for cityName: String) async throws -> WeatherBundle
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle
    func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality
}

extension WeatherServiceProtocol {
    func fetchWeather(at location: WeatherLocation) async throws -> WeatherBundle {
        switch location {
        case .name(let name): return try await fetchWeather(for: name)
        case .coordinate(let lat, let lon, _): return try await fetchWeather(lat: lat, lon: lon)
        }
    }
}
```
- Protokol, servisin SÖZLEŞMESİ — üç fonksiyon: isimle sorgula, koordinatla sorgula, hava kalitesi
  sorgula. HEPSİ `async throws` — zaman alabilirler VE hata fırlatabilirler.
- `extension WeatherServiceProtocol { func fetchWeather(at:) }`: protokolün KENDİSİNE eklenen bir
  VARSAYILAN uygulama (bkz. Bölüm 1 — `extension`). Bu sayede `WeatherLocation`'ın `.name`/`.coordinate`
  dallanmasını `WeatherViewModel`'İN üç fonksiyonu da (`fetchWeather`, `refreshFavoriteSnapshots`,
  `snapshotWeather`) bu TEK fonksiyondan çağırıyor — switch üç FARKLI yerde TEKRAR yazılmıyor.

```swift
nonisolated struct WeatherService: WeatherServiceProtocol {
    private let apiKey = "eff32b3ac02ea2adf9abcb7f29533d4a"
    ...
}
```
- `struct` (class DEĞİL): hiçbir DEĞİŞEN durumu (mutable state) yok — sadece SABİT bir API anahtarı
  tutuyor. Durumsuz olduğu için HER seferinde yeniden yaratılabilir, thread-safe.
- `apiKey`: SADECE `LocationIdentityResponse`/hava kalitesi (OpenWeather) çağrılarında kullanılıyor;
  Open-Meteo'nun kendisi ANAHTAR bile İSTEMİYOR.

```swift
func fetchWeather(for cityName: String) async throws -> WeatherBundle {
    guard let encodedCityName = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        throw WeatherError.invalidResponse
    }
    let identity = try await fetchLocationIdentity(
        urlString: "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCityName)&appid=\(apiKey)"
    )
    return try await fetchWeather(identity: identity)
}
```
- `addingPercentEncoding(withAllowedCharacters:)`: bir şehir isminde boşluk/Türkçe karakter ("İzmir")
  olabilir — bunlar URL içinde DOĞRUDAN kullanılamaz, "yüzde kodlaması" (`İzmir` → `%C4%B0zmir` gibi)
  gerekiyor. Bu işlem BAŞARISIZ olursa (çok nadir) `nil` döner, `guard...else { throw ... }` bu durumda
  ANLAMLI bir hata fırlatıyor.
- `"...\(encodedCityName)..."`: string interpolation — bir değişkenin değerini bir metnin İÇİNE
  gömme sözdizimi.
- İki `await` ZİNCİRLEME: önce kimliği (isim/ülke/koordinat) çöz, SONRA o koordinatla asıl hava durumunu
  çek. İkisi de ayrı birer ağ isteği.

```swift
func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle {
    let identity = try await fetchLocationIdentity(
        urlString: "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
    )
    return try await fetchWeather(identity: identity)
}
```
- Yukarıdakiyle AYNI mantık, sadece URL'nin sorgu kısmı `q=` yerine `lat=&lon=` kullanıyor —
  koordinat zaten KESİN olduğu için yüzde kodlamasına gerek yok.

```swift
private struct LocationIdentity {
    let name: String; let country: String; let lat: Double; let lon: Double
}

private func fetchLocationIdentity(urlString: String) async throws -> LocationIdentity {
    guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }
    let (data, response) = try await requestData(from: url)
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
        throw WeatherError.cityNotFound
    }
    guard let decoded = try? JSONDecoder().decode(LocationIdentityResponse.self, from: data) else {
        throw WeatherError.decoding
    }
    return LocationIdentity(name: decoded.name, country: decoded.sys.country, lat: decoded.coord.lat, lon: decoded.coord.lon)
}
```
- `LocationIdentity`: DTO'dan (JSON'a birebir bağımlı) BAĞIMSIZ, düz/temiz bir ara yapı — DTO'nun iç içe
  (`sys.country`) yapısını burada DÜZLEŞTİRİYORUZ (`country` doğrudan erişilebilir).
- `URL(string:)` BAŞARISIZ olabilir (`nil` dönebilir) — geçersiz bir metin URL'e ÇEVRİLEMEZSE.
- `response as? HTTPURLResponse`: `as?` bir tipi GÜVENLİ şekilde DAHA ÖZEL bir tipe çevirmeye çalışıyor,
  başarısız olursa `nil` dönüyor (crash ETMİYOR); genel `URLResponse`'u HTTP'ye özel `HTTPURLResponse`'a
  çeviriyoruz ki `.statusCode`'a erişebilelim.
- `try? JSONDecoder().decode(...)`: decode BAŞARISIZ olursa (JSON beklenmedik şekilde geldiyse) hatayı
  YUKARI FIRLATMAK yerine `nil` alıyoruz, `guard let decoded else { throw .decoding }` ile KENDİ, anlamlı
  hatamızı fırlatıyoruz — kullanıcı "JSON parse hatası: keyNotFound..." gibi teknik bir mesaj GÖRMÜYOR.

```swift
private func fetchWeather(identity: LocationIdentity) async throws -> WeatherBundle {
    let urlString = "https://api.open-meteo.com/v1/forecast"
        + "?latitude=\(identity.lat)&longitude=\(identity.lon)"
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,pressure_msl,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
        + "&hourly=temperature_2m,precipitation_probability,weather_code"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
        + "&timezone=auto&wind_speed_unit=kmh&forecast_days=7&forecast_hours=24"
    ...
}
```
- URL, `+` ile PARÇA PARÇA birleştiriliyor (uzun tek bir satır yerine okunur olsun diye).
- `current=...`/`hourly=...`/`daily=...`: Open-Meteo'ya "TAM OLARAK hangi alanları istiyorum"u
  söylüyoruz — virgülle ayrılmış bir liste, API sadece BUNLARI döndürüyor (gereksiz veri çekmiyoruz).
- `timezone=auto`: API'nin, VERDİĞİMİZ koordinata göre O YERİN kendi saat dilimini bulup TÜM
  zaman damgalarını (time, sunrise, sunset) o yerin YEREL saatinde döndürmesini sağlıyor.
- `wind_speed_unit=kmh`: rüzgar hızını doğrudan km/s cinsinden İSTİYORUZ (varsayılan zaten km/s ama
  AÇIKÇA belirtmek niyeti netleştiriyor) — uygulamanın geri kalanı zaten bu birimi VARSAYIYOR.
- `forecast_days=7`: günlük tahmin dizisinin UZUNLUĞU (bugün dahil 7 gün).
- `forecast_hours=24`: saatlik tahmin dizisinin ŞU ANKİ SAATTEN itibaren (gece yarısından DEĞİL) tam
  24 saat olmasını sağlıyor — elle "ilk N elemanı al" gibi bir kırpmaya GEREK KALMIYOR.

```swift
let timeZone = TimeZone(secondsFromGMT: decoded.utc_offset_seconds) ?? .current
let dateTimeFormatter = Self.formatter(dateFormat: "yyyy-MM-dd'T'HH:mm", timeZone: timeZone)
let dayFormatter = Self.formatter(dateFormat: "yyyy-MM-dd", timeZone: timeZone)
let primaryConditionCode = WMOWeatherCode.legacyConditionCode(for: decoded.current.weather_code)
```
- `TimeZone(secondsFromGMT:)`: API'nin verdiği saniye cinsinden UTC farkını GERÇEK bir `TimeZone`
  nesnesine çeviriyor; BAŞARISIZ olursa (aşırı nadir, geçersiz bir değer gelirse) cihazın kendi saat
  dilimine (`.current`) düşüyoruz.
- `Self.formatter(...)`: `Self` (bkz. Bölüm 1) — AYNI struct'ın (`WeatherService`) başka bir `static`
  fonksiyonunu çağırıyor. **Temizlik**: eskiden `dateTimeFormatter(timeZone:)` ve `dayFormatter(timeZone:)`
  diye İKİ AYRI, neredeyse birebir aynı fonksiyon vardı (aralarındaki TEK fark `dateFormat` metniydi);
  format string'i PARAMETRE yapıp tek `formatter(dateFormat:timeZone:)`'a indirdik (bkz. aşağıdaki tanım).
- `primaryConditionCode`: Open-Meteo'nun WMO kodunu (`weather_code`, TEK bir sayı) uygulamanın
  BİLDİĞİ eski aralık koduna çeviriyor — bu SAYI, hem `CityWeather.conditionCode` hem
  `conditionCodes: [primaryConditionCode]` (artık HER ZAMAN tek elemanlı bir dizi) için kullanılıyor.

```swift
let current = CityWeather(
    name: identity.name, country: identity.country,
    temperature: decoded.current.temperature_2m,
    feelsLike: decoded.current.apparent_temperature,
    pressure: Int(decoded.current.pressure_msl.rounded()),
    visibility: Int(decoded.current.visibility),
    cloudiness: decoded.current.cloud_cover,
    sunrise: decoded.daily.sunrise.first.flatMap(dateTimeFormatter.date(from:)),
    sunset: decoded.daily.sunset.first.flatMap(dateTimeFormatter.date(from:)),
    conditionDescription: WMOWeatherCode.localizedDescription(for: decoded.current.weather_code),
    conditionCode: primaryConditionCode,
    conditionCodes: [primaryConditionCode],
    humidity: decoded.current.relative_humidity_2m,
    windSpeed: decoded.current.wind_speed_10m,
    windDeg: decoded.current.wind_direction_10m,
    windGust: decoded.current.wind_gusts_10m,
    tempMin: decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m,
    tempMax: decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m,
    lat: identity.lat, lon: identity.lon,
    timezoneOffsetSeconds: decoded.utc_offset_seconds
)
```
- Burada DTO'lardan gelen HAM veri, uygulamanın kendi TEMİZ modeline (`CityWeather`) dönüştürülüyor —
  servis katmanının TEK işi bu: "dış dünyanın formatını, bizim formatımıza çevir".
- `Int(decoded.current.pressure_msl.rounded())`: basınç `Double` (örn. 1013.2) geliyor, `CityWeather.pressure`
  ise `Int` — önce `.rounded()` ile en yakın tam sayıya YUVARLIYORUZ, SONRA `Int(...)` ile tipi çeviriyoruz
  (yuvarlamadan direkt `Int(1013.9)` yazsaydık 1013'e KIRPARDI, 1014 değil).
- `decoded.daily.sunrise.first.flatMap(dateTimeFormatter.date(from:))`: `.first`, dizinin İLK elemanını
  (BUGÜNÜN gündoğumu saatini, `String?` olarak) alıyor. `.flatMap(...)`, bu `String?` NİL DEĞİLSE
  içindeki metni `dateTimeFormatter.date(from:)`'a verip bir `Date?`'e çeviriyor, NİL İSE `nil` olarak
  bırakıyor — `?.` zincirlemesinin fonksiyon-parametre versiyonu gibi düşünülebilir.
- `decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m`: günlük en düşük sıcaklık
  dizisinin İLK elemanı (bugünün değeri) varsa onu kullan, dizi BOŞSA (aşırı nadir bir API tuhaflığı)
  o anki sıcaklığa DÜŞ — asla `nil`/çökme riski YOK.

```swift
let hourly: [HourlyForecast] = (0..<decoded.hourly.time.count).compactMap { index in
    guard let date = dateTimeFormatter.date(from: decoded.hourly.time[index]) else { return nil }
    return HourlyForecast(
        time: date,
        temperature: decoded.hourly.temperature_2m[index],
        pop: decoded.hourly.precipitation_probability[index] / 100
    )
}
```
- `0..<decoded.hourly.time.count`: 0'DAN dizinin uzunluğuna kadar (SON HARİÇ) bir aralık — `time`
  dizisinin HER index'i için dönüyoruz, çünkü `time`/`temperature_2m`/`precipitation_probability`
  PARALEL diziler (aynı index AYNI saate ait, yukarıda anlatıldı).
- `.compactMap { index in ... }`: `map`'e benzer ama closure `nil` DÖNDÜRDÜĞÜNDE o elemanı SONUÇ
  dizisinden ATLIYOR (`nil` olmayanları TOPLUYOR) — bir saatin tarihi ayrıştırılamazsa (olmaması gereken
  bir durum ama savunmacı programlama) o saati SESSİZCE atlıyoruz, TÜM listeyi bozmadan.
- `/ 100`: Open-Meteo yağış olasılığını YÜZDE (0-100) olarak veriyor, `HourlyForecast.pop` ise 0-1 arası
  bekliyor (uygulamanın GERİ KALANIYLA tutarlı olsun diye) — burada BÖLEREK dönüştürüyoruz.

```swift
let daily: [DailyForecast] = (0..<decoded.daily.time.count).compactMap { index in
    guard let date = dayFormatter.date(from: decoded.daily.time[index]) else { return nil }
    return DailyForecast(
        date: date,
        minTemperature: decoded.daily.temperature_2m_min[index],
        maxTemperature: decoded.daily.temperature_2m_max[index],
        conditionCode: WMOWeatherCode.legacyConditionCode(for: decoded.daily.weather_code[index]),
        pop: decoded.daily.precipitation_probability_max[index] / 100
    )
}
return WeatherBundle(current: current, hourly: hourly, daily: daily)
```
- Aynı desen, günlük tahmin için — `dayFormatter` (saat İÇERMEYEN, sadece "yyyy-MM-dd" biçimini
  ayrıştıran AYRI bir formatter) kullanılıyor çünkü `daily.time` sadece TARİH veriyor, saat değil.
- Fonksiyonun SONUCU, üçünü (current/hourly/daily) tek bir `WeatherBundle`'da paketleyip DÖNDÜRÜYOR.

```swift
func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality {
    let urlString = "https://api.openweathermap.org/data/2.5/air_pollution?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
    guard let url = URL(string: urlString) else { throw WeatherError.invalidResponse }
    let (data, _) = try await requestData(from: url)
    guard let decoded = try? JSONDecoder().decode(AirPollutionResponse.self, from: data),
          let firstReading = decoded.list.first else {
        throw WeatherError.decoding
    }
    return AirQuality(aqi: firstReading.main.aqi)
}
```
- `let (data, _)`: `requestData` bir TUPLE (`(Data, URLResponse)`) döndürüyor; burada İKİNCİ elemanı
  (`URLResponse`) HİÇ KULLANMIYORUZ, `_` ile "bunu görmezden gel" diyoruz.
- `guard ... , let firstReading = decoded.list.first else`: TEK bir `guard` içinde İKİ koşulu BİRDEN
  kontrol ediyor (virgülle) — decode BAŞARILI OLMALI VE dizi BOŞ OLMAMALI, ikisi de sağlanmazsa hata.

```swift
private func requestData(from url: URL) async throws -> (Data, URLResponse) {
    do {
        return try await URLSession.shared.data(from: url)
    } catch {
        throw WeatherError.network
    }
}
```
- `URLSession.shared`: iOS'un KENDİ, uygulama genelinde paylaşılan ağ oturumu nesnesi.
- `do { ... } catch { ... }`: `URLSession`'ın kendi (teknik, kullanıcıya ANLAMSIZ) hatasını YAKALAYIP,
  bizim KENDİ `WeatherError.network`'ümüze ÇEVİRİYORUZ — çağıran taraf HER ZAMAN sadece bizim dört hata
  türümüzden (bkz. `WeatherError`) birini görüyor, `URLSession`'ın iç detaylarını hiç bilmiyor.

```swift
private static func formatter(dateFormat: String, timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = dateFormat
    formatter.timeZone = timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}
```
- `dateFormat` artık bir PARAMETRE — çağıran taraf saatlik veri için `"yyyy-MM-dd'T'HH:mm"`, günlük veri
  için sadece `"yyyy-MM-dd"` veriyor (bkz. yukarıdaki çağrı satırı); `'T'` tırnak içinde çünkü harfi
  harfine "T" karakteri (biçim harfi DEĞİL) olarak eşleşsin istiyoruz.
- `locale = Locale(identifier: "en_US_POSIX")`: SABİT BİÇİMLİ bir tarih AYRIŞTIRIRKEN cihazın kendi
  BÖLGESEL ayarlarından (12/24 saat, farklı takvim gibi) ETKİLENMEMEK için standart, "nötr" bir locale —
  bu olmadan bazı cihaz ayarlarında ayrıştırma SESSİZCE BAŞARISIZ olabiliyordu (bilinen bir Foundation
  tuzağı).

### `Services/LocationManager.swift`
```swift
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var displayLocationName: String?
    @Published var apiSearchCityName: String?
    ...
}
```
- `NSObject`: Apple'ın ESKİ (Objective-C kökenli) temel sınıfı — `CLLocationManagerDelegate` protokolüne
  uymak için MİRAS ALINMASI ZORUNLU (CoreLocation, Objective-C çağından kalma bir API).
- `ObservableObject`: bu class'ın `@Published` alanlarını SwiftUI'ın İZLEYEBİLMESİ için.
- `CLLocationManagerDelegate`: "konum güncellemesi geldiğinde/izin değiştiğinde/hata olduğunda BANA
  haber ver" sözleşmesi — bu protokole uyan bir tip, `CLLocationManager`'ın "temsilcisi" (delegate)
  olabiliyor.
- `private let manager = CLLocationManager()`: Apple'ın KONUM işini yapan gerçek nesnesi, DIŞARIYA
  sızdırılmıyor (`private`) — dışarıya sadece işlenmiş `@Published` alanlar açık.

```swift
override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
}
```
- `override init()`: `NSObject`'in kendi başlatıcısını (initializer) EZİYORUZ (override) — kendi kurulum
  adımlarımızı (`manager.delegate = self`) eklemek için.
- `super.init()`: EBEVEYN (NSObject) sınıfının kendi kurulumunu ÖNCE çalıştırıyoruz — bir class kendi
  init'inde İLK yapması gereken şeylerden biri genelde budur.
- `manager.delegate = self`: "konum olayları olduğunda BENİ (bu LocationManager örneğini) çağır" demek.

```swift
func requestLocation() {
    manager.requestWhenInUseAuthorization()
}
```
- Kullanıcıya SİSTEMİN KENDİ izin isteme penceresini gösteriyor ("Uygulama konumunuzu kullanmak
  istiyor..."). İzin zaten VERİLMİŞ/REDDEDİLMİŞSE bu çağrı SESSİZCE hiçbir şey yapmıyor (sistemin kendi
  davranışı).

```swift
func refreshAuthorizationStatusIfNeeded() {
    let currentStatus = manager.authorizationStatus
    guard currentStatus != authorizationStatus else { return }
    authorizationStatus = currentStatus
    switch currentStatus {
    case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
    case .denied, .restricted: location = nil; displayLocationName = nil; apiSearchCityName = nil
    case .notDetermined: break
    @unknown default: break
    }
}
```
- `manager.authorizationStatus`: sistemden O ANKİ GERÇEK izin durumunu OKUYOR (bizim ESKİDEN kaydettiğimiz
  `authorizationStatus` DEĞİL — bu satır İKİSİNİ birbirinden AYIRT ETMEK için önemli).
- `guard currentStatus != authorizationStatus else { return }`: durum GERÇEKTEN DEĞİŞMEDİYSE hiçbir
  şey yapma (gereksiz konum güncellemesi/temizleme TETİKLENMESİN).
- `case .authorizedWhenInUse, .authorizedAlways:` — VİRGÜLLE ayrılmış birden fazla case AYNI bloğu
  paylaşıyor ("bu İKİSİNDEN biri olursa").
- `case .denied, .restricted: location = nil; ...`: TEK satırda ÜÇ atama, `;` (noktalı virgül) ile
  ayrılmış — Swift'te normalde her satır kendi ifadesidir, `;` birden fazla ifadeyi AYNI satıra
  sıkıştırmaya izin veriyor.
- `@unknown default:`: Apple gelecekte YENİ bir `CLAuthorizationStatus` case'i EKLERSE (bizim şu an
  bilmediğimiz), derleyici bunu YAKALASIN diye — `default` ile AYNI işi görür ama derleyici, yeni bir
  case eklendiğinde bu switch'i "eksik" diye İŞARETLEMEZ (normal `default` sessizce yutardı, `@unknown
  default` ise en azından bir UYARI verir).

```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    DispatchQueue.main.async {
        self.authorizationStatus = manager.authorizationStatus
        if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
            self.manager.startUpdatingLocation()
        }
    }
}
```
- Bu, `CLLocationManagerDelegate`'in İSTEDİĞİ bir fonksiyon — CoreLocation, izin durumu her
  DEĞİŞTİĞİNDE bunu KENDİSİ çağırıyor (biz elle çağırmıyoruz).
- `DispatchQueue.main.async { ... }`: "bu bloğu ANA İŞ PARÇACIĞINDA çalıştır" — CoreLocation'ın delegate
  çağrıları HER ZAMAN ana thread'de gelmeyebiliyor (eski Objective-C API'lerin genel bir özelliği),
  `@Published` alanları güncellemek İÇİN ana thread'e GEÇMEMİZ gerekiyor.

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let newLocation = locations.last else { return }
    DispatchQueue.main.async {
        self.location = newLocation.coordinate
        self.manager.stopUpdatingLocation()
    }
    guard let request = MKReverseGeocodingRequest(location: newLocation) else { return }
    Task {
        do {
            let fetchedMapItems = try await request.mapItems
            if let mapItem = fetchedMapItems.first, let address = mapItem.address {
                let locationString = address.shortAddress ?? ""
                await MainActor.run {
                    self.displayLocationName = locationString.isEmpty ? "Konum Bulunamadı" : locationString
                    let components = locationString.components(separatedBy: ",")
                    if let lastComponent = components.last?.trimmingCharacters(in: .whitespaces), !lastComponent.isEmpty {
                        self.apiSearchCityName = lastComponent
                    } else {
                        self.apiSearchCityName = locationString
                    }
                }
            }
        } catch {
            print("Adres çözümlenemedi: \(error.localizedDescription)")
        }
    }
}
```
- `locations: [CLLocation]`: CoreLocation konum güncellemelerini BAZEN birden fazla ölçüm olarak BİRLİKTE
  verebiliyor; `.last` en GÜNCEL (en son alınan) ölçümü alıyor.
- `MKReverseGeocodingRequest(location:)`: iOS 26'nın YENİ (eski `CLGeocoder`'ın yerini alan) ters
  geocoding API'si — bir KOORDİNATI, insan OKUNABİLİR bir adrese çeviriyor. Başarısız KURULURSA (`nil`
  dönerse, örn. geçersiz koordinat) `guard` ile sessizce çıkıyoruz.
- `try await request.mapItems`: BU İSTEK gerçekten ağ/sistem servisi çağrısı, `async throws`.
- `mapItem.address?.shortAddress`: iOS 26'nın YENİ, YAPILANDIRILMIŞ adres tipi (`MKAddress`) — ESKİ
  `mapItem.placemark` API'si ARTIK DEPRECATED (kullanımdan kaldırıldı), bu yüzden onu KULLANMIYORUZ.
- `locationString.components(separatedBy: ",")`: adresi VİRGÜLE göre parçalara ayırıyor ("Melikgazi,
  Kayseri" → ["Melikgazi", " Kayseri"]); `.last` SON parçayı (genelde şehir/il) alıyor —
  `apiSearchCityName`, favoriler İÇİN DEĞİL, "mevcut konum" kartının API sorgusu İÇİN kullanılıyor.
- `.trimmingCharacters(in: .whitespaces)`: virgülden sonraki BAŞTAKİ boşluğu ("  Kayseri" → "Kayseri")
  temizliyor.
- `await MainActor.run { ... }`: `Task` içindeki bu blok `@Published` alanları güncellediği için
  AÇIKÇA ana actor'a (MainActor) geçiyoruz.
- `catch { print(...) }`: adres çözümlenemezse SADECE konsola YAZIYORUZ, kullanıcıya bir HATA
  GÖSTERMİYORUZ — "mevcut konum" kartı bu durumda sadece "Adres Çözümleniyor..." yazmaya DEVAM ediyor
  (bkz. `HomeView.locationWeatherCard`), uygulamayı BOZMUYOR.

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("GPS Hatası: Konum alınamadı. \(error.localizedDescription)")
}
```
- Delegate'in istediği bir başka fonksiyon — GPS/konum tamamen BAŞARISIZ olursa (uçak modu gibi)
  çağrılıyor; bu proje sadece KONSOLA yazıp geçiyor (kritik bir özellik olmadığı için kullanıcıyı
  RAHATSIZ eden bir hata ekranı GÖSTERMİYORUZ).

### `Services/LocationSearchService.swift`
```swift
class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = "" {
        didSet { searchCompleter.queryFragment = searchQuery }
    }
    @Published var searchResults: [MKLocalSearchCompletion] = []
    private var searchCompleter: MKLocalSearchCompleter
    ...
}
```
- `@Published var searchQuery = "" { didSet { ... } }`: bir property'nin `didSet` bloğu, DEĞERİ
  DEĞİŞTİĞİ HER SEFERİNDE (yeni değer atandıktan HEMEN sonra) otomatik ÇALIŞIYOR — kullanıcı her harf
  yazdığında bu BLOK tetikleniyor ve MapKit'in kendi arama motoruna (`searchCompleter`) bu METNİ
  iletiyor.

```swift
override init() {
    searchCompleter = MKLocalSearchCompleter()
    super.init()
    searchCompleter.delegate = self
    searchCompleter.resultTypes = .address
}
```
- Burada `super.init()`'İN ÖNCESİNDE `searchCompleter`'a değer VERİLİYOR — Swift kuralı: bir class'ın
  KENDİ (miras almadığı) stored property'leri, `super.init()` çağrılmadan ÖNCE mutlaka bir DEĞERE sahip
  olmalı.
- `resultTypes = .address`: arama sonuçlarını sadece ADRES/YERLEŞİM türleriyle SINIRLIYOR (işletme/kafe
  gibi POI sonuçlarını İSTEMİYORUZ).

```swift
func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    DispatchQueue.main.async {
        self.searchResults = completer.results
    }
}
func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    print("Arama tamamlayıcı hatası: \(error.localizedDescription)")
}
```
- `completerDidUpdateResults`: Apple ARAMA SONUÇLARINI her BULDUĞUNDA (kullanıcı yazmaya devam ederken
  sürekli) bu fonksiyonu ÇAĞIRIYOR; sonuçları `@Published searchResults`'a yazıp arayüzü GÜNCELLİYORUZ.

```swift
func resolve(_ completion: MKLocalSearchCompletion) async -> WeatherLocation? {
    await geocode(text: completion.title, fallbackName: Self.shortName(from: completion.title))
}
func resolve(freeText: String) async -> WeatherLocation? {
    await geocode(text: freeText, fallbackName: Self.shortName(from: freeText))
}
private static func shortName(from title: String) -> String {
    title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? title
}
private func geocode(text: String, fallbackName: String) async -> WeatherLocation? {
    guard let request = MKGeocodingRequest(addressString: text) else {
        return .name(fallbackName)
    }
    guard let mapItems = try? await request.mapItems, !mapItems.isEmpty else {
        return .name(fallbackName)
    }
    let normalizedFallback = fallbackName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let mapItem = mapItems.first { item in
        [item.name, item.addressRepresentations?.cityName].compactMap { $0 }.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedFallback
        }
    } ?? mapItems[0]
    let coordinate = mapItem.location.coordinate
    return .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: fallbackName)
}
```
- İKİ GENEL (public) fonksiyon, TEK bir `private` yardımcıya (`geocode(text:fallbackName:)`) YÖNLENİYOR
  — biri bir ÖNERİYİ (kullanıcı dropdown'dan seçti), diğeri SERBEST METNİ (Enter'a bastı) çözüyor.
- **Yaşanan bir hata (üç denemede çözüldü)**: "İstanbul" arayıp seçtiğinizde "Karaköy" geliyordu,
  "Kadıköy" arayıp seçtiğinizde "Üsküdar" gibi — üstüne bazı aramalar YAVAŞ çalışıp hata da veriyordu.
  1. İLK denemede `MKLocalSearch.Request`'İN döndürdüğü sonuçlar arasında İSİM eşleştirmesi yaparak
     ÇÖZMEYE çalıştık — YETMEDİ, çünkü `MKLocalSearch` bir POI/İŞLETME arama MOTORU; geniş bir
     YERLEŞİM ismi verildiğinde o isimde bir sonuç HİÇ döndürmeyebiliyordu.
  2. İKİNCİ denemede `MKGeocodingRequest`'e (iOS 26) geçtik — ama CANLI testte hem YAVAŞ çalıştı hem
     hata verdi hem de "Kadıköy" gibi SPESİFİK bir arama bile YANLIŞ ("Üsküdar") sonuca çözülebildi.
  3. ÜÇÜNCÜ denemede `CLGeocoder`'a geçtik — Apple'ın 10+ yıldır TAM OLARAK bu iş için kullandığı,
     olgun API. Ama iOS 26'da bu API DEPRECATED işaretli olduğu için Xcode SÜREKLİ iki uyarı veriyordu;
     üstelik (bkz. `Kod-Rehberi.md`'deki 4. madde) o sıradaki "yanlış semt" hatasının GERÇEK kaynağı
     zaten BU dosya değil, `Models/WeatherLocation.swift`'teki isim eşlemesiymiş — yani `MKGeocodingRequest`
     hiç SUÇLU değilmiş. `displayName` zaten `fallbackName`'e SABİT olduğu ve aşağıdaki isim-eşleştirme
     güvence katmanı KORUNDUĞU için, koordinatı hangi API'nin sağladığı sonucu pratikte DEĞİŞTİRMİYOR.
     Bu yüzden uyarıları temizlemek için `MKGeocodingRequest`'e GERİ DÖNDÜK — kod aşağıda bunu gösteriyor.
- `guard let request = MKGeocodingRequest(addressString: text) else { return .name(fallbackName) }`:
  `MKGeocodingRequest`'in başlatıcısı (init) BAŞARISIZ olabilen (`init?`) bir başlatıcı — metin
  ÇÖZÜMLENEMEYECEK kadar anlamsızsa `nil` DÖNÜYOR, biz de bu durumda sadece İSİMLE aramaya DÜŞÜYORUZ.
- `try? await request.mapItems`: `mapItems`, Objective-C tarafında `(NSArray<MKMapItem *>*?, NSError*?) -> Void`
  COMPLETION HANDLER'lı bir metotken, `NS_SWIFT_ASYNC_NAME(getter:mapItems())` işaretlemesiyle Swift'e
  `async throws` bir COMPUTED PROPERTY olarak yansıtılmış — biz elle bir `async` sarmalayıcı YAZMADIK,
  bu dönüşümü Apple'ın kendi API tanımı sağlıyor (aynı `CLGeocoder`'da olduğu gibi).
- `fallbackName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)`:
  `.folding(options:locale:)`, bir METNİ "sadeleştirilmiş" bir FORMA çeviriyor — `.caseInsensitive`
  büyük/küçük harf FARKINI, `.diacriticInsensitive` aksan/noktalama FARKLARINI (Türkçe'nin İ/ı, İngilizce'nin
  é/e gibi) YOK SAYIYOR.
- `mapItems.first { ... } ?? mapItems[0]`: dönen ADAYLAR arasında ismi/şehri (`item.name`/
  `item.addressRepresentations?.cityName` — eski `CLPlacemark`'ın `name`/`locality`'sinin iOS 26'daki
  KARŞILIĞI) arananla TAM eşleşen bir TANESİ varsa onu TERCİH ediyoruz, yoksa MapKit'in en OLASI
  saydığı ilk sonuca DÜŞÜYORUZ — bu artık sadece KOORDİNAT doğruluğu için bir güvence, isim seçimi
  İÇİN değil (bkz. alt satır).
- `mapItem.location.coordinate`: iOS 26'daki `MKMapItem.location`, eski `CLPlacemark.location`'IN
  aksine OPTIONAL bile DEĞİL (`CLLocation`, `CLLocation?` değil) — bu yüzden burada AYRICA bir
  `guard let` gerekmiyor.
- `return .coordinate(..., displayName: fallbackName)`: **en kritik satır** — GÖSTERİLEN isim ARTIK
  HER ZAMAN kullanıcının aradığı/seçtiği METİN (`fallbackName`), geocoding servisinin kendi ürettiği
  (ve yanlış komşu semte KAYABİLEN) isim DEĞİL. Böylece koordinat ufak bir SAPMA taşısa bile, EKRANDA
  görünen isim HER ZAMAN kullanıcının aradığı yerle BİREBİR eşleşiyor.
- `private static func shortName(from title: String) -> String`: **yaşanan bir hata** — isim ARTIK
  DOĞRU şehri gösteriyordu ama "İstanbul, İstanbul, Türkiye" gibi BİLEŞİK geliyordu, çünkü ŞEHİR ile
  İL ismi AYNI olan yerlerde (İstanbul hem şehir hem il) MapKit'in completer'ı `title`'ı BİLEREK
  hiyerarşik veriyor. `title.components(separatedBy: ",").first`: metni VİRGÜLE göre parçalayıp İLK
  parçayı (gerçek yer İSMİ) alıyor, geri kalanı (il/ülke) ATIYOR. ÖNEMLİ ayrım: bu sadeleştirme sadece
  `fallbackName`'E (GÖSTERİM) uygulanıyor — `geocode(text:fallbackName:)`'e giden `text` parametresi
  (GERÇEK sorgu) HÂLÂ TAM hiyerarşik hâliyle KALIYOR, çünkü MapKit'e ("İstanbul, İstanbul, Türkiye"
  gibi) DAHA FAZLA bağlam vermek, DAHA DOĞRU bir koordinat çözümlemesi sağlıyor — sadece EKRANDA
  gösterileni sadeleştiriyoruz, ARAMANIN kendisini değil.

---

## Utilities/

### `Utilities/WMOWeatherCode.swift`
```swift
nonisolated enum WMOWeatherCode {
    static func legacyConditionCode(for wmoCode: Int) -> Int {
        switch wmoCode {
        case 0:  return 800
        case 1:  return 801
        ...
        default: return 800
        }
    }
    static func localizedDescription(for wmoCode: Int) -> String {
        switch wmoCode {
        case 0:  return String(localized: "wmo.clear", defaultValue: "Açık")
        ...
        default: return String(localized: "wmo.unknown", defaultValue: "Bilinmiyor")
        }
    }
    static func systemIconName(for legacyConditionCode: Int, isNight: Bool = false) -> String {
        switch legacyConditionCode {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800:       return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 801...804: return isNight ? "cloud.moon.fill" : "cloud.fill"
        default:        return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        }
    }
}
```
- `nonisolated enum`: sadece `static` fonksiyonlar barındıran bir enum bile (proje varsayılanı yüzünden)
  MainActor'a KAYIYORDU; `nonisolated` bunu düzeltiyor (bkz. Bölüm 1).
- İçinde HİÇBİR `case` YOK — bu enum bir VERİ tipi değil, sadece iki `static` fonksiyonu bir ARADA tutmak
  için bir "isim alanı" (namespace) olarak KULLANILIYOR (Swift'te bu YAYGIN bir desen: durumsuz yardımcı
  fonksiyonları bir `enum` altında toplamak, çünkü boş bir `enum`'un ÖRNEĞİ yaratılamaz — yanlışlıkla
  `WMOWeatherCode()` yazıp bir NESNE oluşturmaya ÇALIŞILAMAZ).
- `legacyConditionCode`: Open-Meteo'nun standart WMO kodunu (0-99), `CityWeather.systemIconName` gibi
  yerlerin ZATEN bildiği ESKİ OpenWeather aralık numaralarına (200-232, 300-321 vb.) çeviriyor — TEMSİLİ
  bir sayı seçiyoruz (mesela WMO 61 → 500), gerçek OpenWeather kodunun AYNISI olması ÖNEMLİ değil, sadece
  DOĞRU ARALIĞA düşmesi yeterli.
- `localizedDescription`: Open-Meteo hazır bir açıklama METNİ VERMİYOR, sadece sayı — bu yüzden metni
  KENDİMİZ üretiyoruz, `String(localized:defaultValue:)` ile `Localizable.xcstrings` kataloğundan.
- `systemIconName(for:isNight:)`: ekrandaki ikonun adını seçen switch — **temizlik**: eskiden bu switch
  HEM `CityWeather.systemIconName`'de HEM `DailyForecast.systemIconName`'de neredeyse BİREBİR aynı
  şekilde iki kere yazılıyordu, aralarındaki tek fark gece/gündüz durumuydu. Tek fonksiyona toplayıp
  `isNight: Bool = false` VARSAYILAN DEĞERİYLE parametreledik — `CityWeather` kendi gerçek `isNight`
  değerini yolluyor, `DailyForecast` (bir GELECEK günün "şu an gece mi" diye bir anlamı olmadığı için)
  hiç vermiyor, varsayılana (`false`, hep gündüz ikonu) düşüyor.

### `Utilities/RelativeDayFormatter.swift`
```swift
enum RelativeDayFormatter {
    static func label(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return String(localized: "day.today", defaultValue: "Bugün") }
        if calendar.isDateInTomorrow(date) { return String(localized: "day.tomorrow", defaultValue: "Yarın") }
        let locale = Locale.autoupdatingCurrent
        return date.formatted(.dateTime.weekday(.wide).locale(locale)).capitalized(with: locale)
    }
}
```
- `calendar.isDateInToday(date)`/`.isDateInTomorrow(date)`: `Calendar`'ın HAZIR fonksiyonları — "bu
  tarih BUGÜN mü/YARIN mı" sorusunu, GÜN SINIRLARINI (gece yarısı) doğru hesaplayarak cevaplıyor
  (elle `Date` çıkarma/karşılaştırma yapmaktan çok daha GÜVENLİ).
- `calendar` parametre olarak GELİYOR (global `Calendar.current` KULLANILMIYOR) — çağıran taraf
  (`DailyForecastRow`) BİLEREK şehrin KENDİ saat dilimine göre kurulmuş bir `Calendar` veriyor, aksi
  halde yurt dışı bir şehirde "bugün" YANLIŞ güne denk gelebilirdi.
- `Locale.autoupdatingCurrent`: sistem dili DEĞİŞTİĞİNDE bu değer OTOMATİK güncelleniyor (uygulamayı
  yeniden BAŞLATMAYA gerek KALMADAN) — eskiden `Locale(identifier: "tr_TR")` SABİTLENMİŞTİ.
- `date.formatted(.dateTime.weekday(.wide).locale(locale))`: Foundation'ın YENİ (`FormatStyle` tabanlı)
  tarih biçimlendirme sözdizimi — "bu tarihin, GENİŞ biçimli (Pazartesi, Salı... kısaltılmamış) haftanın
  günü ismini, BELİRTİLEN locale'e göre ver" demek.
- `.capitalized(with: locale)`: gün isminin İLK harfini locale'e UYGUN şekilde büyük harfe çeviriyor
  (bazı dillerde büyük/küçük harf kuralları FARKLI olabiliyor, bu yüzden LOCALE-FARKINDA bir çağrı).

### `Utilities/PercentFormatting.swift`
```swift
extension Int {
    var percentFormatted: String {
        let format = String(localized: "format.percent", defaultValue: "%%%d")
        return String(format: format, self)
    }
}
```
- `Int`'e (Swift'in kendi tipi) `percentFormatted` adlı YENİ bir computed property EKLİYORUZ (bkz. Bölüm
  1 — `extension`) — artık HER `Int` değeri (`65.percentFormatted` gibi) bunu ÇAĞIRABİLİYOR.
- `"%%%d"`: bir FORMAT DİZESİ — `%%` LİTERAL bir `%` karakteri anlamına geliyor (format dizelerinde TEK
  bir `%` özel bir anlam TAŞIDIĞI için, GERÇEK bir yüzde işareti yazmak için İKİ tane yazılır), `%d` ise
  "buraya bir TAM SAYI gelecek" demek. Türkçe'de sonuç "%65" (işaret ÖNDE), İngilizce çeviride ise format
  dizesi "%d%%" OLACAK ŞEKİLDE çevrilebiliyor (işaret SONDA) — sıra, KATALOGTAKİ çeviriye göre değişiyor.
- `String(format: format, self)`: `self` burada `Int`'İN KENDİSİ (extension İÇİNDEYKEN `self`, o anki
  `Int` DEĞERİNİ temsil ediyor) — format dizesindeki `%d`'nin YERİNE konuyor.

---

## ViewModels/

### `ViewModels/WeatherViewModel.swift`
```swift
struct HourlyForecast {
    let time: Date
    let temperature: Double
    let pop: Double
}
enum WeatherViewState: Equatable {
    case idle
    case loading
    case success(CityWeather)
    case error(String)
}
```
- `HourlyForecast`: grafik İÇİN temiz, düz bir veri kalıbı. **Temizlik**: eskiden `Identifiable, Equatable`'a
  uyuyordu ve `let id = UUID()` alanı vardı — ama tek kullanıldığı yer olan `WeatherContentView`'daki
  `ForEach`, `id: \.offset` diyerek KENDİ kimliğini kullanıyordu, yani `id`/`Identifiable` hiç
  OKUNMUYORDU; `Equatable`'ı da hiçbir yerde `==` ile KARŞILAŞTIRAN yoktu. Üstelik her `UUID()` HER
  yeni veri çekişinde RASTGELE değiştiği için, bu `Equatable` bir gün kullanılsaydı bile İKİ AYNI SAAT
  verisini asla eşit BULMAYACAKTI — kullanılmayan VE potansiyel bir tuzak olan bir alandı, kaldırdık.
- `WeatherViewState`: bir ekranın OLABİLECEĞİ TÜM durumları TEK bir yerde toplayan durum makinesi (bkz.
  Bölüm 1 — `enum`) — "hem yükleniyor hem BAŞARILI" gibi İMKANSIZ bir durum bu tip sistemiyle baştan
  ENGELLENİYOR.

```swift
enum TemperatureUnit: String {
    case celsius, fahrenheit
    var symbol: String { switch self { case .celsius: return "°C"; case .fahrenheit: return "°F" } }
    func format(_ celsius: Double) -> String {
        switch self {
        case .celsius: return "\(Int(celsius.rounded()))°"
        case .fahrenheit:
            let fahrenheit = celsius * 9 / 5 + 32
            return "\(Int(fahrenheit.rounded()))°"
        }
    }
}
```
- `: String` (bkz. Bölüm 1 — rawValue): `TemperatureUnit(rawValue: "celsius")` gibi bir METİNDEN geri
  KURULABİLMESİ için (UserDefaults'tan OKURKEN kullanılıyor, aşağıda görülecek).
- `format(_:)`: API'den HER ZAMAN Celsius ALIYORUZ; bu fonksiyon SADECE gösterim ANINDA Fahrenayt'a
  ÇEVİRİYOR — birim değiştirmek için ağa TEKRAR gitmeye GEREK YOK, sadece bu fonksiyon FARKLI bir dal
  ÇALIŞTIRIYOR.
- `\(Int(celsius.rounded()))°`: string interpolation İÇİNDE bir HESAPLAMA — önce YUVARLA, sonra `Int`'e
  ÇEVİR, sonra metnin İÇİNE göm, sonuna derece işareti EKLE.

```swift
enum WindSpeedUnit: String {
    case kilometersPerHour, milesPerHour
    func format(_ kmh: Double) -> String {
        switch self {
        case .kilometersPerHour: return String(format: String(localized: "wind.speed_kmh_format", defaultValue: "%.0f km/s"), kmh)
        case .milesPerHour:
            let mph = kmh * 0.621371
            return String(format: String(localized: "wind.speed_mph_format", defaultValue: "%.0f mph"), mph)
        }
    }
}
```
- `%.0f`: format dizesinde "bir ONDALIK sayıyı (float/double), VİRGÜLDEN SONRA SIFIR basamakla" göster
  demek — yani en yakın TAM sayıya yuvarlayıp yazdırıyor.
- `kmh * 0.621371`: km/s'yi mph'e çeviren SABİT dönüşüm katsayısı (fizik sabiti, uydurma değil).

```swift
@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var state: WeatherViewState = .idle
    @Published private(set) var hourlyForecast: [HourlyForecast] = []
    @Published private(set) var dailyForecast: [DailyForecast] = []
    @Published private(set) var airQuality: AirQuality?
    @Published private(set) var lastUpdated: Date?
    @Published var savedCities: [FavoriteCity] = [] { didSet { persistSavedCities() } }
    @Published private(set) var favoriteSnapshots: [String: CityWeather] = [:] { didSet { persistFavoriteSnapshots() } }
    @Published var preferredUnit: TemperatureUnit { didSet { UserDefaults.standard.set(preferredUnit.rawValue, forKey: "PreferredUnitKey") } }
    @Published var preferredWindUnit: WindSpeedUnit { didSet { UserDefaults.standard.set(preferredWindUnit.rawValue, forKey: "PreferredWindUnitKey") } }
    private let service: any WeatherServiceProtocol
    private var fetchTask: Task<Void, Never>?
    ...
}
```
- `final class`: `final`, "bu class'tan BAŞKA bir class TÜRETİLEMEZ (miras alınamaz)" demek — derleyici
  bu bilgiyle bazı ÇAĞRILARI daha HIZLI optimize edebiliyor, ayrıca "yanlışlıkla alt sınıf yaratılmasın"
  diye bir NİYET beyanı.
- `@Published private(set) var state`: `private(set)` demek "bu değeri DIŞARIDAN (View'lardan) OKUYABİLİRSİN
  ama SADECE bu class'ın İÇİNDEN değiştirebilirsin" — View'lar YANLIŞLIKLA `viewModel.state = .idle`
  YAZAMASIN diye (state SADECE `fetchWeather` üzerinden DEĞİŞMELİ).
- `savedCities`/`favoriteSnapshots` NEDEN `didSet` ile diske YAZIYOR: `@Published`, sadece SwiftUI'a
  "değişti, yeniden çiz" haber VERİYOR — DİSKE kaydetme ayrı, KENDİ yazdığımız bir iş, `didSet` bunu
  HER değişiklikte otomatik TETİKLİYOR.
- `Task<Void, Never>?`: `Task`'ın İKİ generic parametresi var — birincisi "BAŞARIYLA biterse ne
  DÖNDÜRÜR" (`Void` = hiçbir şey), İKİNCİSİ "NE tür bir hata FIRLATABİLİR" (`Never` = ASLA hata
  fırlatmaz, çünkü `fetchWeather` İÇİNDE zaten `do/catch` ile TÜM hatalar YAKALANIYOR). `?` optional
  çünkü BAŞLANGIÇTA henüz hiçbir istek YOK.

```swift
init(service: any WeatherServiceProtocol = WeatherService()) {
    self.service = service
    self.savedCities = Self.loadSavedCities()
    self.preferredUnit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "PreferredUnitKey") ?? "") ?? .celsius
    self.preferredWindUnit = WindSpeedUnit(rawValue: UserDefaults.standard.string(forKey: "PreferredWindUnitKey") ?? "") ?? .kilometersPerHour
    self.favoriteSnapshots = Self.loadFavoriteSnapshots()
}
```
- `service: any WeatherServiceProtocol = WeatherService()`: parametrenin bir VARSAYILAN DEĞERİ var —
  çağıran taraf HİÇBİR ŞEY VERMEZSE gerçek `WeatherService()` KULLANILIYOR; testler İSTERSE sahte bir
  servis GEÇEBİLİR (`WeatherViewModel(service: MockWeatherService())` gibi) — protokol SAYESİNDE bu
  MÜMKÜN.
- `TemperatureUnit(rawValue: ...) ?? .celsius`: `rawValue:` İLE başlatıcı (initializer) bir enum'u bir
  STRING'DEN geri KURMAYA çalışıyor, METIN o enum'un HİÇBİR case'ine UYMUYORSA (ilk açılış, henüz hiç
  kaydedilmemiş) `nil` DÖNÜYOR — `??` ile VARSAYILAN olarak `.celsius`'a düşüyoruz.

```swift
func fetchWeather(for location: WeatherLocation) {
    fetchTask?.cancel()
    state = .loading
    hourlyForecast = []
    dailyForecast = []
    airQuality = nil
    fetchTask = Task {
        do {
            let bundle = try await service.fetchWeather(at: location)
            guard !Task.isCancelled else { return }
            let weather = bundle.current
            hourlyForecast = bundle.hourly
            dailyForecast = bundle.daily
            state = .success(weather)
            lastUpdated = .now
            if isFavorite(weather.name) {
                favoriteSnapshots[normalized(weather.name)] = weather
            }
            airQuality = try? await service.fetchAirQuality(lat: weather.lat, lon: weather.lon)
        } catch is CancellationError {
        } catch {
            guard !Task.isCancelled else { return }
            state = .error((error as? WeatherError)?.errorDescription ?? "Beklenmedik bir hata oluştu.")
        }
    }
}
```
- `fetchTask?.cancel()`: ÖNCEKİ (varsa) isteği İPTAL ediyor — kullanıcı HIZLICA başka bir şehre geçerse,
  YAVAŞ kalan eski isteğin CEVABI yeni ekranı EZMESİN diye.
- `state = .loading`/diğer temizlikler: YENİ istek başlamadan ÖNCE ekranı "temiz bir sayfa" HÂLİNE
  getiriyor — eski şehrin verisi BİR AN bile yeni şehrin ekranında GÖZÜKMESİN diye.
- `fetchTask = Task { ... }`: yeni işi BAŞLATIYOR ve referansını SAKLIYOR (bir SONRAKİ çağrıda İPTAL
  edebilmek için).
- `guard !Task.isCancelled else { return }`: `await` SONRASI, bu Task İPTAL EDİLMİŞ Mİ diye KONTROL —
  iptal edildiyse SONUCU işlemeden ÇIK (zaten kimse bu sonuca BAKMIYOR).
- `if isFavorite(weather.name) { favoriteSnapshots[...] = weather }`: gelen sonuç ZATEN bir favoriye
  AİTSE, önbelleği HEMEN güncelle — favori listesine DÖNÜLDÜĞÜNDE eski/bayat veri GÖRÜNMESİN.
- `airQuality = try? await ...`: hava kalitesi İKİNCİL bir bilgi — `try?` sayesinde BAŞARISIZ olursa
  sadece `nil` KALIYOR, TÜM ekranı hataya DÜŞÜRMÜYOR.
- `catch is CancellationError { }`: `is`, bir hatanın BELİRLİ bir TİPTE olup olmadığını KONTROL ediyor;
  İPTAL hatasıysa hiçbir şey YAPMIYORUZ (kullanıcıya göstermeye DEĞMEZ, bu bizim KENDİ `cancel()`
  çağrımızın SONUCU).
- `(error as? WeatherError)?.errorDescription ?? "..."`: hata BİZİM `WeatherError` türümüzdense KENDİ
  mesajını KULLAN, DEĞİLSE (beklenmedik bir sistem hatası) GENEL bir mesaja DÜŞ.

```swift
func refreshFavoriteSnapshots() {
    for favorite in savedCities {
        Task {
            if let bundle = try? await service.fetchWeather(at: favorite.location) {
                favoriteSnapshots[normalized(favorite.name)] = bundle.current
            }
        }
    }
}
```
- `for favorite in savedCities { Task { ... } }`: HER favori İÇİN AYRI, BAĞIMSIZ bir arka plan işi
  BAŞLATIYOR — hepsi PARALEL (aynı anda) çalışıyor, biri YAVAŞ kalırsa DİĞERLERİNİ BEKLETMİYOR.
- `favorite.location`: `FavoriteCity.location` computed property'si (bkz. `Models/FavoriteCity.swift`) —
  koordinat BİLİNİYORSA kesin sonuç verir, bilinmiyorsa isimle DÜŞER.

```swift
func toggleFavorite(name: String, weather: CityWeather?) {
    if isFavorite(name) {
        savedCities.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        favoriteSnapshots.removeValue(forKey: normalized(name))
    } else if let weather, weather.name.caseInsensitiveCompare(name) == .orderedSame {
        savedCities.append(FavoriteCity(name: weather.name, lat: weather.lat, lon: weather.lon))
        favoriteSnapshots[normalized(weather.name)] = weather
    }
}
func isFavorite(_ city: String) -> Bool {
    savedCities.contains { $0.name.caseInsensitiveCompare(city) == .orderedSame }
}
private func normalized(_ city: String) -> String { city.lowercased() }
```
- `weather: CityWeather?`: SADECE EKLEME için gerekli — ÇIKARMA çağrılarında `nil` GEÇİLİYOR (bkz.
  `HomeView`/`WeatherView`), çünkü çıkarmak İÇİN sadece İSME ihtiyaç var.
- `.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }`: `removeAll(where:)` — closure
  `true` DÖNDÜRDÜĞÜ HER elemanı diziden ÇIKARIYOR. `$0`, closure'ın İLK (ve tek) parametresine kısayol
  isim (yazmadan) — burada `$0` bir `FavoriteCity`.
- `.caseInsensitiveCompare(name) == .orderedSame`: İKİ metni BÜYÜK/KÜÇÜK harf FARKINI GÖZ ARDI ederek
  karşılaştırıyor — "Kayseri" ile "kayseri" AYNI favori SAYILSIN diye.
- `else if let weather, weather.name.caseInsensitiveCompare(name) == .orderedSame`: İKİ koşul BİRDEN:
  `weather` NİL DEĞİL VE onun ismi, favoriye EKLENMEK istenen isimle EŞLEŞİYOR (nadir bir UYUMSUZLUK
  durumuna karşı SAVUNMA).
- `.contains { ... }`: dizide closure'ı `true` yapan EN AZ BİR eleman VAR MI diye kontrol EDİYOR, `Bool`
  döndürüyor.

```swift
func recordFreshSnapshot(_ weather: CityWeather) {
    guard isFavorite(weather.name) else { return }
    favoriteSnapshots[normalized(weather.name)] = weather
}
```
- Bu fonksiyon, `fetchWeather(for:)`'IN İÇİNDE zaten var olan "veri favoriyse ÖNBELLEĞE yaz" satırının
  DIŞARIDAN da ÇAĞRILABİLEN, AYRI bir haline ÇIKARILMIŞ hâli.
- Bu fonksiyon `fetchWeather(for:)`'IN İÇİNDEN otomatik çağrılıyor (bkz. YUKARIDAKİ `fetchWeather(for:)`
  koduna, `recordFreshSnapshot(weather)` satırına) — `WeatherView`'da HANGİ şehir gösteriliyorsa (favori
  listesinden ya da favori-değiştirme şeridinden SEÇİLMİŞ olsun) O şehrin taze VERİSİ FAVORİLER
  listesine HER ZAMAN ANINDA yansıyor, AYRICA elle çağırmaya GEREK yok (bkz. `Views/WeatherView.swift`
  bölümündeki MİMARİ karar notu — eskiden bu iş için AYRI bir `CarouselPageModel` VARDI, artık TEK
  paylaşılan `viewModel.state` yeterli).

```swift
private static func loadSavedCities() -> [FavoriteCity] {
    if let data = UserDefaults.standard.data(forKey: "SavedCitiesKey"),
       let decoded = try? JSONDecoder().decode([FavoriteCity].self, from: data) {
        return decoded
    }
    let legacyNames = UserDefaults.standard.stringArray(forKey: "SavedCitiesKey") ?? []
    return legacyNames.map { FavoriteCity(name: $0, lat: nil, lon: nil) }
}
private func persistSavedCities() {
    guard let data = try? JSONEncoder().encode(savedCities) else { return }
    UserDefaults.standard.set(data, forKey: "SavedCitiesKey")
}
```
- `UserDefaults.standard`: iOS'un basit, KALICI anahtar-değer DEPOSU (uygulama kapansa/telefon kapansa
  BİLE veriler KALIYOR).
- `if let data = ..., let decoded = try? ...`: İKİ optional'ı ART ARDA açıyor — HEM veri VAR HEM DE
  o veri GEÇERLİ bir `[FavoriteCity]` JSON'una ÇÖZÜLEBİLİYORSA yeni FORMATTAN oku.
- BAŞARISIZ olursa (yeni format HENÜZ hiç KAYDEDİLMEMİŞSE), `stringArray(forKey:)` ile ESKİ (düz metin
  dizisi) FORMATI okuyup her ismi KOORDİNATSIZ bir `FavoriteCity`'e ÇEVİRİYOR — kullanıcı eski
  favorilerini KAYBETMİYOR, sadece onlar koordinat KİLİDİNE (henüz) SAHİP DEĞİL.
- `.map { FavoriteCity(name: $0, lat: nil, lon: nil) }`: `map`, bir DİZİNİN HER elemanını BAŞKA bir
  şeye DÖNÜŞTÜRÜP yeni bir dizi ÜRETİYOR — burada HER isim METNİNİ (`$0`) bir `FavoriteCity`'e
  ÇEVİRİYOR.
- `JSONEncoder().encode(savedCities)`: `[FavoriteCity]` DİZİSİNİ (hepsi `Codable`) JSON `Data`'sına
  ÇEVİRİYOR, `UserDefaults`'a HAM veri (`Data`) olarak KAYDEDİYOR.

```swift
private func fetchBundle... (KALDIRILDI, bkz. WeatherServiceProtocol.fetchWeather(at:))

func snapshotWeather(for location: WeatherLocation) async -> CityWeather? {
    let bundle = try? await service.fetchWeather(at: location)
    return bundle?.current
}
```
- "Mevcut Konum" kartı İÇİN TEK SEFERLİK, SESSİZ bir anlık görüntü — ANA `state` makinesini
  ETKİLEMEDİĞİ için AYRI bir fonksiyon. `bundle?.current`: `bundle` NİL İSE (istek başarısız oldu),
  `.current`'a erişmeye ÇALIŞMADAN direkt `nil` DÖNDÜRÜYOR (optional chaining).

---

## DesignSystem/

### `DesignSystem/Typography.swift`
```swift
extension Font {
    static let weatherHero = Font.system(size: 96, weight: .thin, design: .serif)
    static let weatherCityName = Font.system(size: 34, weight: .regular, design: .serif)
    static let weatherCondition = Font.system(.title3, design: .default).weight(.medium)
    static let weatherSectionHeader = Font.system(.caption, design: .default).weight(.semibold)
    static let weatherCardTitle = Font.system(.caption, design: .default).weight(.semibold)
    static let weatherCardValue = Font.system(.title2, design: .serif).weight(.medium)
    static let weatherRowTitle = Font.system(.title3, design: .default).weight(.semibold)
    static let weatherRowSubtitle = Font.system(.subheadline, design: .default).weight(.regular)
    static let weatherRowTemperature = Font.system(.title2, design: .serif).weight(.regular)
    static let weatherTemperatureSmall = Font.system(.subheadline, design: .serif).weight(.medium)
    static let weatherBody = Font.system(.body, design: .default)
    static let weatherCaption = Font.system(.caption, design: .default)
    static let weatherBrandWordmark = Font.system(size: 20, weight: .medium, design: .serif)
}
```
- `extension Font`: Apple'ın KENDİ `Font` tipine, BİZİM adlandırılmış SABİTLERİMİZİ EKLİYORUZ — kod
  içinde HER YERDE `.font(.weatherHero)` gibi kullanılabiliyor, tıpkı sistemin KENDİ `.title`/`.body`'si
  gibi.
- `Font.system(size:weight:design:)` vs `Font.system(.title3, design:)`: İKİ farklı KURUCU — biri SABİT
  bir PUNTO (`size: 96`) veriyor, DİĞERİ sistemin KENDİ semantik boyutunu (`.title3` gibi) TEMEL ALIYOR
  — semantik olanlar Dynamic Type (kullanıcının SİSTEM genelinde ayarladığı yazı BÜYÜKLÜĞÜ) İLE OTOMATİK
  büyüyüp KÜÇÜLÜYOR, sabit punto olanlar (hero/şehir ismi) BÜYÜK ölçüde SABİT kalıyor (tasarımın
  kompozisyonu bozulmasın diye).
- `design: .serif` vs `design: .default`: `.serif` New York fontunu (Apple'ın SERİFLİ sistem yazı tipi),
  `.default` San Francisco'yu (SERİFSİZ) seçiyor — SADECE SAYISAL değerler (sıcaklık, şehir ismi)
  serif, GERİ KALAN her şey sans; bu KASITLI KARŞITLIK sayıların GÖZE ÇARPMASINI sağlıyor.
- `.weight(.thin)`/`.weight(.medium)` gibi: fontun KALINLIĞINI (stroke ağırlığı) belirliyor.

```swift
extension Text {
    func weatherLabelStyle() -> Text {
        self.font(.weatherCardTitle).tracking(0.6)
    }
}
```
- `extension Text`: SwiftUI'ın `Text` tipine YENİ bir METOT ekliyor — bu METOT, `Text`'in KENDİSİNİ
  (`self`) alıp ÜZERİNE `.font`/`.tracking` UYGULAYIP GERİ döndürüyor (Text bir struct OLDUĞU için
  `self.font(...)` YENİ bir Text DEĞERİ ÜRETİYOR, orijinali DEĞİŞTİRMİYOR).
- `.tracking(0.6)`: HARFLER ARASI boşluğu BÜYÜTÜYOR — Apple'ın "HUMIDITY" gibi büyük harfli sistem
  etiketlerindeki GENİŞ harf aralığı hissini VERİYOR.

### `DesignSystem/BrandHeader.swift`
```swift
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("BrandMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            Text("Nuve")
                .font(.weatherBrandWordmark)
                .tracking(3)
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.82)], startPoint: .leading, endPoint: .trailing))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nuve")
    }
}
```
- `Image("BrandMark")`: `Assets.xcassets` İÇİNDEKİ `BrandMark` adlı görüntü setini YÜKLÜYOR (dosya
  ADINDAN DEĞİL, asset kataloğundaki İSMİNDEN).
- `.renderingMode(.template)`: görüntüyü bir "ŞABLON" gibi davranmaya ZORLUYOR — RENGİ görmezden gelip
  SADECE ALFA (şeffaflık) kanalını KULLANIYOR, gerçek renk `.foregroundStyle`/`.foregroundColor`'DAN
  geliyor. Bu sayede AYNI PNG dosyası, İSTENEN HERHANGİ bir renkte (burada beyaz-gradyan) GÖSTERİLEBİLİYOR.
- `.resizable().scaledToFit()`: görüntünün SABİT piksel boyutunda DEĞİL, VERİLEN çerçeveye (`.frame`)
  ORANINI KORUYARAK sığmasını SAĞLIYOR.
- `.foregroundStyle(LinearGradient(...))`: düz bir RENK yerine bir GRADYAN ile BOYUYOR — hem ikon hem
  yazı, YUKARIDAN/SOLDAN aşağıya/SAĞA doğru HAFİFÇE solan bir beyaz TONU alıyor, tamamen DÜZ beyazdan
  daha "ZARİF" bir izlenim İÇİN.
- `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("Nuve")`: VoiceOver bu İKİ ayrı
  öğeyi (ikon + yazı) AYRI AYRI OKUMASIN, TEK bir "Nuve" olarak DUYURSUN diye — `children: .ignore`
  içindeki ALT öğeleri (Image/Text) VoiceOver'DAN GİZLİYOR, sadece BELİRTTİĞİMİZ etiket OKUNUYOR.

### `DesignSystem/GlassCard.swift`
```swift
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var accentTint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if let accentTint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(accentTint.opacity(0.3))
                            .blur(radius: 20)
                    }
                }
            )
            .glassEffect(.regular.tint(.black.opacity(0.16)), in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder((accentTint ?? .white).opacity(accentTint == nil ? 0.16 : 0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
            .contentShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}
extension View {
    func weatherGlassCard(cornerRadius: CGFloat = 20, accentTint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, accentTint: accentTint))
    }

    @ViewBuilder
    func hiddenListRow(insets: EdgeInsets? = nil) -> some View {
        if let insets {
            self.listRowInsets(insets).listRowBackground(Color.clear).listRowSeparator(.hidden)
        } else {
            self.listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }
}
```
- `ViewModifier`: SwiftUI'ın "bir View'ı DIŞARIDAN SARIP ÜZERİNE bir dizi STİL/DAVRANIŞ EKLEYEN" özel
  bir protokolü — `func body(content: Content) -> some View` İÇİNDE, `content` SARILAN (bu modifier'ı
  KULLANAN) HERHANGİ bir View'ı TEMSİL EDİYOR.
- `func body(content: Content)`: PARAMETRE olarak GELEN `content`'İN üstüne SIRAYLA `.background`,
  `.glassEffect`, `.overlay`, `.shadow`, `.contentShape` UYGULANIYOR — HER modifier ÖNCEKİNİN SONUCUNU
  ALIP YENİ bir View DÖNDÜRÜYOR (ZİNCİRLEME).
- `Group { if let accentTint { ... } }`: `Group`, birden fazla View'ı TEK bir View gibi GÖSTEREN "SANAL"
  bir SARMALAYICI (kendi başına GÖRSEL bir etkisi YOK); İÇİNDEKİ `if let` KOŞULLU olarak (renk
  VERİLMİŞSE) bir bulanık RENK PARILTISI ÇİZİYOR, VERİLMEMİŞSE Group BOŞ kalıyor.
- `.glassEffect(.regular.tint(.black.opacity(0.16)), in:)`: iOS 26'nın YENİ "Liquid Glass" API'si —
  sistemin KENDİ ışık/bulanıklık MOTORUNU kullanarak CAM efekti VERİYOR; `.tint(.black.opacity(0.16))`
  camı HAFİFÇE KARARTIYOR (arka plan NE KADAR PARLAK olursa OLSUN, üstündeki BEYAZ yazının KONTRASTI
  SABİT KALSIN diye).
- `.overlay(RoundedRectangle(...).strokeBorder(...))`: kartın ÜSTÜNE (içeriğin ÖNÜNE) İNCE bir KENARLIK
  ÇİZİYOR — `strokeBorder`, SADECE kenarı ÇİZER, içini DOLDURMAZ (`.fill`'DEN farklı).
- `(accentTint ?? .white).opacity(accentTint == nil ? 0.16 : 0.45)`: kenarlığın RENGİ, `accentTint`
  VERİLMİŞSE o RENK (daha BELİRGİN, 0.45 opaklık), VERİLMEMİŞSE NÖTR beyaz (daha SİLİK, 0.16 opaklık).
- `.contentShape(.rect(cornerRadius:style:))`: kartın DOKUNMA ALANINI, GÖRÜNEN köşe YUVARLAKLIĞIYLA
  BİREBİR aynı ŞEKLE sabitliyor — bu satır OLMADAN, SwiftUI bir Button/NavigationLink'in SADECE
  İÇERİĞİNİN (yazı/ikon) kapladığı ALANI dokunulabilir sayardı, kartın BOŞ kısımlarına DOKUNUNCA HİÇBİR
  ŞEY OLMAZDI.
- `extension View { func weatherGlassCard(...) }`: `.weatherGlassCard(cornerRadius:accentTint:)`
  şeklinde, HERHANGİ bir View'ın ÜZERİNE ÇAĞRILABİLEN bir KISAYOL — `modifier(GlassCard(...))` içeride
  BU modifier'ı GERÇEKTEN uyguluyor; dışarıdan `.weatherGlassCard()` yazmak, `GlassCard()` struct'ını
  ELLE yaratmaktan DAHA OKUNUR.
- `hiddenListRow(insets:)`: `List` satırlarının varsayılan beyaz arka planını/ayırıcı çizgisini gizleyen
  `.listRowBackground(Color.clear) + .listRowSeparator(.hidden)` üçlüsü (bazen bir `.listRowInsets(...)`
  ile birlikte) `HomeView`, `WeatherFilterView`, `SettingsView`, `FilterResultsView`'da tek tek, AYNEN
  tekrar EDİLİYORDU — tek bir yere TOPLADIK.
- `@ViewBuilder func hiddenListRow(...) -> some View { if let insets { ... } else { ... } }`: (bkz.
  Bölüm 1 — `@ViewBuilder`) `if`/`else` dalları FARKLI somut View TİPLERİ döndürüyor (biri `.listRowInsets`
  ZİNCİRİ EKLİYOR, diğeri EKLEMİYOR); `@ViewBuilder` OLMASAYDI bu KOŞULLU dönüş TİP HATASI verirdi —
  `@ViewBuilder` ikisini de TEK bir opak `some View`'A birleştiriyor. `insets` VERİLMEZSE (varsayılan
  `nil`) sistemin kendi satır BOŞLUĞU aynen KALIYOR, VERİLİRSE (örn. camlı bir kart satırı için) o
  boşluk KULLANILIYOR.

### `DesignSystem/WeatherBackground.swift`
```swift
enum WeatherPalette {
    static var isCurrentlyNight: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 6 || hour >= 19
    }

    static func colors(conditionCode: Int, isNight: Bool) -> [Color] {
        isNight ? nightColors(for: conditionCode) : dayColors(for: conditionCode)
    }

    static var chromeColors: [Color] {
        isCurrentlyNight ? chromeColorsNight : chromeColorsDay
    }

    private static let chromeColorsNight: [Color] = [
        Color(red: 0.05, green: 0.08, blue: 0.18),
        Color(red: 0.11, green: 0.15, blue: 0.32)
    ]

    private static let chromeColorsDay: [Color] = [
        Color(red: 0.22, green: 0.30, blue: 0.42),
        Color(red: 0.35, green: 0.44, blue: 0.58)
    ]

    private static func dayColors(for conditionCode: Int) -> [Color] { switch conditionCode { case 200...232: return [...]; ... } }
    private static func nightColors(for conditionCode: Int) -> [Color] { ... }
}
```
- `static var isCurrentlyNight: Bool`: telefonun ŞU ANKİ saatine bakıp, 19:00 İLE 06:00 ARASINDA mıyız
  diye SORUYOR. **Temizlik**: bu hesaplama eskiden SADECE `HomeView` İÇİNDE, `private` bir kopya olarak
  vardı; şimdi burada, TEK bir yerde tanımlı — hem `HomeView`'ın ana arka planı hem de aşağıdaki
  `chromeColors` AYNI bu tek fonksiyona BAKIYOR, aynı hesaplama İKİ YERDE tekrar EDİLMİYOR.
- `static func colors(...)`: gece/gündüz bilgisine göre İKİ AYRI (day/night) renk TABLOSUNDAN BİRİNİ
  seçiyor — üçlü operatör (`isNight ? ... : ...`) bu SEÇİMİ TEK satırda yapıyor.
- `Color(red:green:blue:)`: 0 İLE 1 arası KIRMIZI/YEŞİL/MAVİ bileşenlerinden bir renk KURUYOR — hex kod
  (`#0D1430` gibi) YERİNE Swift'in kendi tipiyle YAZILMIŞ.
- `static var chromeColors: [Color]`: hava durumuna BAĞLI OLMAYAN ekranlar (Ayarlar, Filtre, Filtre
  Sonuçları) İÇİN nötr bir palet — parlak hava durumu RENKLERİNİ (turuncu/mavi) hiç ÖDÜNÇ ALMIYOR,
  SADECE kendi İÇİNDE gece/gündüz arası GEÇİŞ yapıyor. **Yaşanan bir hata**: bu alan ESKİDEN `static let`
  (SABİT) idi, yani HER ZAMAN aynı koyu LACİVERT renkteydi; gündüz vakti ANA ekran açık bir gradyanla
  dururken, Ayarlar'a DOKUNUNCA aniden ZİFİRİ karanlığa DÜŞMESİ tutarsız GÖRÜNÜYORDU. **Çözüm**: `let`
  yerine HESAPLANAN bir `var` yapıp, `isCurrentlyNight`'A göre İKİ nötr palet (`chromeColorsDay`/
  `chromeColorsNight`) ARASINDA seçim YAPTIRDIK — ikisi de HÂLÂ muted/nötr TONLAR, sadece AÇIKLIK
  seviyesi SAATLE birlikte DEĞİŞİYOR.

```swift
enum WeatherParticleStyle: Hashable {
    case rain, storm, snow, stars, clouds, fog, none
    private static func style(forConditionCode conditionCode: Int, isNight: Bool) -> WeatherParticleStyle {
        switch conditionCode {
        case 200...232: return .storm
        case 300...531: return .rain
        case 600...622: return .snow
        case 701...781: return .fog
        case 800: return isNight ? .stars : .none
        case 801...804: return .clouds
        default: return .none
        }
    }
    static func styles(forConditionCodes codes: [Int], isNight: Bool) -> [WeatherParticleStyle] {
        var uniqueStyles: [WeatherParticleStyle] = []
        for code in codes {
            let style = style(forConditionCode: code, isNight: isNight)
            if style != .none, !uniqueStyles.contains(style) {
                uniqueStyles.append(style)
            }
        }
        return uniqueStyles
    }
}
```
- `case rain, storm, snow, stars, clouds, fog, none`: TEK satırda VİRGÜLLE ayrılmış BİRDEN FAZLA `case`
  tanımı — `case rain\ncase storm\n...` yazmakla AYNI anlama geliyor, sadece daha KISA.
- `styles(forConditionCodes:isNight:)`: BİRDEN FAZLA hava kodu (nadiren aynı anda GEÇERLİ olabiliyordu,
  Open-Meteo'ya geçince ARTIK genelde TEK kod var ama MEKANİZMA hâlâ ÇOKLU desteğe HAZIR) TARANIYOR,
  HER biri bir stile ÇEVRİLİYOR, `.none` OLMAYAN ve DAHA ÖNCE eklenmemiş (`!uniqueStyles.contains`)
  stiller BİRİKTİRİLİYOR — sonuç, TEKRARSIZ bir stil LİSTESİ.
- `var uniqueStyles: [WeatherParticleStyle] = []`: BOŞ bir DİZİYLE başlayıp `for` DÖNGÜSÜ İÇİNDE
  `.append(...)` ile BÜYÜTÜLÜYOR — bu, Swift'te YAYGIN bir "BİRİKTİRME" (accumulator) DESENİ.

```swift
struct WeatherParticleLayer: View {
    let style: WeatherParticleStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let seeds: [ParticleSeed]
    private let windTilt: Double

    init(style: WeatherParticleStyle, windDeg: Int? = nil) {
        self.style = style
        self.seeds = (0..<Self.particleCount(for: style)).map { _ in .random() }
        if let windDeg { self.windTilt = sin(Double(windDeg) * .pi / 180) } else { self.windTilt = -0.25 }
    }
    ...
}
```
- `@Environment(\.accessibilityReduceMotion)`: SİSTEMİN "Hareketi Azalt" ERİŞİLEBİLİRLİK ayarını
  OKUYOR — kullanıcı bunu AÇTIYSA animasyonlar DURDURULUYOR (aşağıda göreceğiz).
- `(0..<Self.particleCount(for: style)).map { _ in .random() }`: "0'DAN parçacık SAYISINA kadar bir
  ARALIK" ALINIYOR, `.map` bu aralığın HER elemanı İÇİN (elemanın KENDİSİNİ `_` ile GÖRMEZDEN gelerek)
  bir `ParticleSeed.random()` ÜRETİYOR — yani "N tane RASTGELE tohum YARAT" demenin KISA yolu.
- `sin(Double(windDeg) * .pi / 180)`: RÜZGAR yönünü (DERECE) RADYANA çevirip `sin` (sinüs)
  FONKSİYONUNDAN geçiriyor — sonuç -1 İLE 1 arası bir "EĞİM" katsayısı, yağmurun DÜŞÜŞ açısını
  RÜZGARA göre HAFİFÇE eğmek İÇİN kullanılıyor.

```swift
private static func particleCount(for style: WeatherParticleStyle) -> Int {
    switch style { case .rain, .storm: return 70; case .snow: return 55; case .stars: return 50; case .clouds: return 4; case .fog: return 3; case .none: return 0 }
}
var body: some View {
    if style == .none {
        Color.clear
    } else {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                draw(in: &context, size: size, elapsed: elapsed)
            }
        }
        .allowsHitTesting(false)
    }
}
```
- `TimelineView(.animation(minimumInterval:paused:))`: SwiftUI'ın "her N SANİYEDE bir YENİDEN ÇİZ"
  mekanizması — İÇERİĞİNİ (Canvas) SÜREKLİ, DÜZENLİ ARALIKLARLA (saniyede en FAZLA 30 kere) yeniden
  DEĞERLENDİRİYOR. `paused: reduceMotion` — hareketi AZALT açıksa BU YENİDEN ÇİZİMİ TAMAMEN DURDURUYOR.
- `Canvas { context, size in ... }`: DÜŞÜK SEVİYELİ, DOĞRUDAN ÇİZİM API'si — HER bir parçacık İÇİN AYRI
  bir SwiftUI View (Circle/Path GİBİ) YARATMAK yerine, TEK bir çizim ÇAĞRISIYLA ONLARCA parçacığı
  ÇİZİYORUZ; bu YÜZDEN parçacık SAYISI ARTSA bile MALİYET NEREDEYSE SABİT kalıyor.
- `timeline.date.timeIntervalSinceReferenceDate`: "referans TARİHİNDEN (2001-01-01) bu YANA GEÇEN
  saniye" — SÜREKLİ ARTAN, TEK bir SAYI; TÜM animasyonlar bu SAYIYA göre HESAPLANIYOR (bir "ZAMAN
  SAATİ" gibi DÜŞÜNÜLEBİLİR).
- `&context`: `&` İŞARETİ, bu PARAMETRENİN "inout" (İÇERİDE DEĞİŞTİRİLEBİLİR VE değişiklik DIŞARIYA
  YANSIR) OLDUĞUNU gösteriyor — `draw(in:...)` FONKSİYONU `context` ÜZERİNE GERÇEKTEN ÇİZİM YAPIYOR.
- `.allowsHitTesting(false)`: bu KATMAN hiçbir DOKUNMA olayını YAKALAMASIN — arkasındaki GERÇEK
  butonlar/kartlar NORMAL şekilde TIKLANABİLSİN diye (parçacıklar SADECE görsel bir KATMAN).

```swift
private func drawRain(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
    for seed in seeds {
        let depthSpeed = 0.7 + seed.depth * 0.9
        let fallDuration = 0.9 / (seed.speed * depthSpeed)
        let progress = ((elapsed / fallDuration) + seed.phase).truncatingRemainder(dividingBy: 1)
        let startY = progress * (size.height + 60) - 40
        let x = seed.x * size.width
        let dropLength = 14 + seed.depth * 10
        let dx = windTilt * (12 + seed.depth * 10)
        var path = Path()
        path.move(to: CGPoint(x: x, y: startY))
        path.addLine(to: CGPoint(x: x + dx, y: startY + dropLength))
        let opacity = (0.18 + seed.depth * 0.3) * seed.scale
        let lineWidth = 1.0 + seed.depth * 0.9
        context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: lineWidth)
    }
}
```
- KRİTİK KURAL: bir DAMLANIN konumu HER karede SIFIRDAN ÜRETİLMİYOR, `seed` (SABİT, BİR KERE üretilmiş
  rastgele özellikler) + `elapsed` (GEÇEN süre) İKİSİNDEN SAF bir MATEMATİK fonksiyonuyla HESAPLANIYOR —
  hiçbir DİZİ elle GÜNCELLENMİYOR, bu yüzden BELLEK/CPU tüketimi ZAMANLA ARTMIYOR.
- `.truncatingRemainder(dividingBy: 1)`: BÖLME işleminin KALANINI ALIYOR — bir sayıyı SÜREKLİ 0 İLE 1
  ARASINDA "SARMALIYOR" (0.3, 1.3, 2.3... hep 0.3'e DÖNER) — bu, bir DAMLANIN ekranın ÜSTÜNDEN
  ALTINA düşüp SONRA TEKRAR ÜSTTEN başlamasını (SONSUZ DÖNGÜ) sağlıyor.
- `startY = progress * (size.height + 60) - 40`: damlayı EKRAN yüksekliğinin biraz ÜSTÜNDEN (-40)
  BAŞLATIP biraz ALTINA (+60) kadar İNDİRİYOR — kesilme ANI (damlanın aniden BELİRİP KAYBOLMASI) EKRAN
  SINIRLARININ DIŞINDA olsun diye.
- `seed.depth`: 0 (UZAK) İLE 1 (YAKIN) arası bir DEĞER — YAKIN damlalar DAHA BÜYÜK/HIZLI/BELİRGİN, UZAK
  olanlar DAHA küçük/YAVAŞ/soluk DÜŞÜYOR; bu BASİT "PARALAKS" hilesi GÖKYÜZÜNE bir DERİNLİK hissi
  katıyor.
- `context.stroke(path, with: .color(...), lineWidth:)`: `Canvas`'ın ÇİZİM komutu — bir `Path`'İ
  (BİRDEN FAZLA noktayı BİRLEŞTİREN geometrik ŞEKİL) BELİRTİLEN renk/kalınlıkla ÇİZİYOR.

(Kar/bulut/yıldız/sis ÇİZİMLERİ AYNI "seed + elapsed = saf FONKSİYON" DESENİNİ TEKRARLIYOR, sadece
FARKLI matematiksel EĞRİLER — `sin(elapsed * ...)` gibi İFADELER kar TANELERİNİN sağa SOLA SAVRULMASINI,
yıldızların GÖZ KIRPMASINI, sisin "NEFES ALMASINI" SAĞLIYOR. Detaylı KOD tekrar EDİLMEYECEK, mantık
AYNI.)

```swift
struct LightningFlashOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion { Color.clear } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let opacity = flashOpacity(at: elapsed)
                    guard opacity > 0 else { return }
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(opacity)))
                }
            }
            .allowsHitTesting(false)
        }
    }
    private func flashOpacity(at elapsed: Double) -> Double {
        let cycleLength = 7.0
        let flashDuration = 0.18
        let t = elapsed.truncatingRemainder(dividingBy: cycleLength)
        guard t < flashDuration else { return 0 }
        let progress = t / flashDuration
        return sin(progress * .pi) * 0.35
    }
}
```
- `flashOpacity(at:)`: 7 SANİYELİK bir DÖNGÜ İÇİNDE, İLK 0.18 saniyede bir "PARLAMA" EĞRİSİ (sinüs
  eğrisinin YARISI — 0'dan YÜKSELİP 0'a İNEN yumuşak bir TEPE) üretiyor, GERİ KALAN 6.82 saniyede
  OPAKLIK sıfır (HİÇBİR ŞEY GÖRÜNMÜYOR) — bu, ŞİMŞEK çakmasının GERÇEKÇİ, ANİ ama YUMUŞAK BAŞLAYIP BİTEN
  hissini VERİYOR.
- `context.fill(Path(CGRect(...)), with:)`: TÜM ekranı (size KADAR bir dikdörtgen) BEYAZA BOYUYOR,
  opaklık O ANKİ flaş DEĞERİNE göre — bu YÜZDEN "ekranı KISACIK aydınlatan bir flaş" hissi VERİYOR.

```swift
struct WeatherParticleField: View {
    let styles: [WeatherParticleStyle]
    let windDeg: Int?
    var body: some View {
        ZStack {
            ForEach(styles, id: \.self) { style in WeatherParticleLayer(style: style, windDeg: windDeg) }
            if styles.contains(.storm) { LightningFlashOverlay() }
        }
    }
}
```
- `ForEach(styles, id: \.self)`: `styles` bir `[WeatherParticleStyle]` DİZİSİ; `id: \.self` "HER
  elemanın KENDİSİNİ kimlik OLARAK kullan" demek (`WeatherParticleStyle` zaten `Hashable`, AYRI bir
  `id` alanına GEREK yok). BİRDEN FAZLA stil VARSA (nadir, kar+sis GİBİ) HEPSİ `ZStack` İÇİNDE ÜST
  ÜSTE ÇİZİLİYOR.

```swift
private struct ParticleSeed {
    let x: Double, y: Double, speed: Double, phase: Double, scale: Double, depth: Double
    static func random() -> ParticleSeed {
        ParticleSeed(x: .random(in: 0...1), y: .random(in: 0...1), speed: .random(in: 0.7...1.3), phase: .random(in: 0...1), scale: .random(in: 0.5...1.2), depth: .random(in: 0...1))
    }
}
```
- `.random(in: 0...1)`: `Double`'ın KENDİ, HAZIR `static` fonksiyonu — BELİRTİLEN ARALIKTA RASTGELE bir
  sayı ÜRETİYOR. Bu STRUCT `private` çünkü SADECE bu DOSYANIN İÇİNDE anlamlı, dışarıya HİÇ SIZMIYOR.

```swift
struct AmbientBackgroundView: View {
    var colors: [Color]
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle().fill(colors.last ?? .blue).frame(width: geo.size.width * 1.5)
                    .offset(x: animate ? -geo.size.width * 0.2 : geo.size.width * 0.2, y: animate ? -geo.size.height * 0.1 : geo.size.height * 0.2)
                    .blur(radius: 60).opacity(0.6)
                Circle().fill(colors.first ?? .white).frame(width: geo.size.width * 1.2)
                    .offset(x: animate ? geo.size.width * 0.5 : -geo.size.width * 0.1, y: animate ? geo.size.height * 0.6 : geo.size.height * 0.2)
                    .blur(radius: 70).opacity(0.5)
            }
            RadialGradient(colors: [.clear, .black.opacity(0.22)], center: .center, startRadius: 160, endRadius: 480)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) { animate.toggle() }
        }
    }
}
```
- `GeometryReader { geo in ... }`: İÇERİĞİNE, ÇEVRELEYEN ALANIN GERÇEK boyutunu (`geo.size`) VEREN bir
  SARMALAYICI — bulutların/dairelerin BOYUTUNU ekranın BOYUTUNA GÖRE ORANTILI (SABİT piksel DEĞİL)
  ayarlamak İÇİN kullanılıyor.
- `.offset(x: animate ? A : B, ...)`: `animate` bayrağına göre İKİ FARKLI konum ARASINDA GEÇİŞ yapıyor
  — asıl ANİMASYON, aşağıdaki `withAnimation` BLOĞUNUN `animate.toggle()` (true↔false) YAPMASIYLA
  TETİKLENİYOR; SwiftUI, bir DEĞER `withAnimation` İÇİNDE DEĞİŞTİĞİNDE ARADAKİ TÜM konumları KENDİSİ
  YUMUŞAKÇA ARA DEĞERLERLE (interpolate) ÇİZİYOR.
- `.repeatForever(autoreverses: true)`: animasyon BİTİNCE TERSİNE (B'den A'ya) tekrar OYNAYIP bunu
  SONSUZA kadar TEKRARLIYOR — dairelerin YAVAŞÇA İLERİ GERİ SÜZÜLDÜĞÜ hissi.
- `guard !reduceMotion else { return }`: "Hareketi Azalt" AÇIKSA animasyonu HİÇ BAŞLATMA — daireler
  SABİT kalıyor.

```swift
struct WeatherBackground: View {
    let conditionCodes: [Int]
    let isNight: Bool
    let windDeg: Int?
    private var primaryConditionCode: Int { conditionCodes.first ?? 800 }
    private var particleStyles: [WeatherParticleStyle] { WeatherParticleStyle.styles(forConditionCodes: conditionCodes, isNight: isNight) }
    var body: some View {
        ZStack {
            AmbientBackgroundView(colors: WeatherPalette.colors(conditionCode: primaryConditionCode, isNight: isNight))
            WeatherParticleField(styles: particleStyles, windDeg: windDeg)
        }
    }
}
```
- Şehir DETAY ekranının (ve karusel SAYFALARININ) TAM arka planı — RENK paletini (`AmbientBackgroundView`)
  VE parçacık KATMANINI (`WeatherParticleField`) BİRLEŞTİRİYOR. `conditionCodes.first ?? 800`: dizi
  BOŞSA (olmaması GEREKEN bir durum) "açık HAVA" (800) VARSAYIYOR — asla ÇÖKMÜYOR.

---

## Views/

### `Views/HomeView.swift`
```swift
import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) var scenePhase
    @State private var searchedLocation: WeatherLocation?
    @State private var currentLocationWeather: CityWeather?
    @State private var showSettings = false
    @State private var showFilter = false
    @State private var filter = WeatherFilter()
    @StateObject private var searchService = LocationSearchService()
    @Namespace private var heroNamespace
    ...
}
```
- `@StateObject private var locationManager = LocationManager()`: `HomeView` KURULDUĞUNDA BİR KERE
  yaratılıyor, View YENİDEN çizildikçe (SwiftUI bunu SIK yapar) SIFIRLANMIYOR — konum İZNİ/GPS durumu
  KAYBOLMASIN diye.
- `@Environment(\.scenePhase)`: uygulamanın ÖN PLANDA mı, ARKA PLANDA mı, tamamen KAPALI mı OLDUĞUNU
  SİSTEMDEN okuyan bir DEĞER — aşağıda `.onChange(of: scenePhase)` İLE kullanılıyor.
- `@State private var searchedLocation: WeatherLocation?`: arama SONUCU seçildiğinde/Enter'a BASILDIĞINDA
  buraya bir DEĞER yazılıyor; `nil` OLMAYAN bir değer, aşağıdaki `.navigationDestination(item:)`'I
  TETİKLEYİP detay ekranına GEÇİŞ yaptırıyor.
- `@Namespace private var heroNamespace`: bir satırdan detay EKRANINA "yakınlaşma" (zoom) animasyonu
  İÇİN PAYLAŞILAN kimlik alanı.

```swift
private var greeting: String {
    let hour = Calendar.current.component(.hour, from: .now)
    switch hour {
    case 5..<12: return String(localized: "greeting.morning", defaultValue: "Günaydın")
    case 12..<18: return String(localized: "greeting.afternoon", defaultValue: "İyi Günler")
    case 18..<22: return String(localized: "greeting.evening", defaultValue: "İyi Akşamlar")
    default: return String(localized: "greeting.night", defaultValue: "İyi Geceler")
    }
}
```
- `Calendar.current.component(.hour, from: .now)`: ŞU ANKİ zamanın SADECE "SAAT" bileşenini (0-23)
  ÇIKARIYOR — cihazın KENDİ saat dilimine göre (Home ekranı GENEL bir "günün NE ZAMANI" hissi verdiği
  için, BELİRLİ bir şehrin saat dilimine BAĞLI değil).
- Bu computed property, HER OKUNDUĞUNDA yeniden HESAPLANIYOR — View her YENİDEN çizildiğinde SAAT
  değişmiş OLABİLİR diye (örn. gece YARISINI geçince "İyi Geceler"DEN "Günaydın"A otomatik geçiş).
- **Temizlik**: burada eskiden AYRICA bir `isCurrentlyNight` computed property'si de VARDI (aynı
  `hour < 6 || hour >= 19` hesabıyla). Artık BURADA değil — `DesignSystem/WeatherBackground.swift`'teki
  `WeatherPalette.isCurrentlyNight`'A taşındı, çünkü ARTIK Ayarlar/Filtre ekranlarının arka planı da
  (bkz. o bölüm) AYNI hesaba İHTİYAÇ duyuyor; aynı SATIRI iki YERDE tutmak yerine TEK bir ORTAK yere
  taşıdık.

```swift
var body: some View {
    NavigationStack {
        ZStack {
            AmbientBackgroundView(colors: WeatherPalette.colors(conditionCode: 800, isNight: WeatherPalette.isCurrentlyNight))
                .ignoresSafeArea()
            List {
                if searchService.searchQuery.isEmpty {
                    // BÖLÜM 0, 1, 2: Selamlama / Konum Kartı / Favoriler
                } else if searchService.searchResults.isEmpty {
                    // Arama yapıldı ama sonuç yok
                } else {
                    // Arama sonuçları
                }
            }
            ...
        }
        ...
    }
}
```
- `NavigationStack`: iOS'un YENİ (eski `NavigationView`'ın yerini alan) gezinme KONTEYNER'i — İÇİNDEKİ
  `NavigationLink`/`.navigationDestination` ÇAĞRILARININ hepsini YÖNETİYOR, geri BUTONUNU/YIĞINI (stack)
  KENDİSİ TUTUYOR.
- `if searchService.searchQuery.isEmpty { ... } else if ... else { ... }`: TEK bir `List` İÇİNDE, arama
  KUTUSUNUN durumuna göre TAMAMEN FARKLI içerik GÖSTERİLİYOR — SwiftUI'da `if`/`else` bir View'IN
  GÖVDESİNDE DOĞRUDAN kullanılabiliyor, HANGİ dalın ÇALIŞACAĞI her YENİDEN çizimde YENİDEN
  değerlendiriliyor.

```swift
// BÖLÜM 0: Saate Göre Selamlama
Section {
    VStack(alignment: .leading, spacing: 2) {
        Text(greeting).font(.weatherCityName).foregroundColor(.white)
        Text(Date.now.formatted(date: .complete, time: .omitted)).font(.weatherCaption).foregroundColor(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .hiddenListRow(insets: EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
}
```
- `Section { ... }`: `List` İÇİNDE bir GRUP oluşturuyor — burada BAŞLIKSIZ (header YOK), sadece
  GRUPLAMA/ARALIK vermek İÇİN kullanılıyor.
- `Date.now.formatted(date: .complete, time: .omitted)`: bugünün TARİHİNİ TAM (gün adı + ay + yıl) ama
  SAAT OLMADAN yazıyor — Foundation'ın YENİ `FormatStyle` API'si.
- `.frame(maxWidth: .infinity, alignment: .leading)`: İÇERİĞİ MÜMKÜN OLAN en GENİŞ alana YAYIP SOLA
  YASLIYOR — `List` satırları VARSAYILAN olarak İÇERİĞE göre daralabildiği İÇİN bu SATIR olmadan metin
  ORTALANMIŞ/dar GÖRÜNEBİLİRDİ.
- `.hiddenListRow(insets:)`: (bkz. `DesignSystem/GlassCard.swift`) `List`'in HER satıra otomatik
  EKLEDİĞİ standart kenar boşluklarını KENDİ değerlerimizle DEĞİŞTİRİYOR, `List`'in KENDİ (varsayılan
  gri/beyaz) satır ARKA PLANINI ve AYIRICI çizgisini de KALDIRIYOR — kendi ÖZEL arka planımız
  (`AmbientBackgroundView`) ALTTAN görünsün diye. Bu SATIR, uygulamadaki BENZER 10'dan fazla yerde
  tekrar EDİYORDU, paylaşılan modifier'A böyle taşındı.

```swift
if locationManager.authorizationStatus != .denied {
    Section { locationWeatherCard... }
} else {
    Section { GlassWarningView(...) }
}
```
- Konum İZNİ REDDEDİLMEDİYSE (henüz SORULMADI, BEKLENİYOR ya da ZATEN verildi) KONUM kartını GÖSTER;
  REDDEDİLDİYSE bunun YERİNE bir UYARI kartı (Ayarlar'a YÖNLENDİREN bir mesaj) GÖSTER.

```swift
// BÖLÜM 2: Favoriler
Section {
    if viewModel.savedCities.isEmpty {
        GlassWarningView(...)
    } else {
        ForEach(viewModel.savedCities) { favorite in
            NavigationLink(destination: WeatherView(location: favorite.location, zoomNamespace: heroNamespace, zoomSourceID: favorite.name, favorites: viewModel.savedCities)) {
                FavoriteCityRow(city: favorite.name, snapshot: viewModel.favoriteSnapshots[favorite.name.lowercased()], unit: viewModel.preferredUnit)
            }
            .buttonStyle(PlainButtonStyle())
            .matchedTransitionSource(id: favorite.name, in: heroNamespace)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { withAnimation { viewModel.toggleFavorite(name: favorite.name, weather: nil) } } label: { Label("Sil", systemImage: "trash") }
            }
            .hiddenListRow(insets: ...)
        }
        .onDelete(perform: deleteCity)
    }
} header: { Text("FAVORİ ŞEHİRLER")... }
```
- `ForEach(viewModel.savedCities) { favorite in ... }`: `FavoriteCity` zaten `Identifiable` (bkz.
  `Models/FavoriteCity.swift` — `var id: String { name.lowercased() }`), bu yüzden `ForEach` HİÇBİR
  EK parametreye (`id:`) İHTİYAÇ DUYMADAN diziyi DOĞRUDAN alabiliyor. Eskiden bir de `index` (satırın
  sırası) GEREKİYORDU — çünkü favoriler arası KARUSEL (`FavoritesCarouselView`, artık SİLİNDİ) hangi
  sayfadan BAŞLAYACAĞINI (`startIndex`) bilmek İSTİYORDU. Karusel kaldırılıp `WeatherView` DOĞRUDAN
  `favorite.location`'I aldığı için `index`'e ARTIK gerek YOK — `Array(...enumerated())` gibi bir
  DOLAMBACA da gerek KALMADI, mimari BU SAYEDE de SADELEŞTİ.
- `NavigationLink(destination: WeatherView(location:, zoomNamespace:, zoomSourceID:, favorites:))`:
  arama sonucu/mevcut konumda kullanılan AYNI `WeatherView` — `favorites:` parametresi SADECE
  `WeatherView`'IN kendi İÇİNDEKİ dokunmatik favori-değiştirme şeridine (bkz. `Views/WeatherView.swift`
  bölümü) TÜM listeyi vermek İÇİN.
- `.matchedTransitionSource(id: favorite.name, in: heroNamespace)`: bu SATIRIN kaynağı, DETAY ekranındaki
  `.navigationTransition(.zoom(sourceID: ..., in: heroNamespace))` İLE EŞLEŞTİĞİNDE, SwiftUI o SATIRDAN
  detay EKRANINA "YAKINLAŞARAK" büyüyen bir GEÇİŞ animasyonu OYNATIYOR.
- `.swipeActions(edge: .trailing, allowsFullSwipe: true)`: satırı SOLA doğru KAYDIRINCA (trailing =
  SAĞ kenardan) bir SİLME butonu ORTAYA çıkarıyor; `allowsFullSwipe: true` TAM kaydırınca (buton
  bekleMEDEN) DOĞRUDAN silinmesine İZİN VERİYOR.
- `.onDelete(perform: deleteCity)`: `List`'in KENDİ, YERLEŞİK "sola kaydır → SİL" jestinden BAĞIMSIZ,
  DÜZENLEME modunda (edit mode, bu projede pek KULLANILMIYOR ama `ForEach` STANDART OLARAK destekliyor)
  silme İÇİN gerekli.

```swift
} else if searchService.searchResults.isEmpty {
    Section { GlassWarningView(iconName: "magnifyingglass", message: String(format: String(localized: "search.no_results_format", defaultValue: "\"%@\" için sonuç bulunamadı."), searchService.searchQuery)) ... }
} else {
    Section {
        ForEach(searchService.searchResults, id: \.self) { result in
            Button { Task { await selectSearchResult(result) } } label: { SearchResultRow(title: result.title) }
                .buttonStyle(PlainButtonStyle())
                .matchedTransitionSource(id: result.title, in: heroNamespace)
                ...
        }
    } header: { Text("ÖNERİLEN ŞEHİRLER")... }
}
```
- `ForEach(searchService.searchResults, id: \.self)`: `MKLocalSearchCompletion` KENDİSİ `Hashable`
  OLDUĞU için `\.self`'İ kimlik OLARAK kullanabiliyoruz (AYRI bir `id` alanına GEREK yok).
- `Button { Task { await selectSearchResult(result) } } label: { ... }`: butona BASILINCA `async` bir
  fonksiyon ÇAĞRILMASI GEREKTİĞİ İÇİN (`selectSearchResult` bir `await` İÇERİYOR), bunu bir `Task {}`
  İÇİNE SARMAMIZ gerekiyor — bir Button action'ı DOĞRUDAN `async` OLAMAZ.

```swift
.scrollContentBackground(.hidden)
.listStyle(.insetGrouped)
.refreshable {
    viewModel.refreshFavoriteSnapshots()
    if let coordinate = locationManager.location {
        currentLocationWeather = await viewModel.snapshotWeather(for: .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: locationManager.displayLocationName ?? ""))
    }
}
.sensoryFeedback(.selection, trigger: viewModel.savedCities.count)
```
- `.scrollContentBackground(.hidden)`: `List`'in KENDİ (varsayılan) arka plan RENGİNİ TAMAMEN GİZLİYOR —
  ALTTAKİ `AmbientBackgroundView` GÖRÜNSÜN diye.
- `.refreshable { ... }`: kullanıcı LİSTEYİ aşağı ÇEKİNCE (pull-to-refresh) sistemin KENDİ dönen
  GÖSTERGESİYLE ÇALIŞAN bir kapanış — HEM favorileri TAZELİYOR HEM mevcut konumu YENİDEN ÇEKİYOR.
- `.sensoryFeedback(.selection, trigger: viewModel.savedCities.count)`: favori SAYISI DEĞİŞTİĞİNDE (bir
  favori EKLENDİĞİNDE/ÇIKARILDIĞINDA) hafif bir DOKUNSAL (haptic) TİTREŞİM VERİYOR.

```swift
.navigationTitle("Nuve")
.navigationBarTitleDisplayMode(.inline)
.toolbarColorScheme(.dark, for: .navigationBar)
.toolbar {
    ToolbarItem(placement: .principal) { BrandHeader() }
    ToolbarItem(placement: .navigationBarLeading) { Button { showFilter = true } label: { Image(systemName: filter.isActive ? "..." : "...") } }
    ToolbarItem(placement: .navigationBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape.fill") } }
}
```
- `.navigationTitle("Nuve")` GÖRSEL olarak ARTIK kullanılmıyor (`.principal` YERİNDEKİ `BrandHeader()`
  onun YERİNİ ALIYOR) — ama VoiceOver'ın ekranı DUYURMASI ve bu ekrandan BAŞKA bir sayfaya GEÇİLDİĞİNDE
  "geri" butonunun ETİKETİ için HÂLÂ gerekli.
- `ToolbarItem(placement: .principal)`: gezinme çubuğunun TAM ORTASINA (normalde başlığın olduğu YERE)
  KENDİ View'IMIZI (`BrandHeader`) yerleştiriyoruz.
- `filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"`:
  filtre AKTİFSE DOLU (fill) ikon, DEĞİLSE BOŞ ikon — kullanıcı bir BAKIŞTA "filtre AÇIK mı" ANLIYOR.

```swift
.searchable(text: $searchService.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Şehir ara (Örn: İstanbul)")
.onSubmit(of: .search) {
    let query = searchService.searchQuery
    Task { searchedLocation = await searchService.resolve(freeText: query) }
}
.navigationDestination(item: $searchedLocation) { location in
    WeatherView(location: location, zoomNamespace: heroNamespace)
}
.sheet(isPresented: $showSettings) { SettingsView() }
.sheet(isPresented: $showFilter) { WeatherFilterView(filter: $filter, unit: viewModel.preferredUnit) }
```
- `.searchable(text: $searchService.searchQuery, ...)`: sistemin KENDİ arama çubuğunu EKLİYOR;
  `$searchService.searchQuery` bir `@Binding` — kullanıcı YAZDIKÇA bu METİN `LocationSearchService`'İN
  `@Published searchQuery`'sine DOĞRUDAN YAZILIYOR (İKİ YÖNLÜ BAĞLANTI).
- `.onSubmit(of: .search)`: kullanıcı KLAVYEDE Enter'a BASINCA çalışıyor.
- `.navigationDestination(item: $searchedLocation) { location in ... }`: `$searchedLocation` NİL
  OLMAYAN bir DEĞER ALDIĞINDA (yani BİR YER seçildiğinde/çözüldüğünde) OTOMATİK olarak
  `WeatherView(location:)`'A GEÇİYOR; `item:` PARAMETRESİ, `isPresented: Bool` YERİNE OPSİYONEL bir
  DEĞERİN KENDİSİNİ kullanan bir DESEN — `location` closure İÇİNDE artık NİL OLMAYAN, GERÇEK bir
  `WeatherLocation`.
- `.sheet(isPresented:) { ... }`: bir MODAL (alttan YUKARI kayan) PENCERE AÇIYOR — Ayarlar/Filtre EKRANLARI
  İÇİN.

```swift
.onAppear {
    locationManager.requestLocation()
    viewModel.refreshFavoriteSnapshots()
}
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        locationManager.refreshAuthorizationStatusIfNeeded()
        viewModel.refreshFavoriteSnapshots()
    }
}
.task(id: locationManager.apiSearchCityName) {
    guard let coordinate = locationManager.location else { return }
    currentLocationWeather = await viewModel.snapshotWeather(for: .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: locationManager.displayLocationName ?? ""))
}
```
- `.onAppear { ... }`: View İLK göründüğünde (uygulama İLK açıldığında) BİR KERE çalışıyor.
- `.onChange(of: scenePhase) { oldPhase, newPhase in ... }`: `scenePhase` DEĞİŞTİĞİNDE ÇALIŞIYOR;
  parametreler ESKİ ve YENİ değeri VERİYOR (burada `oldPhase` KULLANILMIYOR ama Swift'İN yeni
  `onChange` İMZASI İKİSİNİ de İSTİYOR). `newPhase == .active`: uygulama ÖN plana her DÖNDÜĞÜNDE
  (arka plandan/kilit EKRANINDAN) — konum İZNİNİ ve FAVORİLERİ tazeliyoruz.
- `.task(id: locationManager.apiSearchCityName) { ... }`: `.task`, `.onAppear`'A benzer ama İÇİNDE
  DOĞRUDAN `await` KULLANILABİLİYOR VE `id:` parametresi SAYESİNDE, bu ID DEĞİŞTİĞİNDE (konum İLK
  çözüldüğünde/DEĞİŞTİĞİNDE) blok OTOMATİK olarak YENİDEN ÇALIŞIYOR (View YENİDEN görünmese BİLE).

```swift
private func selectSearchResult(_ result: MKLocalSearchCompletion) async {
    searchedLocation = await searchService.resolve(result)
}
private var locationWeatherCard: some View {
    NavigationLink(destination: Group {
        if let coordinate = locationManager.location {
            WeatherView(location: .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: locationManager.displayLocationName ?? locationManager.apiSearchCityName ?? "Konum"), zoomNamespace: heroNamespace, zoomSourceID: "current-location")
        } else {
            Text("Konum aranıyor...")
        }
    }) {
        HStack { ... }
        .padding(20)
        .weatherGlassCard()
    }
    .matchedTransitionSource(id: "current-location", in: heroNamespace)
    .buttonStyle(PlainButtonStyle())
}
```
- `private var locationWeatherCard: some View`: bir COMPUTED PROPERTY olarak TANIMLANMIŞ bir View PARÇASI
  — `body` içindeki büyük ifadeyi KISALTMAK/OKUNURLUĞU artırmak İÇİN AYRI bir İSME çıkarılmış.
- `Group { if let coordinate = ... { ... } else { ... } }`: `NavigationLink`'in `destination`'I TEK bir
  View OLMAK zorunda; `Group`, İKİ FARKLI (koordinat VARSA `WeatherView`, YOKSA sadece bir metin) dalı
  TEK bir View gibi SARMALAYIP bu KURALI sağlıyor.
- `displayName: locationManager.displayLocationName ?? locationManager.apiSearchCityName ?? "Konum"`:
  ÜÇ SEVİYELİ bir YEDEK ZİNCİRİ — ÖNCE tam adres, O da YOKSA sadece şehir İSMİ, O da YOKSA düz "Konum"
  METNİ.
- `zoomSourceID: "current-location"`: SABİT bir METİN — mevcut konum KARTI TEK bir tane OLDUĞU için
  (favoriler gibi ÇOKLU değil), sabit bir KİMLİK yeterli.

```swift
func deleteCity(at offsets: IndexSet) {
    let citiesToRemove = offsets.map { viewModel.savedCities[$0] }
    for favorite in citiesToRemove {
        withAnimation { viewModel.toggleFavorite(name: favorite.name, weather: nil) }
    }
}
```
- `IndexSet`: `List`'in "DÜZENLEME modunda SİLİNMEK istenen SATIRLARIN index'LERİ" olarak VERDİĞİ özel
  bir KÜME tipi.
- `offsets.map { viewModel.savedCities[$0] }`: HER index'İ (`$0`), o index'TEKİ GERÇEK `FavoriteCity`'e
  ÇEVİRİYOR — SİLME işlemi index'E göre DEĞİL, İSME göre YAPILDIĞI (`toggleFavorite(name:)`) İÇİN önce
  GERÇEK nesneyi BULMAMIZ gerekiyor.
- `withAnimation { ... }`: İÇİNDEKİ DEĞİŞİKLİK (favori LİSTESİNDEN çıkarma) YUMUŞAK bir ANİMASYONLA
  (satırın kayarak KAYBOLMASI gibi) GERÇEKLEŞSİN diye.

### `Views/WeatherView.swift`
**Mimari geçmiş (favoriler arası gezinme)**: Bir favoriden diğerine "kaydırarak" (swipe) geçebilmek
için `FavoritesCarouselView` adında AYRI bir ekran vardı. ON BİR farklı teknik yaklaşım (TabView,
ScrollView, overlay, safeAreaInset, VStack, ZStack, GeometryReader, toolbar'ın `.principal` konumu ve
bunların çeşitli kombinasyonları) denendi — HİÇBİRİ canlı cihazda güvenilir/öngörülebilir çalışmadı;
kendi göstergemiz (isim şeridi) ya içerikle ÇAKIŞTI ya ekranın ORTASINA düştü ya da aralarında koca bir
BOŞLUK oluştu. Kök sebep: bir YATAY kaydırma/sayfalama katmanının (favoriler arası geçiş) İÇİNE, HER
SAYFANIN kendi DİKEY kaydırma katmanını (o sayfanın içerik listesi) koymak, ve bunların ÜSTÜNE bir de
SABİT bir üçüncü katman (isim şeridi) eklemek — üç kaydırma/konumlandırma katmanının etkileşimi
SwiftUI'da TUTARLI sonuç vermedi. KARAR: kaydırma/karusel jestini TAMAMEN kaldırdık —
`FavoritesCarouselView.swift` ve `ViewModels/CarouselPageModel.swift` SİLİNDİ. Favoriler artık BU
ekranı (`WeatherView`), TIPKI arama sonucu gibi, TEKİL ve SABİT açıyor; favoriler arası geçiş isteyen
kullanıcı için bunun yerine ekranın ALTINDA `FavoriteSwitcherStrip` var (bkz. aşağısı) — kaydırma
DEĞİL, DOKUNMA ile geçiş.

```swift
struct WeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    let zoomNamespace: Namespace.ID
    let zoomSourceID: String
    private let favorites: [FavoriteCity]
    @State private var activeLocation: WeatherLocation
    @State private var activeName: String

    init(location: WeatherLocation, zoomNamespace: Namespace.ID, zoomSourceID: String? = nil, favorites: [FavoriteCity] = []) {
        self.zoomNamespace = zoomNamespace
        self.zoomSourceID = zoomSourceID ?? location.displayName
        self.favorites = favorites
        _activeLocation = State(initialValue: location)
        _activeName = State(initialValue: location.displayName)
    }
    ...
}
```
- `favorites: [FavoriteCity] = []`: VARSAYILAN boş dizi — arama sonucu/mevcut konum GİBİ tekil
  girişler bu parametreyi HİÇ vermiyor (bkz. `Views/HomeView.swift`'teki `locationWeatherCard` VE
  `.navigationDestination(item:)` çağrıları), sadece FAVORİLER listesinden açılırken TÜM liste
  geçiliyor (bkz. `Views/HomeView.swift`'teki favori satırı notu).
- `@State private var activeLocation`/`activeName`: ekranda O AN gösterilen konum — `init`'TEKİ
  `location` parametresiyle KURULUYOR, kullanıcı alt şeritten BAŞKA bir favoriye dokununca DEĞİŞİYOR
  (bkz. altta `.onChange(of: activeName)`). ESKİDEN bu ekranın TEK, SABİT bir `let location` VARDI —
  artık favoriler arası GEÇİŞ için bunun DEĞİŞEBİLİR (`@State`) olması GEREKİYOR.
- ÖZEL bir `init` TANIMLANMIŞ (Swift'in OTOMATİK ürettiği memberwise BAŞLATICI yerine) — çünkü
  `zoomSourceID` OPSİYONEL bir PARAMETRE (`String? = nil`) VE verilmezse `location.displayName`'E
  DÜŞMESİ GEREKİYOR, AYRICA `activeLocation`/`activeName` gibi `@State` alanlarının BAŞLANGIÇ
  değerlerini `location` parametresinden ELLE kurmak (`_activeLocation = State(initialValue:)`)
  gerekiyor; bu MANTIK sadece BİR init İÇİNDE, elle YAZILARAK ifade EDİLEBİLİYOR.

```swift
private var currentWeather: CityWeather? {
    if case .success(let weather) = viewModel.state { return weather }
    return nil
}
private var favoriteKey: String {
    currentWeather?.name ?? activeLocation.displayName
}
```
- `if case .success(let weather) = viewModel.state`: bir `enum`'IN BELİRLİ bir CASE'DE olup OLMADIĞINI
  kontrol eden ALTERNATİF bir yazım (TAM bir `switch` yerine) — sadece TEK bir case İLE İLGİLENİYORSAK
  bu DAHA KISA.
- `favoriteKey`: veri GELDİYSE (`currentWeather` dolu) API'nin KANONİK ismini (`weather.name`)
  KULLANIYOR, henüz GELMEDİYSE ekrana GELİRKEN kullandığımız İSME (`activeLocation.displayName`)
  DÜŞÜYOR — yıldız BUTONUNUN veri YÜKLENMEDEN ÖNCE bile TUTARLI çalışması İÇİN.

```swift
var body: some View {
    ZStack {
        WeatherBackground(conditionCodes: currentWeather?.conditionCodes ?? [800], isNight: currentWeather?.isNight ?? false, windDeg: currentWeather?.windDeg)
            .ignoresSafeArea()
        VStack {
            WeatherStateScaffold(state: viewModel.state, onRetry: { viewModel.fetchWeather(for: activeLocation) }) { weather in
                WeatherContentView(weather: weather, hourly: viewModel.hourlyForecast, daily: viewModel.dailyForecast, airQuality: viewModel.airQuality, unit: viewModel.preferredUnit, windUnit: viewModel.preferredWindUnit, lastUpdated: viewModel.lastUpdated, onRefresh: { viewModel.fetchWeather(for: activeLocation) })
            }
        }
    }
    .safeAreaInset(edge: .bottom) {
        if favorites.count > 1 {
            FavoriteSwitcherStrip(favorites: favorites, activeName: $activeName, snapshots: viewModel.favoriteSnapshots, unit: viewModel.preferredUnit)
        }
    }
    .navigationTransition(.zoom(sourceID: zoomSourceID, in: zoomNamespace))
    .onAppear { viewModel.fetchWeather(for: activeLocation) }
    .onChange(of: activeName) { _, newName in
        guard let favorite = favorites.first(where: { $0.name == newName }) else { return }
        activeLocation = favorite.location
        viewModel.fetchWeather(for: favorite.location)
    }
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar { ... yıldız + paylaş butonları ... }
}
```
- Bu `WeatherView` SADECE "ÇERÇEVE" — arka plan + navigasyon ÇUBUĞU + yakınlaşma GEÇİŞİ + (favoriler
  listesinden açıldıysa) alt favori-değiştirme şeridi. Asıl İÇERİK (`WeatherStateScaffold`/
  `WeatherContentView`) TAMAMEN AYRI dosyalarda (bkz. `Views/Components/`) — bu SADECE dosyayı
  kısa/okunur TUTMAK için, artık BAŞKA bir tüketicisi (eski karusel) YOK.
- `.safeAreaInset(edge: .bottom) { if favorites.count > 1 { FavoriteSwitcherStrip(...) } }`: şerit
  SADECE gerçekten birden fazla favori VARSA gösteriliyor (tek favoride "geçiş" ANLAMSIZ). Bu ekranda
  ARTIK sadece TEK bir kaydırma katmanı VAR (içeriğin kendi dikey `ScrollView`'ı) — bu YÜZDEN
  `.safeAreaInset(edge: .bottom)` burada YUKARIDA anlatılan ON BİR denemedeki HİÇBİR soruna YOL
  AÇMIYOR; bu, o API'nin STANDART/kanıtlanmış kullanım şekli (tek bir scroll view'ın ALTINA sabit bir
  çubuk eklemek — favori-değiştirme şeridi kendi İÇERİĞİN parçası DEĞİL, `WeatherContentView`'ın kendi
  ScrollView'ının ALTINDAN AYRI, kardeş bir katman).
- `.onChange(of: activeName) { _, newName in ... }`: kullanıcı alt şeritte BAŞKA bir favoriye
  dokunduğunda ÇALIŞIYOR — `favorites` içinde o İSME sahip `FavoriteCity`'İ bulup `activeLocation`'I
  GÜNCELLİYOR ve `viewModel.fetchWeather(for:)`'I YENİDEN çağırıyor. Bu, PAYLAŞILAN `viewModel.state`'İ
  yeniden dolduruyor — eskiden KARUSELDE bu iş İÇİN her sayfanın KENDİ, bağımsız `CarouselPageModel`'i
  vardı; artık TEK bir ekran, TEK bir paylaşılan durum yeterli olduğu için o karmaşıklığa hiç gerek yok.
- `WeatherStateScaffold(state:onRetry:) { weather in WeatherContentView(...) }`: GENERIC bir View'A
  (bkz. Bölüm 1) `@ViewBuilder` bir CLOSURE geçiyoruz — bu CLOSURE'IN parametresi (`weather`), scaffold
  `.success` DURUMUNA geçtiğinde İÇİNDEKİ `CityWeather`'I VERİYOR.
- `.onAppear { viewModel.fetchWeather(for: activeLocation) }`: EKRAN İLK göründüğünde HAVA durumu
  VERİSİNİ ÇEKMEYE BAŞLIYOR.

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleFavorite(name: favoriteKey, weather: currentWeather) }
        } label: {
            Image(systemName: viewModel.isFavorite(favoriteKey) ? "star.fill" : "star")
                .foregroundColor(.yellow).font(.title2)
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(.selection, trigger: viewModel.isFavorite(favoriteKey))
    }
    if let weather = currentWeather {
        ToolbarItem(placement: .navigationBarTrailing) { ShareLink(item: shareText(for: weather)) }
    }
}
```
- `.contentTransition(.symbolEffect(.replace))`: bir SF Symbol İKONU BAŞKA bir SF Symbol'e (`star` →
  `star.fill`) DEĞİŞTİĞİNDE, SwiftUI'IN kendi YERLEŞİK "değiştirme" (replace) ANİMASYONUYLA (yumuşak bir
  ÇAPRAZ GEÇİŞ) OYNAMASINI sağlıyor — elle bir `.scaleEffect` yazmaya GEREK KALMADAN.
- `if let weather = currentWeather { ToolbarItem { ShareLink(...) } }`: paylaş BUTONU sadece veri
  YÜKLENDİYSE görünüyor — paylaşılacak HİÇBİR şey YOKKEN buton GÖSTERİLMİYOR.
- `ShareLink(item: shareText(for: weather))`: iOS'un KENDİ paylaşım SAYFASINI (mesaj/mail/başka
  uygulamalar) AÇAN hazır bir View — `item:` PAYLAŞILACAK METNİ ALIYOR.

```swift
private func shareText(for weather: CityWeather) -> String {
    String(format: String(localized: "share.summary_format", defaultValue: "%@: %@, %@"), weather.name, viewModel.preferredUnit.format(weather.temperature), weather.conditionDescription.capitalized)
}
```
- `%@`: format DİZELERİNDE "buraya bir NESNE/METİN gelecek" YER TUTUCUSU (`%d` sayı İÇİN, `%@` GENEL
  NESNE/String İÇİN) — ÜÇ tane `%@` var, ÜÇ parametre (isim, sıcaklık, DURUM) SIRAYLA YERLERİNE
  KONUYOR.

### `Views/WeatherView.swift` — `FavoriteSwitcherStrip` (private)
Eski karuselin YERİNE geçen, kaydırma İÇERMEYEN gezinme yöntemi — favoriler arasında geçiş bir
"kaydırma/sayfalama JESTİ" ile DEĞİL, ekranın altındaki bir kapsüle DOKUNARAK oluyor.

```swift
private struct FavoriteSwitcherStrip: View {
    let favorites: [FavoriteCity]
    @Binding var activeName: String
    let snapshots: [String: CityWeather]
    let unit: TemperatureUnit

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favorites) { favorite in
                        chip(for: favorite).id(favorite.name)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .onAppear { proxy.scrollTo(activeName, anchor: .center) }
            .onChange(of: activeName) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        }
        .sensoryFeedback(.selection, trigger: activeName)
    }
    ...
}
```
- **Yaşanan bir hata (görsel ince ayar)**: `.background(.ultraThinMaterial)` düz bir MODIFIER olarak
  doğrudan tüm şeride uygulanınca, ekranın UCUNDAN UCUNA uzanan, köşeleri TAMAMEN keskin (hiç
  yuvarlatılmamış) bir çubuk ortaya çıkıyordu — kalın VE camdan çok "katı" bir levha gibi görünüyordu.
- **Çözüm — dört küçük ayar**: (1) malzemeyi artık `.background { RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial) }`
  İLE, yani bir ŞEKLE KIRPILMIŞ olarak veriyoruz — `RoundedRectangle` malzemenin (material) KENDİSİNİN
  hangi HATLARLA çizileceğini belirliyor; (2) dış `.padding(.horizontal, 16)` şeridi ekranın
  kenarlarından İÇERİ çekip YÜZEN bir hap görünümü kazandırıyor — artık `.background` bu paddingden
  SONRA uygulandığı için, malzeme büyümüş/PADDİNGLİ görünüme göre ÇİZİLİYOR (modifier sırası burada
  KRİTİK: önce padding, SONRA background); (3) iç dolgu `.padding(.vertical, 10)`'DAN `6`'ya
  düşürülerek şerit daha İNCE oldu; (4) arka plan `RoundedRectangle`'a `.opacity(0.8)` eklendi —
  bu opaklık SADECE o Shape'e (arka plan katmanına) uygulanıyor, `chip`'lerin KENDİ metni/rengi
  hiç ETKİLENMİYOR, çünkü `.opacity` burada background closure'ının İÇİNDE, dışarıdaki content'e
  DEĞİL.
- `ForEach(favorites) { favorite in ... }`: eski karuseldeki `CityChipStrip` `Array(favorites.enumerated())`
  + `id: \.offset` KULLANIYORDU (çünkü bir SAYFA İNDEKSİYLE — `Int` — konuşmak ZORUNDAYDI, karusel
  `scrolledIndex: Int?` ile SAYFALANIYORDU). Artık bir "SAYFA" YOK, doğrudan `FavoriteCity`'nin
  KENDİSİYLE (İSMİYLE, `@Binding var activeName: String` üzerinden) KONUŞUYORUZ — `FavoriteCity`
  zaten `Identifiable` OLDUĞU için `ForEach` hiç EK parametreye gerek DUYMUYOR, bu da eski koddan
  DAHA SADE.
- `@Binding var activeName: String`: bu View, `WeatherView`'IN `@State private var activeName`'İNE
  giden bir "KAPIYA" sahip (bkz. Bölüm 1 — `@Binding`) — bir kapsüle dokunulunca burada YAZILAN isim,
  DOĞRUDAN üst View'daki `activeName`'İ de DEĞİŞTİRİYOR, bu da `.onChange(of: activeName)` ÜZERİNDEN
  yeni şehri YÜKLETİYOR.
- `ScrollViewReader { proxy in ... }`: İÇİNDEKİ bir `ScrollView`'IN BELİRLİ bir ALT ÖĞESİNE (kimliğiyle,
  `.id(favorite.name)`) PROGRAMLI olarak KAYDIRABİLMEMİZİ sağlayan bir SARMALAYICI — `proxy.scrollTo(...)`
  bunu YAPIYOR. `.onAppear { proxy.scrollTo(activeName, anchor: .center) }`: ekran İLK açıldığında da
  (favoriler listesinden HANGİ şehre dokunulduysa) O kapsül BAŞTAN ortalanmış GÖRÜNSÜN diye.
- `.onChange(of: activeName) { _, newValue in ... }`: aktif İSİM DEĞİŞTİĞİNDE (bir kapsüle
  dokunulduğunda) çalışıyor; `proxy.scrollTo(newValue, anchor: .center)` YENİ aktif kapsülü YATAY
  olarak TAM ORTAYA KAYDIRIYOR.
- `.sensoryFeedback(.selection, trigger: activeName)`: favori DEĞİŞTİĞİNDE hafif bir DOKUNSAL geri
  BİLDİRİM.

```swift
private func chip(for favorite: FavoriteCity) -> some View {
    let isActive = favorite.name == activeName
    let snapshot = snapshots[favorite.name.lowercased()]
    return Button {
        activeName = favorite.name
    } label: {
        HStack(spacing: 6) {
            Text(favorite.name.capitalized).font(.weatherRowSubtitle).lineLimit(1)
            if let snapshot { Text(unit.format(snapshot.temperature)).font(.weatherRowSubtitle.bold()) }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.14)))
        .foregroundColor(isActive ? .black : .white.opacity(0.85))
    }
    .buttonStyle(.plain)
}
```
- `activeName = favorite.name`: dokunulunca `@Binding` ÜZERİNDEN üst View'daki `activeName`'İ
  DEĞİŞTİRİYOR — eski karuseldeki gibi burada AYRICA `withAnimation` sarmaya GEREK yok, görsel
  değişiklik ZATEN `WeatherStateScaffold`'IN `.loading`→`.success` GEÇİŞİYLE doğal olarak oluyor.
- `if let snapshot`: eski karuseldeki `if isActive, let snapshot` KOŞULUNDAN FARKLI olarak artık
  SADECE snapshot VARLIĞINA bakıyor (aktif OLSUN OLMASIN, bilinen HER şehrin sıcaklığı gösteriliyor)
  — bu, kullanıcının diğer favorilerin GÜNCEL sıcaklığını da (dokunmadan) GÖREBİLMESİNİ sağlıyor,
  favori LİSTESİNDEKİ satırlarla TUTARLI bir davranış.
- `.lineLimit(1)`: METİN uzun OLSA bile TEK satıra SIĞDIRIYOR (gerekirse "..." ile KIRPIYOR) — chip'in
  BOYUTU sabit KALSIN diye.

### `Views/WeatherFilterView.swift`
```swift
struct WeatherFilterView: View {
    @Binding var filter: WeatherFilter
    let unit: TemperatureUnit
    @Environment(\.dismiss) private var dismiss
    @State private var showResults = false

    private var bounds: ClosedRange<Double> { unit == .celsius ? -30...50 : -22...122 }
    private var minBinding: Binding<Double> {
        Binding(get: { displayValue(filter.minTemperatureCelsius) }, set: { filter.minTemperatureCelsius = min(celsiusValue($0), filter.maxTemperatureCelsius) })
    }
    private var maxBinding: Binding<Double> {
        Binding(get: { displayValue(filter.maxTemperatureCelsius) }, set: { filter.maxTemperatureCelsius = max(celsiusValue($0), filter.minTemperatureCelsius) })
    }
    private func displayValue(_ celsius: Double) -> Double { unit == .celsius ? celsius : celsius * 9 / 5 + 32 }
    private func celsiusValue(_ displayed: Double) -> Double { unit == .celsius ? displayed : (displayed - 32) * 5 / 9 }
    ...
}
```
- `@Binding var filter: WeatherFilter`: bu EKRAN, filtreyi KENDİSİ SAKLAMIYOR — `HomeView`'DAKİ
  `@State private var filter`'A giden bir KAPI TUTUYOR; burada YAPILAN her DEĞİŞİKLİK DOĞRUDAN
  `HomeView`'daki GERÇEK değeri GÜNCELLİYOR.
- `@Environment(\.dismiss)`: sistemin "bu MODAL/sheet'İ kapat" fonksiyonunu OKUYAN özel bir ORTAM
  değeri — `dismiss()` çağrıldığında EKRAN kapanıyor.
- `private var minBinding: Binding<Double>`: ELLE kurulmuş bir `Binding` — `Binding(get:set:)` İKİ
  CLOSURE alıyor: "OKUNURKEN ne DÖNDÜR" ve "YAZILIRKEN ne YAP". Burada AMAÇ: `filter` İÇİNDE HER ZAMAN
  Celsius SAKLANIYOR, ama KAYDIRICI (Slider) kullanıcının SEÇTİĞİ birimde (°C YA DA °F) göstermeli/okumalı
  — bu İKİ closure ARADAKİ dönüşümü ŞEFFAF şekilde YAPIYOR, `Slider` kendisi HİÇBİR birim FARKINDALIĞINA
  sahip DEĞİL.
- `set: { filter.minTemperatureCelsius = min(celsiusValue($0), filter.maxTemperatureCelsius) }`:
  kaydırıcı YENİ bir değer VERDİĞİNDE (`$0`), ÖNCE görüntü BİRİMİNDEN Celsius'a ÇEVİRİYOR, SONRA
  `min(...)` İLE bunun MAKSİMUM sınırı GEÇMEMESİNİ (en AZ, maksimumdan BÜYÜK olamaz) GARANTİ EDİYOR —
  kullanıcı "EN AZ" kaydırıcısını "EN ÇOK"UN ÜSTÜNE ÇEKEMİYOR.

```swift
var body: some View {
    NavigationStack {
        ZStack {
            AmbientBackgroundView(colors: WeatherPalette.chromeColors).ignoresSafeArea()
            List {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                        ForEach(WeatherConditionCategory.allCases) { category in
                            ConditionChip(category: category, isSelected: filter.categories.contains(category)) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if filter.categories.contains(category) { filter.categories.remove(category) }
                                    else { filter.categories.insert(category) }
                                }
                            }
                        }
                    }
                    ...
                } header: { Text("HAVA DURUMU")... }
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("En Az"); Spacer(); Text(unit.format(filter.minTemperatureCelsius)).font(.weatherTemperatureSmall) }
                            Slider(value: minBinding, in: bounds, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("En Çok"); Spacer(); Text(unit.format(filter.maxTemperatureCelsius)).font(.weatherTemperatureSmall) }
                            Slider(value: maxBinding, in: bounds, step: 1)
                        }
                    }
                    ...
                } header: { Text("SICAKLIK ARALIĞI")... }
                Section {
                    Button { showResults = true } label: { Text("Uygula").font(.weatherRowTitle).frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        ...
                }
            }
            ...
        }
        ...
        .navigationDestination(isPresented: $showResults) { FilterResultsView(filter: filter, unit: unit) }
    }
}
```
- `LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10)`: bir IZGARA
  (grid) düzeni — `.adaptive(minimum: 108)` demek "her SÜTUN EN AZ 108 PUAN genişliğinde OLSUN, EKRAN
  genişliğine SIĞDIĞI kadar SÜTUN yerleştir" — sabit bir "2 SÜTUN" ya da "3 sütun" YAZMAK yerine,
  farklı EKRAN boyutlarına (iPhone/iPad) OTOMATİK uyuyor.
- `ForEach(WeatherConditionCategory.allCases)`: `CaseIterable` SAYESİNDE (bkz. Bölüm 1) bu enum'un
  TÜM case'lerini (`clear`, `cloudy`, `rain`...) OTOMATİK olarak bir DİZİ gibi DOLAŞABİLİYORUZ.
- `ConditionChip(category:isSelected:) { ... }`: SON parametre bir TRAILING CLOSURE — "BU CHIP'E
  DOKUNULUNCA ne OLSUN" (bkz. `ConditionChip`'İN kendi TANIMI aşağıda).
- `if filter.categories.contains(category) { filter.categories.remove(category) } else { filter.categories.insert(category) }`:
  KATEGORİ zaten SEÇİLİYSE ÇIKAR, DEĞİLSE EKLE — bir `Set`'İ "AÇMA/KAPAMA" (toggle) desenidir.
- `Slider(value: minBinding, in: bounds, step: 1)`: sistemin KENDİ kaydırıcı KONTROLÜ — `value:` bir
  `Binding<Double>` İSTİYOR (BİZİM elle KURDUĞUMUZ `minBinding`), `in: bounds` İZİN VERİLEN ARALIK,
  `step: 1` her HAREKETTE 1 birimlik ADIMLARLA DEĞİŞMESİ.
- `.buttonStyle(.glassProminent)`: iOS 26'nın HAZIR, ÖNE ÇIKAN (prominent) CAM buton STİLİ — elle cam
  efekti KURMAK yerine, sistemin KENDİ hazır STİLİ.
- `.navigationDestination(isPresented: $showResults) { ... }`: `showResults` `true` OLDUĞUNDA,
  `FilterResultsView`'A GEÇİYOR — `HomeView`'daki `item:` versiyonundan FARKLI olarak burada BASİT bir
  `Bool` bayrağı KULLANILIYOR (aktarılacak EK bir VERİ olmadığı için YETERLİ).

```swift
private struct ConditionChip: View {
    let category: WeatherConditionCategory
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.label).font(.weatherRowSubtitle)
                if isSelected { Image(systemName: "checkmark").font(.caption.bold()) }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .black : .white)
        .background(isSelected ? Color.white : Color.white.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(isSelected ? 0 : 0.18), lineWidth: 1))
        .contentShape(Capsule())
    }
}
```
- `let action: () -> Void`: bu STRUCT, "PARAMETRE almayan, hiçbir şey DÖNDÜRMEYEN bir CLOSURE"
  SAKLIYOR — DIŞARIDAN (`WeatherFilterView`'DAN) VERİLEN "dokununca NE olsun" MANTIĞI.
  `Button(action: action)`: bu SAKLANAN closure'ı DOĞRUDAN butonun EYLEMİ olarak KULLANIYOR.
- `.contentShape(Capsule())`: (bkz. `GlassCard` notundaki AYNI konu) — bu CHIP `GlassCard`'ı
  KULLANMADIĞI (kendi `Capsule` şeklini elle KURDUĞU) için AYNI "sadece İÇERİK dokunulabilir" SORUNUNU
  AYRICA burada da ÇÖZMEMİZ gerekti.

### `Views/FilterResultsView.swift`
```swift
struct FilterResultsView: View {
    let filter: WeatherFilter
    let unit: TemperatureUnit
    @EnvironmentObject var viewModel: WeatherViewModel
    @Namespace private var zoomNamespace

    @State private var groups: [CountryGroup] = []

    private func recomputeGroups() {
        let matches: [FilteredCity] = viewModel.savedCities.compactMap { favorite in
            guard let weather = viewModel.favoriteSnapshots[favorite.name.lowercased()], filter.matches(weather) else { return nil }
            return FilteredCity(name: favorite.name, temperature: weather.temperature, systemIconName: weather.systemIconName, country: weather.localizedCountryName, location: favorite.location)
        }
        let grouped = Dictionary(grouping: matches, by: \.country)
        groups = grouped.map { country, cities in CountryGroup(country: country, cities: cities.sorted { $0.name < $1.name }) }.sorted { $0.country < $1.country }
    }
    ...
}
```
- **Yaşanan bir hata (liste yavaşça yukarı aşağı kayıyordu)**: `groups` BAŞTA düz bir COMPUTED
  property'ydi, yani `body` HER çağrıldığında baştan HESAPLANIYORDU. `@EnvironmentObject` kullanan bir
  View, bağlı olduğu nesnedeki HERHANGİ bir `@Published` alan DEĞİŞTİĞİNDE TÜM body'sini YENİDEN
  çalıştırıyor — bu ekranla HİÇ ilgisi olmayan bir alan (mesela BAŞKA bir sayfanın sıcaklık verisi)
  değişse BİLE `FilterResultsView.body` yeniden çalışıp `groups`'u SIFIRDAN hesaplıyordu. Arka
  plandaki `AmbientBackgroundView`'ın sürekli dönen (5 saniyelik, sonsuz TEKRARLI) animasyonu
  AÇIKKEN, bu sık tekrarlanan (ama İÇERİK olarak hep AYNI sonucu üreten) yeniden hesaplama, SwiftUI'ın
  o an aktif olan animasyon BAĞLAMINI bu YENİ (ama değer olarak AYNI) satır dizisine de UYGULAMASINA
  yol açtı — kullanıcı buna "liste yavaşça yukarı aşağı kayıyor" diye BAKTI.
- **Çözüm**: `groups`'u artık bir `@State` DEĞİŞKENİ yaptık, sonucu `recomputeGroups()` fonksiyonuyla
  SADECE `.onAppear` VE `viewModel.favoriteSnapshots`/`viewModel.savedCities` GERÇEKTEN değiştiğinde
  (`.onChange(of:)` ile, aşağıda) hesaplıyoruz — ekranla İLGİSİZ bir `@Published` değişikliği artık
  `body`'yi tetiklese BİLE `groups` AYNI kalıyor, liste kaymıyor.
- `.compactMap { favorite in guard ... else { return nil }; return FilteredCity(...) }`: HER favori
  İÇİN, EĞER o şehrin ÖNBELLEKTE verisi VARSA VE filtreye UYUYORSA bir `FilteredCity` ÜRETİYOR, aksi
  halde `nil` (compactMap `nil`LERİ ATLAR) — SONUÇTA sadece KRİTERE uyan şehirler KALIYOR.
- `Dictionary(grouping: matches, by: \.country)`: bir DİZİYİ, VERİLEN bir ÖZELLİĞE (burada `country`)
  göre GRUPLAYIP bir `[String: [FilteredCity]]` SÖZLÜĞÜNE ÇEVİREN HAZIR bir BAŞLATICI — "her ÜLKE
  KENDİ şehirleriyle EŞLEŞSİN" demenin KISA yolu.
- `.map { country, cities in CountryGroup(...) }`: sözlüğün HER (anahtar, DEĞER) çiftini bir
  `CountryGroup`'A ÇEVİRİP tekrar bir DİZİYE DÖNÜŞTÜRÜYOR; `.sorted { $0.name < $1.name }` şehirleri
  ALFABETİK sıralıyor.
- `.sorted { $0.country < $1.country }`: EN DIŞTAKİ liste de ÜLKE ismine GÖRE alfabetik SIRALANIYOR.

```swift
var body: some View {
    ZStack {
        AmbientBackgroundView(colors: WeatherPalette.chromeColors).ignoresSafeArea()
        if groups.isEmpty {
            GlassWarningView(iconName: "line.3.horizontal.decrease.circle", message: String(localized: "home.filter_no_matches", defaultValue: "..."))
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.cities) { city in
                            NavigationLink(destination: WeatherView(location: city.location, zoomNamespace: zoomNamespace)) {
                                CityWeatherRow(name: city.name, temperature: city.temperature, systemIconName: city.systemIconName, unit: unit)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .matchedTransitionSource(id: city.name, in: zoomNamespace)
                            ...
                        }
                    } header: {
                        Text(group.country).font(.weatherSectionHeader).tracking(1.1).foregroundColor(.white.opacity(0.75))
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
    .foregroundColor(.white)
    .navigationTitle("Sonuçlar")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .onAppear { recomputeGroups() }
    .onChange(of: viewModel.favoriteSnapshots) { _, _ in recomputeGroups() }
    .onChange(of: viewModel.savedCities) { _, _ in recomputeGroups() }
}
```
- `if groups.isEmpty { ... } else { ... }`: SONUÇ YOKSA bir UYARI kartı, VARSA GRUPLANMIŞ liste
  GÖSTERİLİYOR.
- Her `CountryGroup` bir `Section`; `header:` KISMINDAKİ `Text(group.country)` SADECE bir BAŞLIK —
  DOKUNULABİLİR bir SATIR DEĞİL (eski TASARIMDA ülkeye dokununca AYRI bir ekrana GEÇİLİYORDU, artık
  YOK).
- `NavigationLink(destination: WeatherView(location: city.location, ...))`: `city.location`,
  `FilteredCity.location`'DAN geliyor (bu da `FavoriteCity.location`'DAN, yani KOORDİNAT bilinen bir
  favori İÇİN her ZAMAN koordinatla GİDİYOR).
- `.onAppear { recomputeGroups() }`: ekran İLK göründüğünde listeyi BİR KERE hesaplıyor.
- `.onChange(of: viewModel.favoriteSnapshots) { _, _ in recomputeGroups() }` VE aynısı `savedCities`
  İÇİN: liste SADECE bu İKİ kaynak GERÇEKTEN değiştiğinde YENİDEN hesaplanıyor — `CityWeather` zaten
  `Equatable`, `FavoriteCity` zaten `Hashable` (dolayısıyla `Equatable`) OLDUĞU için `.onChange(of:)`
  bu KARŞILAŞTIRMAYI SORUNSUZ yapabiliyor, EK bir kod YAZMAYA gerek KALMADI.

```swift
struct FilteredCity: Identifiable, Hashable {
    let name: String; let temperature: Double; let systemIconName: String; let country: String; let location: WeatherLocation
    var id: String { name }
}
struct CountryGroup: Identifiable, Hashable {
    let country: String; let cities: [FilteredCity]
    var id: String { country }
}
```
- İKİSİ de SADECE GÖSTERİM İÇİN gereken BİLGİYİ taşıyan KÜÇÜK struct'lar — `CityWeather`'IN TAMAMINI
  DEĞİL.

### `Views/SettingsView.swift`
```swift
struct SettingsView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(colors: WeatherPalette.chromeColors).ignoresSafeArea()
                List {
                    Section {
                        Picker("Sıcaklık Birimi", selection: $viewModel.preferredUnit) {
                            Text("Santigrat (°C)").tag(TemperatureUnit.celsius)
                            Text("Fahrenayt (°F)").tag(TemperatureUnit.fahrenheit)
                        }
                        .tint(.white)
                        ...
                        Picker("Rüzgar Birimi", selection: $viewModel.preferredWindUnit) { ... }
                        ...
                    } header: { Text("BİRİMLER")... }
                    Section { HStack { Text("Sürüm"); Spacer(); Text("1.0") } ... } header: { Text("HAKKINDA")... }
                }
                ...
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
        }
    }
}
```
- `Picker("Sıcaklık Birimi", selection: $viewModel.preferredUnit) { Text(...).tag(...) ... }`: bir
  SEÇİM kontrolü — `selection:` PARAMETRESİ bir `@Binding`; İÇİNDEKİ HER `Text`'in `.tag(...)`'I, o
  SEÇENEĞE karşılık GELEN GERÇEK DEĞERİ belirtiyor. Kullanıcı BİR SEÇENEĞE dokununca,
  `viewModel.preferredUnit` DOĞRUDAN o DEĞERE GÜNCELLENİYOR (`WeatherViewModel`'İN KENDİ `didSet`'İ
  bunu OTOMATİK UserDefaults'a YAZIYOR).
- `ToolbarItem(placement: .cancellationAction)`: sistemin "İPTAL/kapat" EYLEMİ İÇİN AYRILMIŞ standart
  bir KONUM (genelde SOL üst) — `Button("Kapat") { dismiss() }` bu MODAL EKRANI kapatıyor.

### `Views/GlassWarningView.swift`
```swift
struct GlassWarningView: View {
    var iconName: String
    var message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName).font(.system(size: 40, weight: .light)).foregroundColor(.white)
            Text(message).font(.weatherBody).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.9))
        }
        .padding(24).frame(maxWidth: .infinity).weatherGlassCard().padding(.horizontal)
    }
}
```
- **Temizlik**: eskiden opsiyonel `actionTitle: String?`/`action: (() -> Void)?` parametreleri VE bir
  "tekrar dene" butonu vardı — ama uygulamadaki GERÇEK çağrı yerlerinin (boş favori listesi, konum izni
  yok, arama sonucu yok, filtre sonucu yok) HİÇBİRİ bu butonu KULLANMIYORDU, sadece dosyanın kendi
  `#Preview`'ı deniyordu. Kullanılmayan parametreleri VE buton dalını kaldırdık — artık bu View SADECE
  ikon + mesaj gösteren, tek işi olan basit bir View.
- `multilineTextAlignment(.center)`: metin BİRDEN FAZLA satıra YAYILIRSA (uzun UYARI mesajları GİBİ)
  HER satırı ORTALIYOR.

### `Views/AirQualityCard.swift`
```swift
struct AirQualityCard: View {
    let airQuality: AirQuality
    var body: some View {
        HStack(spacing: 16) {
            Circle().fill(airQuality.tintColor).frame(width: 14, height: 14).shadow(color: airQuality.tintColor.opacity(0.6), radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("HAVA KALİTESİ").weatherLabelStyle().foregroundColor(.white.opacity(0.6))
                Text(airQuality.label).font(.weatherRowTitle).foregroundColor(.white)
            }
            Spacer()
        }
        .padding().weatherGlassCard(accentTint: airQuality.tintColor).accessibilityElement(children: .combine)
    }
}
```
- `Circle().fill(airQuality.tintColor)...shadow(color: airQuality.tintColor.opacity(0.6), radius: 4)`:
  küçük, RENKLİ bir "durum NOKTASI" — endekse göre YEŞİLDEN mora DEĞİŞEN renk, ETRAFINDA AYNI renkte
  hafif bir PARILTI (glow) VEREN bir gölge.
- `Spacer()`: `HStack` İÇİNDE kalan TÜM boş alanı DOLDURUP, ÖNCEKİ içeriği SOLA, kendisinden SONRAKİ
  (varsa) İÇERİĞİ SAĞA İTEN "esnek" bir BOŞLUK — burada SADECE soldaki İÇERİĞİ sıkıştırıp kartın
  KALAN kısmını BOŞ bırakıyor.

---

## Views/Components/

### `Views/Components/WeatherContentView.swift`
```swift
struct WeatherContentView: View {
    let weather: CityWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    let airQuality: AirQuality?
    let unit: TemperatureUnit
    let windUnit: WindSpeedUnit
    let lastUpdated: Date?
    let onRefresh: () -> Void

    private var cityTimeZone: TimeZone {
        TimeZone(secondsFromGMT: weather.timezoneOffsetSeconds) ?? .current
    }

    private var cityCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = cityTimeZone
        return calendar
    }

    private func localTimeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone))
    }
    ...
}
```
- Bu View TAMAMEN SAF (bkz. `Kod-Rehberi.md`'DEKİ gerekçe) — HİÇBİR `@EnvironmentObject`/ViewModel
  KULLANMIYOR, sadece PARAMETRE olarak ALDIĞI veriyi GÖSTERİYOR. `WeatherView`'IN gövdesinden BİLEREK
  AYRI bir dosyada tutuluyor ki Xcode Preview'ında TEK BAŞINA, örnek veriyle KOLAYCA test edilebilsin.
- `cityTimeZone`: `weather.timezoneOffsetSeconds`'TAN (o ŞEHRİN kendi saat DİLİMİ) bir `TimeZone`
  KURUYOR — hem `cityCalendar` hem aşağıdaki CANLI saat gösterimi BUNU kullanıyor, TELEFONUN değil
  ŞEHRİN saatini.
- `cityCalendar`: günlük tahmin SATIRLARINDAKİ "Bugün/Yarın" hesabı CİHAZIN değil ŞEHRİN saatine göre
  YAPILSIN diye.
- `localTimeText(_:)`: verilen bir ANI, `cityTimeZone`'A göre "14:32" gibi KISA bir saat METNİNE
  ÇEVİRİYOR. `Date.FormatStyle(date: .omitted, time: .shortened, timeZone: cityTimeZone)`: `date: .omitted`
  TARİHİ hiç YAZDIRMA, sadece SAATİ; `time: .shortened` sistemin 12/24 saat AYARINA göre KISA biçim;
  `timeZone:` PARAMETRESİ ÖNEMLİ — VERMEZSEK bu format telefonun KENDİ saat dilimini KULLANIRDI, biz
  BİLEREK şehrin saat dilimini VERİYORUZ.

```swift
var body: some View {
    ScrollView(showsIndicators: false) {
        VStack(spacing: 4) {
            VStack(spacing: 6) {
                Text(weather.name).font(.weatherCityName).foregroundColor(.white).padding(.top, 40)
                Text(weather.localizedCountryName).font(.weatherCaption).foregroundColor(.white.opacity(0.6))
                TimelineView(.everyMinute) { timeline in
                    HStack(spacing: 5) { Image(systemName: "clock.fill").font(.system(size: 11, weight: .semibold)); Text(localTimeText(timeline.date)).font(.weatherRowSubtitle.bold()) }
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75))
                }
                .padding(.top, 2)
                Text(unit.format(weather.temperature)).font(.weatherHero).foregroundColor(.white).contentTransition(.numericText()).padding(.leading, 15)
                HStack(spacing: 8) {
                    Image(systemName: weather.systemIconName).symbolRenderingMode(.multicolor).symbolEffect(.bounce, value: weather.conditionCode)
                    Text(weather.conditionDescription.capitalized).font(.weatherCondition)
                }
                .foregroundColor(.white).opacity(0.9)
                HStack(spacing: 6) {
                    Text(String(format: String(localized: "weather.high_format", defaultValue: "Y:%@"), unit.format(weather.tempMax)))
                    Text(String(format: String(localized: "weather.low_format", defaultValue: "D:%@"), unit.format(weather.tempMin)))
                }
                .font(.weatherTemperatureSmall).foregroundColor(.white.opacity(0.75)).padding(.top, 2)
                if abs(weather.feelsLike - weather.temperature) >= 2 {
                    Text(feelsLikeNote(for: weather)).font(.weatherCaption).foregroundColor(.white.opacity(0.6)).padding(.top, 2)
                }
                if let lastUpdated {
                    Text("Son güncelleme: \(lastUpdated.formatted(date: .omitted, time: .shortened))").font(.weatherCaption).foregroundColor(.white.opacity(0.55)).padding(.top, 2)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            Spacer().frame(height: 30)
            ...
        }
    }
    .refreshable { onRefresh() }
    .sensoryFeedback(.success, trigger: lastUpdated)
}
```
- `.contentTransition(.numericText())`: sıcaklık DEĞERİ DEĞİŞTİĞİNDE (yenilendiğinde), rakamların
  BİRBİRİNE YUMUŞAKÇA "SAYAÇ gibi" GEÇİŞ yapmasını SAĞLAYAN, sisteme ÖZEL bir animasyon.
- `.symbolEffect(.bounce, value: weather.conditionCode)`: `weather.conditionCode` DEĞİŞTİĞİNDE (farklı
  bir HAVA durumuna GEÇİLDİĞİNDE), ikon HAFİFÇE "ZIPLAYARAK" DİKKAT ÇEKİYOR — `value:` PARAMETRESİ
  "BU DEĞER değiştiğinde efekti TETİKLE" demek.
- `abs(weather.feelsLike - weather.temperature) >= 2`: `abs(...)`, bir SAYININ MUTLAK değerini (İŞARETİNİ
  yok SAYAR) ALIYOR — hissedilen İLE gerçek sıcaklık ARASINDAKİ FARK, YÖNÜNE bakılmaksızın (daha SICAK
  ya da daha SERİN) 2 dereceden BÜYÜKSE not GÖSTERİLİYOR.
- `lastUpdated.formatted(date: .omitted, time: .shortened)`: sadece SAATİ (TARİH olmadan), cihazın
  12/24 saat AYARINA göre GÖSTERİYOR.
- `.refreshable { onRefresh() }`: aşağı ÇEKME (pull-to-refresh) jesti — DIŞARIDAN VERİLEN `onRefresh`
  closure'ını ÇAĞIRIYOR (bu View KENDİSİ NASIL yenileneceğini BİLMİYOR, sadece "YENİLE" DENDİĞİNDE
  dışarıya HABER veriyor).
- `.sensoryFeedback(.success, trigger: lastUpdated)`: `lastUpdated` DEĞİŞTİĞİNDE (yeni veri BAŞARIYLA
  geldiğinde) BİR "başarı" DOKUNSAL geri bildirimi.
- `TimelineView(.everyMinute) { timeline in ... }`: (bkz. Bölüm 1 — bu da bir property wrapper DEĞİL,
  ama BENZER bir "otomatik yenileme" fikri) sistemin HAZIR bir zamanlayıcı ARACI — İÇİNDEKİ View'ı, GERÇEK
  dakika SINIRINA (14:31:00, 14:32:00 gibi) TAM hizalı şekilde YENİDEN çiziyor. `timeline.date`, o an
  geçerli OLAN zamanı VERİYOR; biz bunu `localTimeText(...)`'E vererek EKRANDAKİ saati GÜNCEL tutuyoruz —
  elle bir `Timer` KURMAMIZA ve `@State` GÜNCELLEMEMİZE hiç GEREK kalmadı.
- **Yaşanan bir hata (okunabilirlik)**: bu saat yazısı İLK halinde ÇOK küçük (`caption2`) ve ÇOK soluktu
  (%55 opaklık), göze HİÇ çarpmıyordu. **Çözüm**: fontu `weatherRowSubtitle.bold()`'A büyütüp opaklığı
  %92'ye ÇIKARDIK, VE etrafına ince bir cam HAP (`Capsule().fill(.white.opacity(0.14))` + ince bir
  `strokeBorder` KENARLIK) EKLEDİK. `.background(Capsule().fill(...))`: metnin ARKASINA, kapsül
  ŞEKLİNDE, hafif dolgun bir zemin ÇİZİYOR. `.overlay(Capsule().strokeBorder(...))`: o ZEMİNİN
  KENARINA, ÇOK ince (0.75 punto) bir ÇİZGİ ekliyor. Bu İKİSİ birlikte, uygulamanın ZATEN başka
  yerlerde (favori DEĞİŞTİRME şeridindeki çipler gibi) KULLANDIĞI "cam çip" görünümünü BURAYA da
  taşıyor — hem daha ŞIK/TUTARLI görünüyor hem de artık GERÇEKTEN fark ediliyor.

```swift
if !hourly.isEmpty {
    VStack(alignment: .leading, spacing: 10) {
        sectionHeader("24 SAATLİK TAHMİN", icon: "clock")
        TimelineView(.everyMinute) { timeline in
            Chart {
                ForEach(Array(hourly.enumerated()), id: \.offset) { index, forecast in
                    AreaMark(x: .value("Saat", forecast.time), y: .value("Sıcaklık", forecast.temperature))
                        .foregroundStyle(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Saat", forecast.time), y: .value("Sıcaklık", forecast.temperature))
                        .foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    if index % 3 == 0 {
                        PointMark(x: .value("Saat", forecast.time), y: .value("Sıcaklık", forecast.temperature))
                            .foregroundStyle(.white)
                            .annotation(position: .top) { Text(unit.format(forecast.temperature)).font(.weatherTemperatureSmall.bold()).foregroundColor(.white) }
                    }
                }
                RuleMark(x: .value("Şu An", timeline.date))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, spacing: 2) {
                        Text(localTimeText(timeline.date)).font(.caption2.bold()).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.35)))
                    }
            }
            .padding(.top, 20)
            .frame(height: 120)
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { _ in AxisValueLabel(format: .dateTime.hour()).foregroundStyle(.white) } }
            .chartYAxis(.hidden)
        }
    }
    .padding().weatherGlassCard().padding(.horizontal, 20)
}
```
- `Chart { ... }`: Apple'ın `Charts` FRAMEWORK'ÜNÜN grafik KONTEYNER'i — İÇİNE KOYULAN HER "Mark" (AreaMark/
  LineMark/PointMark/RuleMark) bir VERİ SERİSİNİ TEMSİL EDİYOR.
- `AreaMark`: NOKTALARIN ALTINDAKİ alanı BİR GRADYANLA DOLDURUYOR (grafiğin "gölgeli" GÖRÜNÜMÜ).
  `LineMark`: noktaları BİRLEŞTİREN ÇİZGİ. `PointMark`: TEK TEK noktaların KENDİSİ (nokta İŞARETİ +
  ÜSTÜNDEKİ sıcaklık ETİKETİ).
- `index % 3 == 0`: `%` (MOD/kalan) OPERATÖRÜ — bir SAYININ 3'E bölümünden KALAN sıfırsa (yani index
  0, 3, 6, 9... İSE) `true`. Bu SAYEDE nokta İŞARETİ VE etiketi SADECE HER 3 SAATTE bir GÖSTERİLİYOR
  (eksendeki 3 saatlik İŞARETLERLE hizalı), 24'ÜN HEPSİNE değil — ÇİZGİ/ALAN İSE hâlâ TÜM 24 noktayı
  KULLANIYOR (pürüzsüz KALSIN diye).
- `RuleMark(x: .value("Şu An", timeline.date))`: grafiğin ÜZERİNE, "şu an" NEREDE olduğumuzu gösteren
  DİKEY, KESİK çizgili ince bir İŞARET çiziyor. `x` değeri GERÇEK `Date()` (TimelineView'DAN gelen
  `timeline.date`) — `hourly` verisi ZATEN "şu andan İTİBAREN 24 saat" mantığıyla çekildiği İÇİN, bu
  çizgi grafiğin SOL ucuna YAKIN başlayıp, `TimelineView` her DAKİKA yeniden ÇİZDİKÇE sağa doğru KAYAR,
  yani GERÇEK zamanın geçişini GÖRSEL olarak yansıtır.
- `.annotation(position: .top, spacing: 2) { ... }`: bir Mark'IN ÜSTÜNE, İSTEDİĞİMİZ HERHANGİ bir
  SwiftUI View'ı (burada bir `Text`) YERLEŞTİRMEMİZİ sağlıyor — hem sıcaklık ETİKETLERİ hem de "şu an"
  ÇİZGİSİNİN ÜSTÜNDEKİ saat YAZISI bunu kullanıyor. `spacing: 2`, ETİKETİN çizgiye ne KADAR YAKIN
  duracağını AYARLIYOR.
- **Yaşanan bir hata (çakışma)**: "şu an" etiketi İLK halinde HEMEN üstündeki "24 SAATLİK TAHMİN"
  başlığıyla ÇAKIŞIP karman ÇORMAN görünüyordu — çünkü grafiğin ÇİZİM alanı, üstündeki başlıkla ARASINDA
  SADECE `VStack`'in `spacing: 10`'u kadar BOŞLUK vardı, etiketin KENDİSİ de bu boşluğa SIĞMIYORDU.
  **Çözüm — iki parça**: (1) `Text(...).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.35)))`
  — etiketi KENDİ küçük, YARI SAYDAM SİYAH kapsülüne ALDIK; böylece grafiğin DEĞİŞKEN (bazen açık bazen
  koyu) arka planından her ZAMAN ayrışıp okunaklı KALIYOR. (2) `Chart { ... }.padding(.top, 20)` —
  Chart'IN kendisine, `.frame(height: 120)`'DAN ÖNCE 20 punto'luk bir ÜST boşluk EKLEDİK; bu, Chart'ın
  GERÇEK çizim alanını 120'DEN biraz KÜÇÜLTÜP, üstte etiketin TAŞABİLECEĞİ bir TAMPON bölge BIRAKIYOR —
  etiket artık BAŞLIĞA hiç DEĞMİYOR.
- `.chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { _ in ... } }`: X eksenindeki
  İŞARETLERİ "HER 3 saatte bir" OLACAK şekilde ÖZELLEŞTİRİYORUZ; `AxisValueLabel(format: .dateTime.hour())`
  o işaretin ALTINA sadece SAATİ (14, 17, 20 GİBİ) yazıyor.
- `.chartYAxis(.hidden)`: DİKEY (sıcaklık) eksenini TAMAMEN GİZLİYOR — grafik SADECE görsel bir "TREND"
  hissi VERMESİ yeterli, TAM sayısal DEĞERLER zaten NOKTA etiketlerinde VAR.

```swift
if !daily.isEmpty {
    VStack(alignment: .leading, spacing: 10) {
        sectionHeader("ÖNÜMÜZDEKİ GÜNLER", icon: "calendar")
        VStack(spacing: 12) { ForEach(daily) { day in DailyForecastRow(day: day, calendar: cityCalendar, unit: unit) } }
            .padding().weatherGlassCard()
    }
    .padding(.horizontal, 20)
}
Spacer().frame(height: 20)
if let airQuality { AirQualityCard(airQuality: airQuality).padding(.horizontal, 20); Spacer().frame(height: 20) }
GlassEffectContainer {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
        WeatherDetailBox(icon: "humidity", iconColor: .blue, title: "NEM", value: weather.humidity.percentFormatted)
        WindDetailBox(speedKmh: weather.windSpeed, degrees: weather.windDeg, gustKmh: weather.windGust, unit: windUnit)
        WeatherDetailBox(icon: "thermometer.sun", iconColor: .orange, title: "HİSSEDİLEN", value: unit.format(weather.feelsLike))
        WeatherDetailBox(icon: "barometer", iconColor: .purple, title: "BASINÇ", value: "\(weather.pressure) hPa")
        WeatherDetailBox(icon: "eye", iconColor: .teal, title: "GÖRÜŞ", value: "\(weather.visibility / 1000) km")
        WeatherDetailBox(icon: "cloud", iconColor: .gray, title: "BULUTLULUK", value: weather.cloudiness.percentFormatted)
        WeatherDetailBox(icon: "thermometer.and.liquid.waves", iconColor: .cyan, title: "ÇİĞ NOKTASI", value: unit.format(weather.dewPoint))
        SunTimesBox(sunrise: weather.sunrise, sunset: weather.sunset)
    }
}
.padding(.horizontal, 20).padding(.bottom, 40)
```
- `GridItem(.flexible())`: bir IZGARA SÜTUNUNUN "MEVCUT alanı, DİĞER esnek SÜTUNLARLA EŞİT paylaş"
  demesi — İKİ `.flexible()` YAN YANA KOYUNCA, EKRAN İKİ EŞİT sütuna BÖLÜNÜYOR.
- `GlassEffectContainer { ... }`: BİRDEN FAZLA cam KARTIN (8 KUTU) AYNI "IŞIK/BULANIKLIK" HESABINI
  PAYLAŞMASI İÇİN bir SARMALAYICI — bu OLMASA her kart KENDİ BAŞINA ayrı bir BULANIKLIK hesaplardı,
  performans VE görsel TUTARLILIK açısından DAHA MALİYETLİ/tutarsız OLURDU.
- `weather.visibility / 1000`: API METRE cinsinden VERİYOR, burada KİLOMETREYE ÇEVRİLİYOR (basit tam
  sayı BÖLMESİ — `Int / Int` sonucu YİNE `Int`, ONDALIK kısım ATILIYOR).
- `SunTimesBox`, TEK bir "ÇİĞ NOKTASI" satırından SONRA, IZGARANIN SEKİZİNCİ (son) HÜCRESİNİ
  DOLDURUYOR — `LazyVGrid` içindeki HER öğe SIRAYLA ızgaraya YERLEŞTİRİLİYOR, kaçıncı sütun/SATIRDA
  olacağı OTOMATİK hesaplanıyor.

```swift
private func feelsLikeNote(for weather: CityWeather) -> String {
    weather.feelsLike > weather.temperature
        ? String(localized: "weather.feels_warmer", defaultValue: "Gerçek sıcaklıktan daha sıcak hissettiriyor")
        : String(localized: "weather.feels_cooler", defaultValue: "Gerçek sıcaklıktan daha serin hissettiriyor")
}
private func sectionHeader(_ title: LocalizedStringKey, icon: String) -> some View {
    HStack { Image(systemName: icon); Text(title).tracking(1.1) }
        .font(.weatherSectionHeader).foregroundColor(.white.opacity(0.6)).padding(.horizontal, 5)
}
```
- `sectionHeader(_:icon:) -> some View`: bir View ÜRETEN, `private` bir YARDIMCI FONKSİYON — "24 SAATLİK
  TAHMİN"/"ÖNÜMÜZDEKİ GÜNLER" gibi İKİ farklı YERDE AYNI GÖRÜNÜMÜ (ikon + BAŞLIK, aynı STİL) TEKRAR
  YAZMAMAK için.
- `title: LocalizedStringKey`: (bkz. Bölüm 1) BİLEREK bu tip SEÇİLDİ — çağıran TARAF `sectionHeader("24 SAATLİK TAHMİN", ...)`
  gibi DÜZ bir literal VERDİĞİNDE, SwiftUI bunu OTOMATİK olarak YERELLEŞTİRME kataloğunda ARASIN diye.

### `Views/Components/WeatherStateScaffold.swift`
```swift
struct WeatherStateScaffold<SuccessContent: View>: View {
    let state: WeatherViewState
    let onRetry: () -> Void
    @ViewBuilder let successContent: (CityWeather) -> SuccessContent

    var body: some View {
        switch state {
        case .idle, .loading: WeatherLoadingSkeleton()
        case .success(let weather): successContent(weather)
        case .error(let errorMessage):
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 36)).foregroundColor(.white)
                Text(errorMessage).font(.weatherBody).foregroundColor(.white).multilineTextAlignment(.center)
                Button("Tekrar Dene") { onRetry() }.buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}
```
- `struct WeatherStateScaffold<SuccessContent: View>`: GENERIC bir View (bkz. Bölüm 1) —
  `SuccessContent`, "HERHANGİ bir View TİPİ OLABİLİR" demek; ÇAĞIRAN taraf `successContent` closure'ı
  İÇİNDE HANGİ View'ı DÖNDÜRÜRSE (`WeatherContentView` gibi), `SuccessContent` OTOMATİK olarak O TİP
  olarak ÇÖZÜLÜYOR.
- `@ViewBuilder let successContent: (CityWeather) -> SuccessContent`: bir CityWeather ALIP bir View
  ÜRETEN CLOSURE; `@ViewBuilder` sayesinde bu closure'ın İÇİNDE (çağrıldığı YERDE) BİRDEN FAZLA View
  İFADESİ art arda YAZILABİLİYOR.
- `switch state { case .idle, .loading: ...; case .success(let weather): successContent(weather); case .error(let errorMessage): ... }`:
  `WeatherViewState`'İN DÖRT durumunu TEK bir yerde İŞLİYOR — HEM `WeatherView` HEM DE karuselin HER
  sayfası bu AYNI switch'İ (kod TEKRARI olmadan) KULLANIYOR.
- `Spacer(); VStack { ... }; Spacer()`: hata GÖRÜNÜMÜNÜ EKRANIN DİKEY ORTASINA İTEN İKİ boşluk —
  üstteki VE alttaki Spacer'lar EŞİT genişlemeye ÇALIŞTIĞI için İÇERİK TAM ORTADA KALIYOR.

### `Views/Components/WeatherDetailBox.swift`
```swift
struct WeatherDetailBox: View {
    var icon: String
    var iconColor: Color = .white
    var title: LocalizedStringKey
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.weatherCardTitle).foregroundColor(iconColor)
                Text(title).weatherLabelStyle().foregroundColor(.white.opacity(0.7))
            }
            Text(value).font(.weatherCardValue).foregroundColor(.white)
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).frame(height: 138)
        .weatherGlassCard(accentTint: iconColor)
        .accessibilityElement(children: .combine)
    }
}
```
- `var iconColor: Color = .white`: VARSAYILAN bir DEĞERE sahip bir PARAMETRE — çağıran taraf
  BELİRTMEZSE beyaz KULLANILIYOR (ama BU projede HER çağrı KENDİ rengini VERİYOR: nem MAVİ, basınç
  MOR gibi).
- İki `.frame`: BİRİNCİSİ (`maxWidth: .infinity`) YATAYDA MÜMKÜN olan en GENİŞ alanı KAPLAMASINI,
  İKİNCİSİ (`height: 138`) DİKEY YÜKSEKLİĞİ SABİTLİYOR — TÜM detay KUTULARININ ızgarada AYNI boyda
  GÖRÜNMESİ İÇİN (rüzgar kutusundaki HAMLE satırı BAZEN olduğu İÇİN yükseklik 110'DAN 138'e ÇIKARILDI).
- `.weatherGlassCard(accentTint: iconColor)`: kartın KENDİSİ de, İKONUN rengiyle AYNI hafif bir RENK
  KİMLİĞİ ALIYOR (arkasında O renkte bulanık bir PARILTI + o RENK tonunda bir KENARLIK).

### `Views/Components/WindDetailBox.swift`
```swift
struct WindDetailBox: View {
    let speedKmh: Double
    let degrees: Int?
    let gustKmh: Double?
    let unit: WindSpeedUnit
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 6) { Image(systemName: "wind")...; Text("RÜZGAR")... }
            HStack(spacing: 8) {
                Text(unit.format(speedKmh)).font(.weatherCardValue).foregroundColor(.white)
                if let degrees {
                    Image(systemName: "location.north.fill").font(.caption).foregroundColor(.white.opacity(0.85)).rotationEffect(.degrees(Double(degrees)))
                }
            }
            if let gustKmh, gustKmh > speedKmh {
                Text(String(format: String(localized: "wind.gust_format", defaultValue: "Hamle: %@"), unit.format(gustKmh))).font(.weatherCaption).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).frame(height: 138).weatherGlassCard(accentTint: .mint).accessibilityElement(children: .combine)
    }
}
```
- `.rotationEffect(.degrees(Double(degrees)))`: bir OK İKONUNU (`location.north.fill`, VARSAYILAN
  olarak KUZEYİ gösteren bir OK) RÜZGARIN geldiği YÖNE göre DÖNDÜRÜYOR — API'DEN gelen `Int` derece
  DEĞERİ, `Double`'A ÇEVRİLİP DOĞRUDAN dönüş AÇISI olarak KULLANILIYOR.
- `if let gustKmh, gustKmh > speedKmh`: İKİ koşul — HAMLE değeri BİLİNMELİ VE normal HIZDAN daha
  BÜYÜK olmalı (BAZEN API ikisini AYNI/YAKIN verebiliyor, o DURUMDA ayrı bir satır GÖSTERMENİN
  ANLAMI yok).

### `Views/Components/SunTimesBox.swift`
```swift
struct SunTimesBox: View {
    let sunrise: Date?
    let sunset: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 6) { Image(systemName: "sun.horizon")...; Text("GÜNDOĞUMU / GÜNBATIMI")... }
            HStack(spacing: 14) {
                Label { Text(sunrise?.formatted(date: .omitted, time: .shortened) ?? "--:--") } icon: { Image(systemName: "sunrise.fill").foregroundColor(.orange) }
                Label { Text(sunset?.formatted(date: .omitted, time: .shortened) ?? "--:--") } icon: { Image(systemName: "sunset.fill").foregroundColor(.indigo) }
            }
            .font(.weatherCaption.bold()).foregroundColor(.white)
            Spacer()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).frame(height: 138).weatherGlassCard(accentTint: .orange).accessibilityElement(children: .combine)
    }
}
```
- `Label { ... } icon: { ... }`: SwiftUI'ın "bir İKON + bir METİN" İÇİN hazır KALIBI — `icon:`
  kısmındaki View SOLDA (ya da PLATFORMA göre uygun YERDE), `Label { }` KISMINDAKİ metin YANINDA
  GÖSTERİLİYOR; elle bir `HStack { Image; Text }` KURMAKTAN daha SEMANTİK.
- `sunrise?.formatted(...) ?? "--:--"`: `sunrise` NİL İSE (veri henüz GELMEDİYSE ya da API VERMEDİYSE)
  YER TUTUCU bir METİN ("--:--") GÖSTERİYOR — çökme/BOŞ görünüm RİSKİ yok.

### `Views/Components/DailyForecastRow.swift`
```swift
struct DailyForecastRow: View {
    let day: DailyForecast
    let calendar: Calendar
    let unit: TemperatureUnit
    var body: some View {
        HStack {
            Text(RelativeDayFormatter.label(for: day.date, calendar: calendar)).font(.weatherRowSubtitle).foregroundColor(.white).frame(width: 92, alignment: .leading)
            if day.pop >= 0.1 {
                HStack(spacing: 2) { Image(systemName: "drop.fill").font(.caption2); Text(Int(day.pop * 100).percentFormatted).font(.caption2) }
                    .foregroundColor(.cyan).frame(width: 40, alignment: .leading)
            } else {
                Spacer().frame(width: 40)
            }
            Spacer()
            Image(systemName: day.systemIconName).font(.system(size: 20)).foregroundColor(.white).symbolRenderingMode(.multicolor)
            Spacer()
            HStack(spacing: 12) {
                Text(unit.format(day.minTemperature)).font(.weatherTemperatureSmall).foregroundColor(.white.opacity(0.6))
                Capsule().fill(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing)).frame(width: 60, height: 4)
                Text(unit.format(day.maxTemperature)).font(.weatherTemperatureSmall.bold()).foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
    }
}
```
- `.frame(width: 92, alignment: .leading)`: gün İSMİNE SABİT bir GENİŞLİK VERİYOR — "Bugün" ile
  "Perşembe" FARKLI uzunlukta OLSA bile, SAĞDAKİ öğeler (yağış/ikon/sıcaklık) HER satırda AYNI
  YATAY konumda HİZALI kalıyor.
- `if day.pop >= 0.1 { ... } else { Spacer().frame(width: 40) }`: yağış OLASILIĞI %10'UN altındaysa
  o BÖLGEYİ BOŞ (ama AYNI genişlikte, 40 PUAN) bırakıyor — İÇERİK olsun OLMASIN, satırın GENEL
  HİZASI BOZULMUYOR.
- `Capsule().fill(LinearGradient(colors: [.blue, .orange], ...)).frame(width: 60, height: 4)`: ince,
  YATAY bir ÇUBUK — SOLDAN (soğuk/mavi) SAĞA (sıcak/turuncu) bir GRADYAN, o GÜNÜN en düşük/EN yüksek
  sıcaklığı ARASINDAKİ "aralığı" GÖRSEL olarak TEMSİL ediyor (Apple'IN kendi Hava Durumu'NUN benzer bir
  görsel DİLİNDEN ilham, ama KENDİ basit yorumumuz).

### `Views/Components/WeatherLoadingSkeleton.swift`
```swift
struct WeatherLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8).frame(width: 140, height: 20)
                RoundedRectangle(cornerRadius: 24).frame(width: 160, height: 90)
                RoundedRectangle(cornerRadius: 8).frame(width: 120, height: 18)
            }
            .padding(.top, 60)
            RoundedRectangle(cornerRadius: 20).frame(height: 140).padding(.horizontal, 20)
            RoundedRectangle(cornerRadius: 20).frame(height: 190).padding(.horizontal, 20)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(0..<6, id: \.self) { _ in RoundedRectangle(cornerRadius: 20).frame(height: 138) }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .foregroundColor(.white.opacity(0.18))
        .shimmering()
    }
}
```
- `RoundedRectangle(cornerRadius:).frame(width:height:)`: HİÇBİR gerçek İÇERİK OLMAYAN, SADECE
  "GELECEK ekranın HANGİ boyutlarda kutulardan OLUŞACAĞINI" TAKLİT eden DÜZ dikdörtgenler — şehir ismi,
  sıcaklık, İKİ büyük kart (grafik+günlük TAHMİN), altı KÜÇÜK kart (detay ızgarası) İÇİN.
- `.foregroundColor(.white.opacity(0.18))`: TÜM dikdörtgenler ÇOK SOLUK beyaz — "burada BİR ŞEY
  OLACAK ama henüz YOK" hissi.
- `ForEach(0..<6, id: \.self) { _ in ... }`: 0'DAN 5'e kadar (6 tane) AYNI kutuyu ÜRETİYOR; `_`
  DÖNGÜ değişkenini (SAYININ kendisini) HİÇ KULLANMADIĞIMIZI GÖSTERİYOR — sadece "6 KERE TEKRARLA"
  demek İÇİN.
- `.shimmering()`: aşağıda TANIMLANAN ÖZEL modifier'ı ÇAĞIRIYOR.

```swift
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * 500)
                    .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 2 }
            }
    }
}
private extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}
```
- `@State private var phase: CGFloat = -1`: -1'DEN başlayıp ANİMASYONLA 2'ye KADAR GİDECEK bir
  İLERLEME değeri — bu ARALIK, ışık ÇİZGİSİNİN EKRANIN SOLUNUN biraz DIŞINDAN başlayıp SAĞIN biraz
  DIŞINA kadar GİTMESİNİ sağlıyor (BAŞLANGIÇ/BİTİŞ ekranın TAM kenarında OLSAYDI kesilme ANI fark
  EDİLİRDİ).
- `.overlay(LinearGradient(...).offset(x: phase * 500).mask(content))`: ışık ÇİZGİSİNİ (şeffaf →
  yarı-SAYDAM beyaz → şeffaf bir GRADYAN, 20 derece EĞİK) `phase`'E göre YATAYDA KAYDIRIYOR; `.mask(content)`
  BU IŞIK çizgisini SADECE `content`'İN (dikdörtgenlerin) KAPLADIĞI ALANLA SINIRLIYOR — yani ışık
  SADECE kutuların ÜSTÜNDE GEZİYOR, ARADAKİ boşluklarda GÖRÜNMÜYOR.
- `.repeatForever(autoreverses: false)`: animasyon BİTİNCE (2'ye ULAŞINCA) TERSİNE OYNAMADAN, BAŞA
  (-1'e) ATLAYIP TEKRAR baştan BAŞLIYOR — sürekli AYNI YÖNDE akan bir IŞIK hissi.

### `Views/Components/FavoriteCityRow.swift`
```swift
struct FavoriteCityRow: View {
    let city: String
    let snapshot: CityWeather?
    let unit: TemperatureUnit
    var body: some View {
        if let snapshot {
            CityWeatherRow(name: city, temperature: snapshot.temperature, systemIconName: snapshot.systemIconName, unit: unit)
        } else {
            HStack { Text(city.capitalized)...; Spacer(); ProgressView().tint(.white) }
                .padding(.vertical, 12).padding(.horizontal, 16).weatherGlassCard(cornerRadius: 18)
        }
    }
}
```
- `if let snapshot { CityWeatherRow(...) } else { ... ProgressView() ... }`: veri (favori İÇİN
  önbelleklenmiş HAVA durumu) GELDİYSE paylaşılan `CityWeatherRow`'U kullanıyor, henüz GELMEDİYSE
  sadece İSİM + dönen bir YÜKLENİYOR göstergesi (`ProgressView`) gösteriyor. Bu İKİ dal, TAM olarak
  `WeatherViewState.idle/.loading` VE `.success` durumlarına BENZER bir MANTIK ama BURADA ayrı bir
  enum'a GEREK yok, TEK bir `if let` YETİYOR (çünkü SADECE İKİ durum var: veri VAR/YOK, hata durumu
  YOK — favori SATIRI hiç HATA göstermiyor, sadece SESSİZCE yüklenmeye devam EDİYOR).

### `Views/Components/SearchResultRow.swift`
```swift
struct SearchResultRow: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.weatherRowTitle).foregroundColor(.white)
            .padding(.vertical, 10).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weatherGlassCard(cornerRadius: 18)
    }
}
```
- Artık SADECE isim GÖSTERİYOR (bkz. Kod-Rehberi'NDEKİ "Province" hatası NOTU) — eskiden MapKit'in
  KENDİ, potansiyel olarak İNGİLİZCE idari TERİMLER içerebilen `subtitle`'ını da GÖSTERİYORDU, bu
  GÜVENİLMEZ olduğu İÇİN tamamen KALDIRILDI.

### `Views/Components/CityWeatherRow.swift`
```swift
struct CityWeatherRow: View {
    let name: String
    let temperature: Double
    let systemIconName: String
    let unit: TemperatureUnit
    var body: some View {
        HStack {
            Text(name.capitalized).font(.weatherRowTitle).foregroundColor(.white)
            Spacer()
            Image(systemName: systemIconName).font(.system(size: 20)).symbolRenderingMode(.multicolor).foregroundColor(.white)
            Text(unit.format(temperature)).font(.weatherRowTemperature).foregroundColor(.white)
        }
        .padding(.vertical, 12).padding(.horizontal, 16).weatherGlassCard(cornerRadius: 18)
    }
}
```
- HEM `FavoriteCityRow`'un "veri GELDİ" hâli HEM `FilterResultsView`'DAKİ şehir SATIRI, BİREBİR AYNI
  bu GÖRÜNÜMÜ KULLANIYORDU — kod TEKRARINI önlemek İÇİN buraya, TEK bir ORTAK bileşene ÇIKARILDI (bkz.
  `Kod-Rehberi.md`).
- `.symbolRenderingMode(.multicolor)`: SF Symbols İKONLARININ (güneş, bulut GİBİ) KENDİ İÇİNDEKİ
  RENK bilgisini KULLANMASINI sağlıyor (düz TEK renk yerine — GÜNEŞ ikonunun SARISI, bulutun GRİSİ
  gibi doğal RENKLERİYLE çiziliyor).

---

## Kapanış

Bu dosya, kod TABANINDAKİ her Swift dosyasını (Kod-Rehberi.md HARİÇ tutularak, o AYRI bir amaca
hizmet ETTİĞİ için) satır SATIR/grup grup, KULLANILAN sözdiziminin NE anlama geldiğine kadar
AÇIKLAMAYI hedefliyor. Yeni bir DOSYA eklendiğinde ya da MEVCUT bir dosya ANLAMLI şekilde
DEĞİŞTİĞİNDE, bu dosyanın da İLGİLİ bölümünün GÜNCELLENMESİ gerekiyor — tıpkı `Kod-Rehberi.md` gibi.
