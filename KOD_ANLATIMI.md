# Nuve — Kod Anlatım Dökümanı

Bu döküman, "Nuve" hava durumu uygulamasındaki her mekanizmayı satır satır,
neden öyle yazıldığını da açıklayarak anlatır. Amaç ezber değil: bir satırı
gördüğünde "bu neden burada, ne zaman çalışıyor, kim tetikliyor" sorusuna
kendi kendine cevap verebilmen.

Döküman baştan sona okunacak şekilde değil, ihtiyaç duydukça başvurulacak
şekilde yazıldı. Başlıklar sırayla: mimari → uygulamanın açılışı →
property wrapper'lar (state yönetimi) → eşzamanlılık (concurrency) →
özellik özellik uçtan uca veri akışları → görsel sistem → Info.plist ve
proje ayarları.

---

## 1. Genel mimari: MVVM kuşbakışı

Uygulama klasik bir **MVVM** (Model-View-ViewModel) düzeninde:

```
Models/        → sadece veri: struct/enum, hiç UI kodu yok
Services/      → dış dünyayla konuşan katman: ağ istekleri, konum, arama
ViewModels/    → Model'i View'ın anlayacağı hâle getiren, state tutan sınıf
Views/         → SwiftUI ekranları ve alt bileşenleri
DesignSystem/  → renk, yazı tipi, "cam kart" gibi ortak görsel dil
Utilities/     → tek başına anlamlı, view'a bağlı olmayan yardımcı kod
```

Akışın tek yönlü mantığı şöyle:

```
Kullanıcı etkileşimi (dokunma, arama, ayar değiştirme)
        │
        ▼
   View bir fonksiyon çağırır (örn. viewModel.fetchWeather(...))
        │
        ▼
ViewModel, Service'i çağırır (örn. service.fetchWeather(at:))
        │
        ▼
   Service, ağdan veri çeker, Model'e (struct) dönüştürür
        │
        ▼
ViewModel, sonucu @Published bir property'ye yazar
        │
        ▼
SwiftUI, o property'yi okuyan her View'ı otomatik olarak yeniden çizer
```

Bu tek yönlü döngü projenin can damarı. Aşağıdaki her bölüm, bu döngünün
farklı bir parçasını büyüteç altına alıyor.

---

## 2. Uygulamanın açılışı: `WeatherAppApp.swift`

```swift
import SwiftUI

@main
struct WeatherAppApp: App {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark) // uygulama hep koyu modda kalsın
        }
    }
}
```

Satır satır:

- **`@main`** — Swift'e "programın giriş noktası burası" der. Normalde bir
  `main.swift` dosyası ya da `main()` fonksiyonu gerekir; `@main` bunun
  yerine geçen bir attribute'tur, tam bu `struct`'ın `main()`'ini
  derleyicinin otomatik ürettiğini söyler.
- **`App` protokolü** — SwiftUI'de bir uygulamanın kök noktası bu
  protokole uyar. Tek zorunlu gereksinimi `body: some Scene` içermek.
- **`@StateObject private var viewModel = WeatherViewModel()`** —
  Uygulama boyunca **tek bir** `WeatherViewModel` örneği yaratılıyor ve bu
  örnek, `WeatherAppApp` struct'ı kaç kere yeniden değerlendirilirse
  değerlendirilsin **yeniden yaratılmıyor**. `@StateObject` tam olarak bunu
  garanti eder: "bu nesnenin sahibi benim, yaşam döngüsünü ben yönetiyorum,
  view yeniden çizilse bile nesneyi tekrar `init` etme." (`@ObservedObject`
  olsaydı, her yeniden çizimde nesne resetlenebilirdi — burada istemediğimiz
  şey tam olarak bu.)
- **`WindowGroup`** — Scene protokolüne uyan, uygulamanın pencere(ler)ini
  tanımlayan yapı taşı. iPhone'da tek pencere olur.
- **`.environmentObject(viewModel)`** — `viewModel`'i, bu view'ın **altındaki
  bütün view ağacına** enjekte eder. `HomeView`, `WeatherView`,
  `SettingsView`, `WeatherFilterView`, `FilterResultsView`... hepsi
  `@EnvironmentObject var viewModel: WeatherViewModel` yazarak bu **aynı**
  nesneye ulaşır. Prop olarak elden ele taşımaya (`WeatherViewModel`'i her
  view'ın init'ine parametre olarak geçirmeye) gerek kalmaz.
- **`.preferredColorScheme(.dark)`** — Bugün geri eklediğimiz satır. iOS,
  sistem genelinde açık/koyu tema arasında geçiş yapabilir; bu modifier o
  sistem tercihini **görmezden gelip** bu view ağacını (yani tüm
  uygulamayı) her zaman koyu temada zorlar. Uygulamanın tüm renk paleti
  (`WeatherPalette`, beyaz metinler, camsı kartlar) zaten koyu arka plan
  varsayımıyla tasarlandığı için, kullanıcı telefonunu açık temaya alsa
  bile okunaklılık bozulmasın diye bilinçli olarak sabitlenmiş. Bu
  modifier'ı `HomeView()`'dan **sonra** çağırmak önemli değil aslında — asıl
  önemlisi `WindowGroup` içindeki kök view'a uygulanmış olması; alt
  view'lardan biri kendi üzerine ayrıca `.preferredColorScheme(.light)`
  koysa o alt ağaç için override edebilirdi (burada hiçbir yerde
  yapılmıyor, dolayısıyla uygulamanın tamamı koyu kalıyor).

---

## 3. Property wrapper'lar: hangisi ne zaman kullanılıyor

SwiftUI'de state yönetimi neredeyse tamamen "hangi wrapper'ı, hangi
katmanda kullanıyorsun" sorusuna iniyor. Bu projede kullanılanlar:

### `@State` — view'a **özel**, kısa ömürlü veri

```swift
// WeatherContentView.swift
@State private var showCityFact = false

// HomeView.swift
@State private var showSettings = false
@State private var editingFavorite: FavoriteCity?
```

`@State`, bir `struct View`'ın içinde normalde mümkün olmayan bir şeyi
mümkün kılar: **değişebilen** veri. View'lar struct olduğu için her
yeniden çizimde teknik olarak yeniden yaratılırlar; `@State` ile işaretli
değişkenler ise SwiftUI tarafından view'ın dışında, ayrı bir depoda
tutulur ve view yeniden yaratılsa da değerini korur. Kural: **sadece o
view'ı ve varsa çocuklarını ilgilendiren, dışarıdan kimsenin bilmesine
gerek olmayan veri** için kullanılır. `showCityFact` iyi bir örnek: "bu
sheet açık mı" bilgisini sadece `WeatherContentView` bilmek zorunda.

### `@Binding` — bir `@State`'in **referansını** başka bir view'a taşımak

```swift
// WeatherFilterView.swift
@Binding var filter: WeatherFilter

// WeatherView.swift (FavoriteSwitcherStrip içinde)
@Binding var activeName: String
```

`HomeView`'daki `@State private var filter = WeatherFilter()` gerçek
sahip; `WeatherFilterView(filter: $filter, ...)` çağrısındaki `$` işareti
"bunun sahibi ben değilim, sadece oku/yaz erişimi ver" demek. Alt view
`filter.categories.insert(...)` yazdığında, aslında üstteki `@State`
değişiyor — SwiftUI bunu otomatik senkronize eder.

### `@StateObject` vs `@ObservedObject` vs `@EnvironmentObject`

Üçü de `ObservableObject`'e erişim sağlar, farkları **sahiplik**:

| Wrapper | Kim yaratıyor / yaşatıyor | Bu projede |
|---|---|---|
| `@StateObject` | Bu view (view yeniden çizilse bile nesne yaşar) | `WeatherAppApp.viewModel`, `HomeView.locationManager`, `HomeView.searchService` |
| `@ObservedObject` | Dışarıdan geliyor, sahiplik bu view'da değil | (bu projede kullanılmıyor — çünkü ihtiyaç olan her yerde ya `@StateObject` ile üretiliyor ya da `@EnvironmentObject` ile enjekte ediliyor) |
| `@EnvironmentObject` | Üst view ağacından `.environmentObject(...)` ile geliyor | `SettingsView`, `HomeView`, `WeatherView`, `WeatherFilterView`, `FilterResultsView`'daki `viewModel` |

`HomeView` içindeki şu satıra dikkat:

```swift
@EnvironmentObject var viewModel: WeatherViewModel
@StateObject private var locationManager = LocationManager()
@StateObject private var searchService = LocationSearchService()
```

`viewModel` her yerde aynı örnek olmalı (favoriler, birim tercihi gibi
**paylaşılan** state) → `@EnvironmentObject`. `locationManager` ve
`searchService` ise sadece `HomeView`'a özel, başka hiçbir view'ın
bilmesine gerek olmayan nesneler → `@StateObject` ile burada doğrudan
yaratılıyorlar.

### `@Published` — bir sınıfın hangi property'si değişince view yeniden çizilsin

```swift
// WeatherViewModel.swift
@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var state: WeatherViewState = .idle
    @Published var savedCities: [FavoriteCity] = [] {
        didSet { persistSavedCities() }
    }
    @Published var preferredUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(preferredUnit.rawValue, forKey: "PreferredUnitKey") }
    }
    ...
}
```

`ObservableObject` protokolüne uyan bir sınıfın `@Published` işaretli her
property'si değiştiğinde, sınıf otomatik olarak `objectWillChange`
sinyali yayınlar. Bu sınıfı `@EnvironmentObject`/`@StateObject` ile
**okuyan** her view, bu sinyali dinler ve kendini yeniden çizer. Yani
`viewModel.preferredUnit = .fahrenheit` satırı çalıştığı an, bu değeri
okuyan **her** view (ayarlar ekranındaki Picker, hava durumu ekranındaki
sıcaklık yazısı, favori listesindeki her satır) tek bir atamayla otomatik
güncellenir — elle "reload" çağırmaya gerek yok.

`private(set)` kısmı önemli: `state`'i sadece `WeatherViewModel`'in
kendisi değiştirebilir, dışarıdan (view'dan) sadece okunabilir. Bu, "kimin
neyi değiştirebileceği" sınırını tip sisteminin kendisine yazdırmak —
yorum yazmaya gerek kalmıyor.

`didSet` ile birleşince ortaya çok kullanışlı bir desen çıkıyor: **"değer
değişti → hem view'ları güncelle (Published'in işi) hem de kalıcı hâle
getir (didSet'in işi)."** Bunu Bölüm 5 ve 6'da uçtan uca izleyeceğiz.

### `@MainActor` — "bu kod her zaman ana iş parçacığında çalışsın"

```swift
@MainActor
final class WeatherViewModel: ObservableObject { ... }

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate { ... }
```

SwiftUI, UI güncellemelerinin **ana thread'de** yapılmasını zorunlu tutar;
başka bir thread'den `@Published` bir değeri değiştirmek çökmeye ya da
görsel tutarsızlıklara yol açabilir. `@MainActor` bir sınıfın **tamamını**
ana actor'e (pratikte ana thread'e) sabitler: bu sınıfın herhangi bir
metodunu çağırmak istersen, ya zaten ana thread'de olman ya da `await` ile
ana thread'e geçiş yapman gerekir. Derleyici bunu **derleme zamanında**
kontrol eder — "ana thread'de değilsin" hatasını çalışma zamanını
beklemeden yakalarsın.

### `nonisolated` — "bu, actor izolasyonunun dışında kalsın"

```swift
nonisolated protocol WeatherServiceProtocol: Sendable { ... }
nonisolated struct WeatherService: WeatherServiceProtocol { ... }
nonisolated struct WikipediaFactService { ... }
```

`WeatherViewModel` `@MainActor` ama içindeki `service: any WeatherServiceProtocol`
ağ isteği atarken ana thread'i **bloklamamalı**. `nonisolated` işaretli bir
tip, hiçbir actor'e bağlı değildir — herhangi bir thread'den güvenle
çağrılabilir. `Sendable` ise "bu tipin bir kopyası, thread'ler arasında
güvenle taşınabilir" garantisi (struct olduğu ve içinde sadece value type
tuttuğu için `WeatherService` bunu otomatik/kolayca sağlıyor). Kısacası:
ViewModel ana thread'e kilitli, Service katmanı hiçbir thread'e kilitli
değil — ağ isteği arka planda dönerken UI donmuyor.

### `@Environment` — sistemin/ortamın sana verdiği hazır değerler

```swift
@Environment(\.dismiss) private var dismiss
@Environment(\.scenePhase) var scenePhase
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

`\.dismiss`, bir sheet/NavigationStack içinde "beni kapat" fonksiyonunu
sana verir (`SettingsView`, `CityFactSheet`, `EditFavoriteSheet` hep bunu
kullanır). `\.scenePhase`, uygulamanın `.active`/`.inactive`/`.background`
durumunu izlemeni sağlar — `HomeView` bunu, kullanıcı uygulamaya geri
döndüğünde konum iznini ve favori anlık görüntülerini tazelemek için
kullanıyor (Bölüm 8'de detay var). `\.accessibilityReduceMotion`,
kullanıcı Ayarlar > Erişilebilirlik'ten "Hareketi Azalt"ı açtıysa
`true` döner; parçacık animasyonları (yağmur, kar, ışık titremesi) bu
durumda durdurulur.

### `@Namespace` — hero/zoom geçişleri için ortak kimlik alanı

```swift
// HomeView.swift
@Namespace private var heroNamespace
```

Bölüm 12'de ayrıntılı işleniyor.

---

## 4. Eşzamanlılık (concurrency): `async/await`, `Task`, iptal

### Önce çok basit bir örnekle: `Task` tam olarak nedir?

`Task { ... }`, Swift'e "şu bloğun içindekini **arka planda başlat, ama
sonucunu bana bir değişken gibi ver**" demenin yolu. Bir benzetme: garsona
sipariş verirsin, garson mutfağa gider, sen bu arada masanda oturmaya
devam edersin (uygulamanın geri kalanı donmaz); yemek hazır olunca garson
sana getirir. `Task { ... }` bloğu işte bu "garson" — kendi başına, ana
akışı bloklamadan çalışan bir iş parçası başlatıyor.

En basit hâliyle projede şöyle kullanılıyor:

```swift
fetchTask = Task {
    let bundle = try await service.fetchWeather(at: location)
    state = .success(weather)
}
```

- `Task { ... }` — yeni bir arka plan işi **başlatır** ve bu işin
  "tutamacını" (handle) geri döndürür. Bu tutamaç `fetchTask` değişkenine
  atanıyor — böylece bu işi daha sonra "iptal et" (`fetchTask?.cancel()`)
  diyerek durdurabiliyoruz. Bir `Task`, bir kâğıda yazılmış "bu işi ben
  başlattım, takip numaram şu" fişi gibi düşünülebilir.
- `await` — "burada bir bekleme var, ama bekleme sırasında ana thread'i
  **bloklamıyorum**" demek. `service.fetchWeather(at:)` internet
  üzerinden veri çekiyor, bu birkaç yüz milisaniye sürebilir; `await` o
  süre boyunca uygulamanın geri kalanının (animasyonlar, dokunma
  tepkileri) çalışmaya devam etmesine izin veriyor. `await`'in olduğu
  satırdan sonrası, veri **gerçekten geldiğinde** çalışır — sanki kod
  duraklayıp bekliyormuş gibi okunur ama aslında thread boşta kalmıyor.
- `try` — `fetchWeather(at:)` `throws` işaretli bir fonksiyon, yani hata
  fırlatabilir (internet yoksa, sunucu hata dönerse). `try` bunu kabul
  ettiğini, hata olursa `catch` bloğuna düşeceğini söylüyor.
- Sonuç: `Task` bloğunun **içinde**, sanki senkron (adım adım, bekleyerek)
  yazılmış gibi okunan ama aslında arka planda çalışan bir kod var. Bu,
  Swift'in eski "completion handler" (`fetchWeather { result in ... }`
  şeklinde, iç içe geçmiş kapanışlarla dolu) tarzına göre çok daha
  okunabilir bir yöntem.

Şimdi bunun projedeki tam hâlini görelim:

`WeatherViewModel.fetchWeather(for:)` bu projenin en yoğun concurrency
örneği:

```swift
func fetchWeather(for location: WeatherLocation) {
    fetchTask?.cancel() // eski isteğin cevabı yeni ekranın üzerine yazmasın

    state = .loading
    hourlyForecast = []
    dailyForecast = []
    airQuality = nil

    fetchTask = Task {
        do {
            let bundle = try await service.fetchWeather(at: location)
            guard !Task.isCancelled else { return }

            let weather = location.applying(to: bundle.current)
            hourlyForecast = bundle.hourly
            dailyForecast = bundle.daily
            state = .success(weather)
            lastUpdated = .now

            recordFreshSnapshot(weather)
            airQuality = try? await service.fetchAirQuality(lat: weather.lat, lon: weather.lon)
        } catch is CancellationError {
            // iptal edilen isteğin hatası gösterilmez
        } catch {
            guard !Task.isCancelled else { return }
            state = .error((error as? WeatherError)?.errorDescription ?? "Beklenmedik bir hata oluştu.")
        }
    }
}
```

Neden bu kadar dikkatli iptal yönetimi var? Çünkü kullanıcı hızlıca iki
farklı şehre art arda dokunursa (örn. arama sonucundan birine, sonra
geri gidip başka birine), **iki ayrı ağ isteği** aynı anda uçuşabilir.
Birinci istek geç cevap verirse, ekranda artık ikinci şehir gösterilirken
birinci şehrin verisiyle üzerine yazabilir. Bunu önlemek için:

1. Yeni bir `fetchWeather` çağrısı gelir gelmez, `fetchTask?.cancel()` ile
   **önceki** Task'a iptal sinyali gönderilir.
2. `service.fetchWeather(at:)` bir `await` noktası olduğu için, Swift
   iptal edilen Task'ları burada otomatik olarak `CancellationError`
   fırlatacak şekilde keser.
3. Cevap yine de gelirse (iptal sinyali ile ağ isteğinin bitmesi arasında
   yarış olabilir), `guard !Task.isCancelled else { return }` ekstra bir
   güvenlik ağı: "ben zaten geçersiz kılındıysam, state'i güncelleme."

`try?` kullanılan `airQuality = try? await service.fetchAirQuality(...)`
satırı bilinçli bir tercih: hava kalitesi verisi **opsiyonel** bir ek
bilgi, gelmezse tüm ekranı hataya düşürmenin bir anlamı yok — sessizce
`nil` kalması yeterli.

`LocationManager` içinde ise farklı bir desen var:

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    ...
    DispatchQueue.main.async {
        self.location = newLocation.coordinate
        ...
    }
    Task {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(newLocation)
        ...
        await MainActor.run { self.displayLocationName = ... }
    }
}
```

`CLLocationManagerDelegate` metotları Apple'ın eski (Swift concurrency
öncesi) API'sinden geldiği için **hangi thread'den çağrılacağı garanti
değil**. Sınıf `@MainActor` olsa da, delegate metodu senkron olarak
protokolden geldiği için derleyici burada otomatik atlama yapamıyor; bu
yüzden elle `DispatchQueue.main.async` / `await MainActor.run` ile ana
thread'e geçiş **açıkça** yazılmış. Bu, projede "eski (delegate tabanlı)
API ile yeni (async/await tabanlı) API'nin aynı sınıfta bir arada
yaşaması" örneği.

---

## 5. "Ayarlara basınca ne oluyor?" — uçtan uca

1. Kullanıcı `HomeView`'ın sağ üst köşesindeki dişli ikonuna dokunur.
2. `HomeView.swift`'te bu butonun `action`'ı çalışır: `showSettings = true`.
   Bu bir `@State` — sadece `HomeView`'ın kendi bildiği bir bayrak.
3. `HomeView`'ın body'sinde `.sheet(isPresented: $showSettings) { SettingsView() }`
   modifier'ı bu değişikliği **dinliyor**; `showSettings` `true` olur olmaz
   SwiftUI `SettingsView()`'ı bir sheet (alttan açılan panel) olarak
   ekrana yerleştirir.
4. `SettingsView`'ın içinde `@EnvironmentObject var viewModel: WeatherViewModel`
   var — `HomeView`'a `WeatherAppApp` tarafından enjekte edilen **aynı**
   nesne, sheet'e de otomatik miras kalır (environment, view ağacında
   aşağı doğru akar).
5. Kullanıcı "Sıcaklık Birimi" Picker'ından "Fahrenayt"a dokunur:
   `Picker("Sıcaklık Birimi", selection: $viewModel.preferredUnit)` —
   burada `$viewModel.preferredUnit` bir **binding**; Picker seçimi
   değiştiğinde doğrudan `viewModel.preferredUnit = .fahrenheit` atamasını
   tetikler.
6. Bu atama, `@Published var preferredUnit: TemperatureUnit { didSet { ... } }`
   tanımına girer. İki şey **aynı anda** olur:
   - `@Published` sayesinde `viewModel`'i izleyen her view (o an açık olan
     `WeatherView`, arka planda bekleyen `HomeView`'daki favori
     satırları) bir sonraki ekran döngüsünde yeniden çizilir ve artık
     `unit.format(...)` çağrıları Fahrenayt formatını üretir.
   - `didSet` bloğu çalışır: `UserDefaults.standard.set(preferredUnit.rawValue, forKey: "PreferredUnitKey")`
     — tercih diske yazılır, uygulama kapanıp açılsa bile hatırlanır.
7. Kullanıcı "Kapat"a basar → `dismiss()` (`\.dismiss` environment değeri)
   çağrılır, sheet kapanır. `showSettings` otomatik olarak `false`'a
   döner (SwiftUI'nin sheet yönetiminin bir parçası).

Bu zincirde dikkat edilecek nokta: **hiçbir yerde elle "ekranı
yenile" kodu yok.** Tek atama (`$viewModel.preferredUnit`'e binding
üzerinden yazmak), hem kalıcılığı hem de tüm ekranların güncellenmesini
otomatik tetikliyor. Bu, `@Published` + `didSet` ikilisinin gücü.

Rüzgar birimi Picker'ı da birebir aynı mekanizmayı `preferredWindUnit`
üzerinden çalıştırıyor.

---

## 6. Şehir arama akışı

1. `HomeView`'daki `.searchable(text: $searchService.searchQuery, ...)`
   modifier'ı, navigasyon çubuğunun altına bir arama kutusu ekler ve
   kullanıcının yazdığı her karakteri `searchService.searchQuery`'ye
   bağlar.
2. `LocationSearchService.swift`:
   ```swift
   @Published var searchQuery = "" {
       didSet { searchCompleter.queryFragment = searchQuery }
   }
   ```
   Her karakter değişiminde, Apple'ın `MKLocalSearchCompleter`'ına
   (klavye yazarken anlık öneri üreten MapKit bileşeni) yeni sorgu
   iletilir.
3. `MKLocalSearchCompleter`, kendi arka plan işini bitirince
   `completerDidUpdateResults(_:)` delegate metodunu çağırır; bu metot
   `searchResults`'ı (yine `@Published`) günceller.
4. `HomeView`'ın `List`'i `searchService.searchResults`'ı dinlediği için,
   öneriler ekranda anlık olarak belirir (`SearchResultRow` ile).
5. Kullanıcı bir sonuca dokununca `selectSearchResult(_:)` çağrılır →
   `searchService.resolve(result)` → bu, seçilen serbest metni **gerçek
   bir koordinata** çevirir (`geocode(text:fallbackName:)`).
6. Elde edilen `WeatherLocation` (`.coordinate(lat:lon:displayName:)`),
   `searchedLocation` state'ine yazılır; `.navigationDestination(item: $searchedLocation)`
   bunu görünce otomatik olarak `WeatherView`'a **push** eder.

**Bugün düzelttiğimiz kısım tam burada:** `geocode(text:fallbackName:)`
eskiden iOS 26'ya özel `MKGeocodingRequest` kullanıyordu; iOS 18'de
uygulama bu satırda derlenmiyordu. Şimdi iOS 18'den beri değişmeden var
olan `MKLocalSearch` üzerinden çalışıyor (Bölüm 10'da detay var) — böylece
tek bir kod yolu hem iOS 18 hem iOS 26'da çalışıyor, `#available` dallanmasına
bile gerek kalmadı.

---

## 7. Favoriler ve kalıcılık

```swift
@Published var savedCities: [FavoriteCity] = [] {
    didSet { persistSavedCities() }
}
@Published private(set) var favoriteSnapshots: [String: CityWeather] = [:] {
    didSet { persistFavoriteSnapshots() }
}
```

İki ayrı `@Published` değişken var, çünkü ikisinin ömrü farklı:

- `savedCities`: kullanıcının **hangi şehirleri** favorilediği — küçük,
  nadiren değişen bir liste (`FavoriteCity`: isim, opsiyonel koordinat,
  takma isim, kart rengi).
- `favoriteSnapshots`: her favorinin **en son bilinen hava durumu** —
  `HomeView` her açıldığında/öne geldiğinde tazelenen, çok daha "geçici"
  bir önbellek (`[şehirAdıKüçükHarf: CityWeather]`).

`toggleFavorite(name:weather:)`:

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
```

`WeatherView`'daki yıldız butonuna basınca bu çağrılır. Her iki `@Published`
değişkenin de `didSet`'i tetiklenir → `persistSavedCities()` ve
`persistFavoriteSnapshots()` çalışır → `JSONEncoder().encode(...)` ile
`UserDefaults`'a yazılır. Uygulama yeniden açıldığında `WeatherViewModel.init`
içindeki `Self.loadSavedCities()` / `Self.loadFavoriteSnapshots()` bu
veriyi geri okur.

`loadSavedCities()`'teki şu satıra dikkat:

```swift
// eski formatta düz isim listesi varsa koordinatsız favoriye çevirir
private static func loadSavedCities() -> [FavoriteCity] {
    if let data = ..., let decoded = try? JSONDecoder().decode([FavoriteCity].self, from: data) {
        return decoded
    }
    let legacyNames = UserDefaults.standard.stringArray(forKey: "SavedCitiesKey") ?? []
    return legacyNames.map { FavoriteCity(name: $0, lat: nil, lon: nil) }
}
```

Bu, **geriye dönük uyumluluk** örneği: uygulamanın daha eski bir
sürümünde favoriler düz `[String]` olarak saklanıyordu; `FavoriteCity`
struct'ına geçilince, eski kullanıcıların verisi kaybolmasın diye önce
yeni formatı dener, olmazsa eski formatı okuyup dönüştürür.

---

## 8. Hava durumu çekme: networking katmanı

`WeatherService.swift`, **iki farklı API'yi** birleştiriyor ve bunun
nedeni kodun içinde açık:

```swift
// openweather: konum. open-meteo: hava durumu sayıları
nonisolated struct WeatherService: WeatherServiceProtocol { ... }
```

- **OpenWeather** (`api.openweathermap.org`) sadece "bu isimdeki/bu
  koordinattaki yer neresi, hangi ülkede, tam koordinatı ne" bilgisini
  vermek için kullanılıyor (`fetchLocationIdentity`). Bunun için bir API
  anahtarı gerekiyor (`Secrets.swift`).
- **Open-Meteo** (`api.open-meteo.com`) ise anahtar gerektirmeyen,
  ücretsiz bir API; asıl sıcaklık/nem/rüzgar/7 günlük tahmin gibi
  **sayısal** veriyi buradan çekiyor.

Neden ayrı? Çünkü OpenWeather'ın ücretsiz katmanı bazı alanlarda (saatlik/
günlük tahmin detayı, dakikalık yağış) Open-Meteo kadar zengin değil;
proje ikisinin güçlü yanlarını birleştiriyor: OpenWeather'dan **kimlik**,
Open-Meteo'dan **sayı**.

`WeatherServiceProtocol`'un varlığı da bilinçli bir tasarım kararı:

```swift
nonisolated protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for cityName: String) async throws -> WeatherBundle
    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherBundle
    func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQuality
}
```

`WeatherViewModel`, somut `WeatherService` struct'ına değil, bu
**protokole** bağımlı (`private let service: any WeatherServiceProtocol`).
Bu, **dependency injection** deseni: testlerde gerçek ağ isteği atmayan
sahte (mock) bir servis geçirilebilir, `WeatherViewModel`'in kendisi hiç
değişmeden. `init(service: any WeatherServiceProtocol = WeatherService())`
satırındaki varsayılan değer sayesinde günlük kullanımda hiçbir şey
değişmiyor, ama test edilebilirlik kapısı açık kalıyor.

`private nonisolated struct OpenMeteoResponse: Codable { ... }` gibi ham
API cevabı struct'ları neden `private`? Çünkü bunlar **sadece bu dosyanın
iç detayı** — API'nin JSON şeklini bire bir yansıtıyorlar (`temperature_2m`,
`weather_code` gibi Swift'e göre garip isimlendirmeler bile bilerek
korunmuş, çünkü `Codable` otomatik decode için JSON anahtarıyla Swift
property adının birebir eşleşmesi gerekiyor). Uygulamanın geri kalanı bu
ham şekli hiç görmemeli; onun yerine temiz bir `CityWeather` struct'ına
dönüştürülüp öyle sunuluyor (`fetchWeather(identity:)` metodunun sonundaki
`CityWeather(...)` çağrısı bu dönüşümü yapıyor).

`WMOWeatherCode.legacyConditionCode(for:)` neden var? Open-Meteo, hava
durumunu [WMO kod standardına](https://open-meteo.com/en/docs) göre
(`0` = açık, `61` = hafif yağmur...) veriyor. Ama uygulamanın **geri
kalanı** (ikonlar, renk paletleri, "en iyi gün" skorlaması, filtre
kategorileri) hep OpenWeather'ın eski `2xx`/`3xx`/`5xx`/`8xx` aralık
sistemine göre yazılmış. Bu fonksiyon, WMO kodunu o eski aralık sistemine
**çeviren bir köprü** — böylece tek bir "hava kodu dili" ile tüm
uygulama konuşuyor, iki API'nin farklı sözlüğü hiçbir yerde sızmıyor.

---

## 9. `CityWeather` modeli: computed property'lerin gücü

`CityWeather` sadece ham veri tutmuyor; `outfitSuggestion`,
`sunsetQualityScore`, `dewPoint`, `humidityComfortLabel` gibi bir sürü
**computed property** (hesaplanan özellik) barındırıyor:

```swift
var outfitSuggestion: String {
    var parts: [String] = []
    switch feelsLike {
    case ..<0: parts.append("kalın mont, bere ve eldiven şart")
    ...
    }
    ...
}
```

Bunların hepsi **saf fonksiyon** mantığıyla yazılmış: sadece `self`'in
diğer alanlarını okuyor, hiçbir yan etkisi (network isteği, state
değişikliği) yok. Bu bilinçli bir tercih — `CityWeather` bir `struct` ve
`Codable`/`Equatable`; bu computed property'ler her erişimde yeniden
hesaplanır ama maliyetleri ihmal edilebilir düzeyde (birkaç `switch`,
birkaç aritmetik işlem). View katmanı (`WeatherContentView`,
`WeatherDetailBox` vs.) bu hazır etiketleri doğrudan gösteriyor, kendi
içinde hiç iş mantığı taşımıyor — "View sadece gösterir, karar Model'de
verilir" ilkesinin somut hâli.

---

## 10. Konum servisleri ve iOS 18 uyumluluğu

Bugünkü düzeltmelerin en teknik kısmı burası, o yüzden ayrıntılı
anlatıyorum.

### Neden bozulmuştu?

Projenin `IPHONEOS_DEPLOYMENT_TARGET`'ı (uygulamanın çalışabileceği en
düşük iOS sürümü) `26.0`/`26.5`'e ayarlıydı ve kod, MapKit'in **sadece
iOS 26'da** var olan yeni adres API'lerini kullanıyordu:

- `MKReverseGeocodingRequest` (koordinattan adrese)
- `MKGeocodingRequest` (metinden koordinata)
- `MKMapItem.address` / `.addressRepresentations` (yeni `MKAddress` tipi)
- `MKMapItem.location` (eski `.placemark.coordinate`'in yeni karşılığı)

Deployment target'ı `18.0`'a indirince, derleyici bu satırlarda "sadece
iOS 26'da var" hatası verdi (`xcodebuild` ile gerçek bir derleme
yapılarak doğrulandı). Çözüm, bu API'lerin **iOS 18'den beri değişmeden
var olan** eşdeğerlerini kullanmaktı — iki ayrı kod yolu (`#available`
dallanması) yazmaya bile gerek kalmadı, çünkü eski API'ler iOS 26'da da
hâlâ çalışıyor (sadece "deprecated" — kullanımdan kaldırılmaya aday
işaretli, ama tamamen kullanılabilir).

### `LocationManager.swift` — tersine geocode

**Öncesi (sadece iOS 26):**
```swift
guard let request = MKReverseGeocodingRequest(location: newLocation) else { return }
let fetchedMapItems = try await request.mapItems
if let mapItem = fetchedMapItems.first, let address = mapItem.address {
    let locationString = address.shortAddress ?? ""
    ...
}
```

**Şimdi (iOS 18 ve üzeri):**
```swift
let placemarks = try await CLGeocoder().reverseGeocodeLocation(newLocation)
guard let placemark = placemarks.first else { return }
let locationString = [placemark.locality, placemark.administrativeArea]
    .compactMap { $0 }
    .joined(separator: ", ")
await MainActor.run {
    self.displayLocationName = locationString.isEmpty ? "Konum Bulunamadı" : locationString
    self.apiSearchCityName = placemark.locality ?? locationString
}
```

`CLGeocoder`, CoreLocation'ın çok eski (iOS 5'ten beri var) ama hâlâ
çalışan tersine-geocode aracı. `CLPlacemark.locality` doğrudan "şehir
adı" alanı — eski koddaki "virgülle ayırıp son parçayı al" gibi kırılgan
bir metin ayrıştırma hilesine artık gerek kalmadı, çünkü `locality` zaten
tam olarak istediğimiz veriyi temiz biçimde veriyor.

### `LocationSearchService.swift` — metinden koordinata geocode

**Öncesi (sadece iOS 26):**
```swift
guard let request = MKGeocodingRequest(addressString: text) else { return .name(fallbackName) }
guard let mapItems = try? await request.mapItems, !mapItems.isEmpty else { return .name(fallbackName) }
let mapItem = mapItems.first { [item.name, item.addressRepresentations?.cityName]... } ?? mapItems[0]
let coordinate = mapItem.location.coordinate
```

**Şimdi (iOS 18 ve üzeri):**
```swift
let request = MKLocalSearch.Request()
request.naturalLanguageQuery = text
request.resultTypes = .address
guard let response = try? await MKLocalSearch(request: request).start(),
      !response.mapItems.isEmpty else { return .name(fallbackName) }
let mapItem = response.mapItems.first { [item.name, item.placemark.locality]... } ?? response.mapItems[0]
let coordinate = mapItem.placemark.coordinate
```

`MKLocalSearch`, MapKit'in çok daha eski (iOS 6.1'den beri var) genel
arama aracı; `MKLocalSearch.Request` ile serbest metin sorgusu
gönderiliyor, sonuçlar `MKMapItem` dizisi olarak dönüyor — tek fark, yeni
`address`/`location` yerine klasik `placemark` (bir `CLPlacemark`)
üzerinden `.coordinate` ve `.locality` okunuyor. Kullanıcının arama
kutusuna yazdığı isim (`fallbackName`) ile gelen sonuçlar arasında en
uygununu bulma mantığı (`.folding(...)` ile büyük/küçük harf ve Türkçe
aksan farklarını yok sayarak karşılaştırma) birebir korundu.

### Deployment target neden 18.0

`project.pbxproj` içindeki `IPHONEOS_DEPLOYMENT_TARGET` build ayarı,
uygulamanın **en düşük** çalışacağı iOS sürümünü belirler. `26.0`/`26.5`
iken uygulama sadece en yeni cihazlarda/simülatörlerde açılabiliyordu;
`18.0`'a indirilerek çok daha geniş bir cihaz/kullanıcı kitlesine
ulaşılabilir hâle getirildi. Bu satırın hem `Debug` hem `Release`
konfigürasyonunda (proje seviyesinde ve hedef seviyesinde, toplam dört
yerde) güncellenmesi gerekiyordu — Xcode projeleri bu ayarı birden fazla
yerde tutabiliyor, biri unutulursa örneğin Debug derlemesi 18'de çalışıp
Release derlemesi çalışmayabilirdi.

---

## 11. Wikipedia "İlginç Bilgi" özelliği

Bu, bugün yanlışlıkla silinip geri yüklenen ikinci özellik. İki dosyadan
oluşuyor:

### `WikipediaFactService.swift`

```swift
nonisolated struct WikipediaFactService {
    func fetchFact(cityName: String, countryName: String?) async -> CityFact? {
        if let fact = await fetchSummary(title: cityName, language: "tr") { return fact }
        if let fact = await fetchSummary(title: cityName, language: "en") { return fact }
        if let countryName, !countryName.isEmpty {
            if let fact = await fetchSummary(title: countryName, language: "tr") { return fact }
        }
        return nil
    }
    ...
}
```

Wikipedia'nın **anahtar/kayıt gerektirmeyen** ücretsiz REST API'sini
kullanıyor: `https://{dil}.wikipedia.org/api/rest_v1/page/summary/{başlık}`.
Bu uç nokta, bir sayfanın kısa özetini (ilk paragraf) ve varsa küçük bir
kapak görselini döndürür. Sırasıyla:

1. Önce şehir adıyla **Türkçe** Wikipedia'da dener.
2. Bulamazsa (küçük yerleşimlerin çoğu Türkçe Wikipedia'da yazılmamış
   olabiliyor) **İngilizce** Wikipedia'yı dener.
3. O da yoksa, **ülke adıyla** Türkçe Wikipedia'yı dener (en azından ülke
   hakkında bir bilgi gösterilsin diye).
4. Hiçbiri olmazsa `nil` döner — bu `throws` değil, **optional dönen bir
   fonksiyon**; çünkü "bulunamadı" burada bir hata değil, beklenen ve
   normal bir sonuç. `CityFactSheet` bunu `.notFound` durumuna çevirip
   nazik bir mesaj gösteriyor.

`decoded.type != "disambiguation"` satırı ince ama önemli bir detay:
Wikipedia'da "Efes" gibi birden fazla anlama gelebilecek başlıklar
"anlam ayrım sayfası" (disambiguation) olarak işaretlenir — bu sayfanın
özeti anlamsız olurdu ("Efes şunlara atıfta bulunabilir: ..."), o yüzden
bilerek eleniyor.

### `CityFactSheet.swift`

```swift
private enum FactLoadState {
    case loading
    case found(CityFact)
    case notFound
}

struct CityFactSheet: View {
    let cityName: String
    let countryName: String
    @State private var state: FactLoadState = .loading
    private let service = WikipediaFactService()

    var body: some View {
        NavigationStack { ... }
        .task {
            let fact = await service.fetchFact(cityName: cityName, countryName: countryName)
            state = fact.map(FactLoadState.found) ?? .notFound
        }
    }
}
```

`.task { }` modifier'ı, bu view ekrana **ilk geldiğinde bir kere**
çalışan asenkron bir blok tanımlar (view kaybolursa Task otomatik iptal
edilir — `fetchTask?.cancel()` gibi elle bir şey yapmaya gerek yok, SwiftUI
bunu view'ın yaşam döngüsüyle otomatik eşliyor). `FactLoadState` enum'ı,
"henüz cevap gelmedi / bulundu / bulunamadı" üç hâli **tip güvenli**
biçimde modelliyor; `switch state { ... }` her hâli ayrı ayrı, unutmadan
ele almayı derleyici seviyesinde zorunlu kılıyor.

Bağlanma noktası, `WeatherContentView.swift`'in en altında:

```swift
.overlay(alignment: .topTrailing) {
    cityFactButton
}
.sheet(isPresented: $showCityFact) {
    CityFactSheet(cityName: weather.name, countryName: weather.localizedCountryName)
}
```

`cityFactButton`, ekranın sağ üst köşesinde sabit duran (kaydırma
sırasında yerinden oynamayan — çünkü `overlay`, `ScrollView`'ın kendi
çerçevesine bağlı, içeriğine değil) sarı ampul ikonlu bir düğme. Ona
basınca `showCityFact = true` olur, `.sheet` bunu görüp `CityFactSheet`'i
açar. **Bugün asıl bozuk olan tam buradaydı**: dosyalar silinince, bu
`.sheet` satırı da bir şekilde kaybolmuştu — düğme vardı ama basınca hiçbir
şey açılmıyordu. Şimdi her ikisi de yerinde.

---

## 12. Liquid Glass (iOS 26) ve iOS 18 geri uyumluluğu

iOS 26 ile Apple, "Liquid Glass" adı verilen yeni bir görsel dil getirdi:
`.glassEffect(...)` modifier'ı ve `GlassEffectContainer` view'ı,
arka planı gerçekçi biçimde kıran/yansıtan camsı bir yüzey efekti
üretiyor; `.buttonStyle(.glassProminent)` da aynı dilin buton varyantı.
Bunların hepsi **sadece iOS 26 ve üzerinde** mevcut — iOS 18-25 çalışan bir
cihazda bu API'ler derleme zamanında hata verir.

Uygulamanın görsel kimliği ("cam kart" görünümü) bu efekte epey bağımlı
olduğu için, çözüm şu oldu: **her Liquid Glass çağrısını, eski sürümlerde
görsel olarak çok benzer bir alternatife düşen bir sarmalayıcının
arkasına gizlemek.** Bunun merkezi `DesignSystem/GlassCard.swift`:

```swift
private struct GlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.16)), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .background(.black.opacity(0.16), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
```

`#available(iOS 26.0, *)` bir **çalışma zamanı** kontrolü değil, aslında
**derleme zamanı + çalışma zamanı** birleşimi bir yapı: derleyici, `if`
bloğunun içindeki iOS-26-özel çağrının sadece o dal içinde
kullanılmasına izin verir (dışarıda kullansan hata verirdi); çalışma
zamanında ise cihazın gerçek iOS sürümüne bakıp doğru dalı çalıştırır.
`else` dalında kullanılan `.ultraThinMaterial`, iOS 15'ten beri var olan,
bulanık-cam benzeri klasik bir SwiftUI materyali — Liquid Glass kadar
gerçekçi kırılma efekti vermez ama aynı "buzlu cam" hissini iOS 18'de de
makul bir şekilde taklit ediyor.

Aynı desen, `View` extension'ı olarak iki yerde daha tekrarlanıyor:

```swift
@ViewBuilder
func weatherProminentButtonStyle() -> some View {
    if #available(iOS 26.0, *) { self.buttonStyle(.glassProminent) }
    else { self.buttonStyle(.borderedProminent) }
}

@ViewBuilder
func weatherGlassEffectContainer() -> some View {
    if #available(iOS 26.0, *) { GlassEffectContainer { self } }
    else { self }
}
```

- `weatherProminentButtonStyle()`: `WeatherStateScaffold`'daki "Tekrar
  Dene" ve `WeatherFilterView`'daki "Uygula" butonları bunu kullanıyor.
  iOS 26'da camsı, öne çıkan bir buton; altında ise sistemin klasik
  "belirgin, dolgulu" buton stili (`.borderedProminent`) — işlevsel
  olarak birebir aynı, görsel olarak en yakın karşılık.
- `weatherGlassEffectContainer()`: `WeatherContentView`'daki detay
  kutuları ızgarasını (`detailsGrid`) sarmalıyor. `GlassEffectContainer`,
  içindeki birden çok cam yüzeyin birbirine **görsel olarak** yumuşak
  geçiş yapmasını sağlayan bir performans/görsel optimizasyonu; iOS
  18'de bu container'ın kendisi yok, ama içindeki `WeatherDetailBox`'lar
  zaten kendi `weatherGlassCard()`'ları ile ayrı ayrı `.ultraThinMaterial`
  kullandığı için container olmadan da düzgün görünüyorlar — bu yüzden
  `else` dalında hiçbir şey yapmadan `self`'i (içeriği olduğu gibi)
  döndürmek yeterli.

Neden bu üç fonksiyon tek tek `#available` yazmak yerine `GlassCard.swift`'te
merkezîleştirildi? Çünkü aynı `if #available` bloğunu 10'dan fazla view
dosyasına tekrar tekrar yazmak hem hataya açık (birini unutabilirsin) hem
de "iOS 26 fallback mantığı" değişirse (örneğin Apple yeni bir API
getirirse) tek bir yerden güncellenebilmesi gerekiyor — bu üç extension,
projenin **tek** Liquid-Glass-uyumluluk noktası.

---

## 13. Navigasyon ve hero/zoom geçişleri

```swift
// HomeView.swift
@Namespace private var heroNamespace
...
NavigationLink(destination: WeatherView(location: favorite.location, zoomNamespace: heroNamespace, zoomSourceID: favorite.name, favorites: viewModel.savedCities)) {
    FavoriteCityRow(...)
}
.matchedTransitionSource(id: favorite.name, in: heroNamespace)
```

```swift
// WeatherView.swift
.navigationTransition(.zoom(sourceID: zoomSourceID, in: zoomNamespace))
```

`@Namespace`, birbiriyle "eşleşecek" iki view'a **ortak bir kimlik alanı**
tanımlar (SwiftUI içeride bunu bir `Namespace.ID` değeriyle takip eder).
`matchedTransitionSource(id:in:)`, "buraya dokunulursa, geçiş bu view'dan
başlasın" der; hedef ekrandaki `.navigationTransition(.zoom(sourceID:in:))`
ise "ben, aynı `id`'ye sahip kaynaktan **büyüyerek** açılayım" der. Sonuç:
favori satırına dokunduğunda, o satır kartı gerçekten büyüyüp tam ekran
hava durumu sayfasına dönüşüyormuş gibi bir geçiş animasyonu oluyor (Apple
Fotoğraflar/App Store'daki "zoom" geçişlerine benzer). Bu, iOS 18 ile
gelen bir SwiftUI özelliği — deployment target'ı 18'e indirirken bu API'lerin
**dokunulmaması** gerektiğini, sadece Liquid Glass API'lerinin
sorun çıkardığını yukarıdaki `xcodebuild` hatalarından teyit ettik.

`sheet(isPresented:)` ile `sheet(item:)` arasındaki fark da projede iki
örnekle görülüyor:

```swift
.sheet(isPresented: $showSettings) { SettingsView() }              // basit açık/kapalı bayrak
.sheet(item: $editingFavorite) { favorite in EditFavoriteSheet(favorite: favorite, ...) }  // hangi veriyle açılacağını da taşıyor
```

`sheet(item:)`, `editingFavorite: FavoriteCity?` gibi **opsiyonel bir
veri** üzerinden çalışır: değer `nil` değilse sheet açılır ve içine
otomatik olarak o değer (`favorite`) geçirilir; `nil` olursa sheet kapanır.
Böylece "hangi favoriyi düzenliyorum" bilgisini ayrıca bir `@State`'e
taşımaya gerek kalmıyor — tek bir opsiyonel değişken hem "açık mı" hem
"hangi veriyle" sorularını birden cevaplıyor.

---

## 14. Görsel efektler: `TimelineView`, `Canvas`, `Charts`

### `TimelineView` — zamana bağlı, otomatik yenilenen görünümler

```swift
TimelineView(.everyMinute) { timeline in
    Text(localTimeText(timeline.date))
}
```

Normal bir `Text(Date.now...)` sadece view yeniden çizildiğinde
güncellenir; SwiftUI kendiliğinden "her dakika yeniden çiz" demez. `TimelineView(.everyMinute)`
tam olarak bunu sağlıyor: SwiftUI'ye periyodik olarak (burada dakikada
bir) yeni bir `timeline.date` ile içeriği yeniden değerlendirmesini
söylüyor. Şehir saatinin (`localTimeText`), arka plandaki parçacık
animasyonlarının (`WeatherParticleLayer`, `.animation(minimumInterval: 1/30)`
ile saniyede ~30 kare) ve saatlik grafikteki "şu an" çizgisinin hepsi bu
mekanizmayla canlı kalıyor.

### `Canvas` — düşük seviyeli, performanslı çizim

`WeatherBackground.swift`'teki yağmur/kar/yıldız/sis efektleri
(`WeatherParticleLayer`) SwiftUI view'ları (`Circle()`, `Rectangle()`)
yerine `Canvas` kullanıyor:

```swift
Canvas { context, size in
    let elapsed = ...
    draw(in: &context, size: size, elapsed: elapsed)
}
```

`Canvas`, her "damla"yı ayrı bir `View` olarak yaratmak yerine, doğrudan
bir grafik bağlamına (`GraphicsContext`) çizim komutları (`context.stroke`,
`context.fill`) gönderir. 70 yağmur damlası için 70 ayrı SwiftUI view
yaratmak performans açısından pahalı olurdu; `Canvas` ile bunların hepsi
**tek bir çizim geçişinde** işleniyor. `ParticleSeed` struct'ı (rastgele
`x`, `hız`, `faz`, `derinlik` değerleri) her parçacığın "kimliğini" sabit
tutuyor; zamanla değişen tek şey `elapsed` (geçen süre) — bu yüzden
animasyon pürüzsüz ve öngörülebilir.

### `Charts` — saatlik sıcaklık grafiği

```swift
Chart {
    ForEach(...) { index, forecast in
        AreaMark(x: .value("Saat", forecast.time), y: .value("Sıcaklık", forecast.temperature))
        LineMark(x: .value("Saat", forecast.time), y: .value("Sıcaklık", forecast.temperature))
        if index % 3 == 0 { PointMark(...) }
    }
    RuleMark(x: .value("Şu An", timeline.date))
}
```

Apple'ın `Charts` çerçevesi (iOS 16+), veriyi "mark"lar (`AreaMark`,
`LineMark`, `PointMark`, `RuleMark`) olarak tanımlamanı ister; sen hangi
değerin x/y eksenine karşılık geldiğini söylersin, ölçekleme/eksen
çizimi framework'ün işi. `index % 3 == 0` ile her 3 saatte bir nokta ve
etiket gösterilmesi bilinçli bir okunabilirlik kararı — 24 saatin hepsine
etiket koysaydı grafik okunmaz hâle gelirdi. `RuleMark`, "şu an" dikey
çizgisini `TimelineView`'dan gelen canlı `timeline.date` ile çiziyor —
grafik dakikada bir kendini kaydırıyormuş hissi bu ikilinin birleşiminden
geliyor.

---

## 15. Uygulama ikonu değişimi

```swift
enum AppIconManager {
    private static func iconName(for conditionCode: Int) -> String? {
        switch conditionCode {
        case 200...232, 300...321, 500...531: return "AppIcon-Rainy"
        case 600...622: return "AppIcon-Snowy"
        case 701...781, 803...804: return "AppIcon-Cloudy"
        default: return nil
        }
    }
    @MainActor
    static func update(for conditionCode: Int) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let target = iconName(for: conditionCode)
        guard UIApplication.shared.alternateIconName != target else { return }
        UIApplication.shared.setAlternateIconName(target, completionHandler: nil)
    }
}
```

`HomeView`'da tetiklenme noktası:

```swift
.onChange(of: currentLocationWeather) { _, newWeather in
    guard let newWeather else { return }
    AppIconManager.update(for: newWeather.conditionCode)
}
```

Kullanıcının **bulunduğu konumun** hava durumu her güncellendiğinde
(`currentLocationWeather` değiştiğinde), uygulama ikonu o havaya uygun
alternatif bir ikona (yağmurlu/karlı/bulutlu) otomatik geçiyor; hiçbiri
uymuyorsa (`default: return nil`) standart ikona dönüyor. `alternateIconName != target`
kontrolü gereksiz sistem çağrısını (ve bununla gelen küçük bir dock
"zıplama" animasyonunu) önlüyor — zaten o ikondaysak tekrar aynı isteği
göndermiyoruz.

Bu alternatif ikonların **hangi dosya isimlerine karşılık geldiği**
`SupplementalInfo.plist`'te (Bölüm 17'de detay var) `CFBundleAlternateIcons`
altında tanımlı — kod tarafında sadece string bir isim (`"AppIcon-Rainy"`)
geçiriliyor, gerçek görsel dosya eşlemesi proje ayarlarının işi.

---

## 16. Yerelleştirme (Localization)

Projede sabit Türkçe metinler yerine neredeyse her yerde şu desen var:

```swift
String(localized: "weather.high_format", defaultValue: "Y:%@")
```

`"weather.high_format"` bir **anahtar**; `defaultValue`, o anahtar için
henüz çeviri yoksa (ya da geliştirme sırasında) kullanılacak metin.
Gerçek çeviriler `Localizable.xcstrings` dosyasında tutuluyor — Xcode'un
görsel string-catalog editörüyle düzenlenen, JSON tabanlı bir dosya. Bu
yaklaşımın faydası: ileride İngilizce (ya da başka bir dil) desteği
eklenmek istendiğinde, kod tarafında **tek bir satır değişmeden**, sadece
`Localizable.xcstrings`'e yeni bir dil sütunu eklemek yeterli olacak.
`String(format:)` ile birlikte kullanılan yerlerde (`"%@"`, `"%d"`) sayı/
metin yer tutucuları da dil bağımsız kalıyor.

---

## 17. Info.plist ve proje ayarları (`project.pbxproj`)

Bu projede **elle düzenlenen klasik bir `Info.plist` dosyası yok** —
modern Xcode projelerinde bu artık build ayarlarından **otomatik
üretiliyor**. `project.pbxproj` içindeki ilgili anahtarlar:

```
GENERATE_INFOPLIST_FILE = YES;
INFOPLIST_FILE = SupplementalInfo.plist;
INFOPLIST_KEY_CFBundleDisplayName = Nuve;
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Size en yakın şehrin hava durumunu gösterebilmek için konum izninize ihtiyacımız var.";
INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
INFOPLIST_KEY_UILaunchScreen_Generation = YES;
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
PRODUCT_BUNDLE_IDENTIFIER = cagrikaanyanik.Nuve;
SWIFT_VERSION = 5.0;
TARGETED_DEVICE_FAMILY = "1,2";
IPHONEOS_DEPLOYMENT_TARGET = 18.0;
```

Bunların her biri neye karşılık geliyor:

- **`GENERATE_INFOPLIST_FILE = YES`** — Xcode'a "bana elle bir
  `Info.plist` dosyası gösterme, derleme sırasında bu build ayarlarından
  kendin üret" der. Eski projelerde gördüğün fiziksel `Info.plist`
  dosyası burada yok; onun yerine her anahtar bir `INFOPLIST_KEY_*` build
  ayarı olarak `project.pbxproj`'un içinde yaşıyor.
- **`INFOPLIST_FILE = SupplementalInfo.plist`** — Bazı Info.plist
  anahtarlarının (örn. `CFBundleAlternateIcons`) karşılığı yok; bu
  anahtar, otomatik üretilen plist'in üzerine **ek olarak** birleştirilecek
  (merge edilecek) ham bir plist dosyası gösteriyor. `SupplementalInfo.plist`
  içeriği:
  ```xml
  <key>CFBundleIcons</key>
  <dict>
      <key>CFBundleAlternateIcons</key>
      <dict>
          <key>AppIcon-Rainy</key>  <dict>...</dict>
          <key>AppIcon-Cloudy</key> <dict>...</dict>
          <key>AppIcon-Snowy</key>  <dict>...</dict>
      </dict>
  </dict>
  ```
  Bu, Bölüm 15'teki `AppIconManager`'ın `setAlternateIconName("AppIcon-Rainy", ...)`
  çağrısının **çalışabilmesi için önkoşul** — sistem, bu isimde bir
  alternatif ikonun var olduğunu buradan öğreniyor.
- **`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`** — iOS, bir
  uygulamanın konum izni isteyebilmesi için, kullanıcıya **neden**
  istediğini açıklayan bir metnin Info.plist'te bulunmasını **zorunlu**
  kılar; yoksa `CLLocationManager.requestWhenInUseAuthorization()` çağrısı
  sessizce reddedilir, hatta uygulama App Store incelemesinden geçmez.
  Bu metin, `HomeView.onAppear { locationManager.requestLocation() }`
  çağrıldığında kullanıcıya gösterilen izin diyaloğunun altındaki
  açıklama cümlesi.
- **`INFOPLIST_KEY_CFBundleDisplayName = Nuve`** — Ana ekrandaki ikonun
  altında görünen isim; kod içinde `BrandHeader.swift`'teki `Text("Nuve")`
  ile görsel olarak da tekrarlanıyor (biri sistem seviyesinde, biri
  uygulama içi marka başlığı).
- **`PRODUCT_BUNDLE_IDENTIFIER = cagrikaanyanik.Nuve`** — Uygulamanın
  App Store/sistem genelinde **benzersiz kimliği**. Bu üç proje kopyasının
  (WeatherApp, weatherview_guncel, WeatherApp_Guncel) hepsinde **aynı**
  olması bilerek — hepsi aynı uygulamanın farklı çalışma kopyaları.
- **`IPHONEOS_DEPLOYMENT_TARGET = 18.0`** — Bölüm 10'da detaylandırılan,
  bugün `26.5`/`26.0`'dan indirilen minimum iOS sürümü.
- **`TARGETED_DEVICE_FAMILY = "1,2"`** — `1` iPhone, `2` iPad demek;
  uygulama her iki aile için de derleniyor (arayüz kısıtlaması olmadığı
  sürece iPad'de de büyütülmüş halde çalışabilir).
- **`SWIFT_VERSION = 5.0`** — Kullanılan Swift dil sürümü (Swift 6'nın
  daha katı concurrency kontrollerinden bilerek kaçınılmış; nitekim
  `LocationManager` içindeki `CLLocationManagerDelegate` uyumu ile ilgili
  "Swift 6'da hata olur" uyarısını daha önce Bölüm 4'te gördük).

### `PBXFileSystemSynchronizedRootGroup` — neden yeni dosya eklemek "projeye eklemek" gerektirmiyor

Eski Xcode projelerinde, diske yeni bir `.swift` dosyası koymak yetmezdi;
o dosyayı ayrıca `project.pbxproj`'a **elle referans olarak eklemen**
gerekirdi (Xcode'un "Add Files to Project" diyaloğu tam olarak bunu
yapardı). Bu proje ise `project.pbxproj`'da şu satırı içeriyor:

```
isa = PBXFileSystemSynchronizedRootGroup;
```

Bu, Xcode 16 ile gelen daha yeni bir proje formatı: belirtilen klasör
(`WeatherApp/`) **dosya sistemiyle otomatik senkronize**. Yani bugün
`WikipediaFactService.swift` ve `CityFactSheet.swift` dosyalarını sadece
doğru klasöre yazmak, onları derleme hedefine dahil etmek için **yeterliydi**
— `project.pbxproj`'u elle değiştirmemize hiç gerek kalmadı. Bunu, bu
dosyaları oluşturduktan hemen sonra `xcodebuild` ile gerçek bir derleme
yaparak da doğruladık (derleme çıktısında bu dosyaların derlendiğini
gördük).

---

## 18. Bugün yapılan değişikliklerin özeti

1. **`WikipediaFactService.swift`** (Services/) geri yüklendi — Wikipedia
   REST API'sinden şehir/ülke özeti çeken servis.
2. **`CityFactSheet.swift`** (Views/Components/) geri yüklendi — bu
   veriyi yükleniyor/bulundu/bulunamadı üç hâliyle gösteren sheet.
3. **`WeatherContentView.swift`**'teki `.sheet(isPresented: $showCityFact)`
   bağlantısı yeniden kuruldu — düğme artık gerçekten bir şey açıyor.
4. **`WeatherAppApp.swift`**'e `.preferredColorScheme(.dark)` eklendi —
   uygulama artık sistem temasından bağımsız, her zaman koyu modda.
5. **iOS 18 uyumluluğu**: `IPHONEOS_DEPLOYMENT_TARGET` `26.x`'ten
   `18.0`'a indirildi; bunun için:
   - `GlassCard.swift`'e `#available(iOS 26.0, *)` dallanmalı üç yardımcı
     (`weatherGlassCard`, `weatherProminentButtonStyle`,
     `weatherGlassEffectContainer`) eklendi, tüm cam-efekt kullanım
     noktaları bunlara yönlendirildi.
   - `LocationManager.swift`'teki tersine geocode, `MKReverseGeocodingRequest`
     yerine `CLGeocoder`'a geçirildi.
   - `LocationSearchService.swift`'teki ileri geocode, `MKGeocodingRequest`
     yerine `MKLocalSearch`'e geçirildi.
   - Değişiklikler gerçek bir `xcodebuild ... -destination 'generic/platform=iOS Simulator'`
     derlemesiyle doğrulandı (**BUILD SUCCEEDED**).
6. Bu değişikliklerin hepsi, projenin üç kopyası arasında (`WeatherApp`,
   `weatherview_guncel`, `WeatherApp_Guncel`) birebir aynı hale getirildi;
   git geçmişi olan `WeatherApp` klasöründen `origin/main`'e pushlandı.
