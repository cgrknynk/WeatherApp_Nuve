import SwiftUI
import Charts

// MARK: - şehir detay ekranı
// tek bir konumun hava durumunu gösteren ekran, arama sonucu, mevcut konum ve
// favoriler hepsi bu ekrana geliyor, kod tekrarı olmasın diye
//
// not: favoriler arasında kaydırarak geçebilmek için ayrı bir karusel ekranı
// yapmıştım ama kendi şerit göstergemi kaydırılabilir içeriğin üstüne sabit
// bir yere koymak bir türlü tutarlı çalışmadı, on bir farklı yöntem denedim
// hepsi bir şekilde bozuk çıktı. sonunda kaydırma fikrini tamamen bıraktım.
// favoriler artık bu ekranı arama sonucu gibi tekil açıyor, diğer favorilere
// geçiş ekranın altındaki bir şeride dokunarak oluyor (aşağıya bak)
struct WeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    let zoomNamespace: Namespace.ID
    let zoomSourceID: String

    // favoriler listesinden açıldıysa diğer favorilere dokunarak geçebilmek
    // için tüm liste burada tutuluyor. arama sonucu gibi tekil girişlerde bu
    // liste boş kalıyor, alt şerit hiç görünmüyor
    private let favorites: [FavoriteCity]

    // ekranda o an gösterilen konum, başta location parametresiyle kuruluyor,
    // kullanıcı alt şeritten başka bir favoriye dokununca değişiyor
    @State private var activeLocation: WeatherLocation
    @State private var activeName: String

    init(location: WeatherLocation, zoomNamespace: Namespace.ID, zoomSourceID: String? = nil, favorites: [FavoriteCity] = []) {
        self.zoomNamespace = zoomNamespace
        self.zoomSourceID = zoomSourceID ?? location.displayName
        self.favorites = favorites
        _activeLocation = State(initialValue: location)
        _activeName = State(initialValue: location.displayName)
    }

    private var currentWeather: CityWeather? {
        if case .success(let weather) = viewModel.state { return weather }
        return nil
    }

    // favori mi diye kontrol ederken veri gelmişse api'nin kesin ismini
    // kullanıyorum, henüz gelmediyse ekrana gelirken kullandığım ismi
    private var favoriteKey: String {
        currentWeather?.name ?? activeLocation.displayName
    }

    var body: some View {
        ZStack {
            WeatherBackground(
                conditionCodes: currentWeather?.conditionCodes ?? [800],
                isNight: currentWeather?.isNight ?? false,
                windDeg: currentWeather?.windDeg
            )
            .ignoresSafeArea()

            VStack {
                WeatherStateScaffold(state: viewModel.state, onRetry: { viewModel.fetchWeather(for: activeLocation) }) { weather in
                    WeatherContentView(
                        weather: weather,
                        hourly: viewModel.hourlyForecast,
                        daily: viewModel.dailyForecast,
                        airQuality: viewModel.airQuality,
                        unit: viewModel.preferredUnit,
                        windUnit: viewModel.preferredWindUnit,
                        lastUpdated: viewModel.lastUpdated,
                        onRefresh: { viewModel.fetchWeather(for: activeLocation) }
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if favorites.count > 1 {
                FavoriteSwitcherStrip(
                    favorites: favorites,
                    activeName: $activeName,
                    snapshots: viewModel.favoriteSnapshots,
                    unit: viewModel.preferredUnit
                )
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleFavorite(name: favoriteKey, weather: currentWeather)
                    }
                } label: {
                    // boyutu bilerek sabit tutuyorum, eskiden favoriye eklenince
                    // büyüyordu ve bu istenmeyen bir zıplama gibi görünüyordu
                    Image(systemName: viewModel.isFavorite(favoriteKey) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.selection, trigger: viewModel.isFavorite(favoriteKey))
            }

            if let weather = currentWeather {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: shareText(for: weather))
                }
            }
        }
    }

    // MARK: - paylaşım metni
    private func shareText(for weather: CityWeather) -> String {
        String(
            format: String(localized: "share.summary_format", defaultValue: "%@: %@, %@"),
            weather.name,
            viewModel.preferredUnit.format(weather.temperature),
            weather.conditionDescription.capitalized
        )
    }
}

// MARK: - favoriler arası dokunmatik geçiş şeridi
// eski karuselin yerine geçen basit yöntem: kaydırma jesti yok, bir favoriye
// dokununca o şehre geçiliyor. bu ekranda tek bir kaydırılabilir katman
// olduğu için burayı ekranın altına sabitlemek sorunsuz çalışıyor
//
// küçük bir görsel sorun daha vardı: malzemeyi düz şeride uygulayınca ekranın
// tam ucundan ucuna uzanan, köşeleri hiç yuvarlak olmayan kalın bir çubuk
// çıkıyordu. çözüm: malzemeyi yuvarlak köşeli bir şekle kırpıp, şeridi
// kenarlardan biraz içeri çekip yüzen bir hap gibi bıraktım, biraz da
// inceltip hafif şeffaflaştırdım
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
                        chip(for: favorite)
                            .id(favorite.name)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .onAppear { proxy.scrollTo(activeName, anchor: .center) }
            .onChange(of: activeName) { _, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
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

    private func chip(for favorite: FavoriteCity) -> some View {
        let isActive = favorite.name == activeName
        let snapshot = snapshots[favorite.name.lowercased()]

        return Button {
            activeName = favorite.name
        } label: {
            HStack(spacing: 6) {
                Text(favorite.name.capitalized)
                    .font(.weatherRowSubtitle)
                    .lineLimit(1)

                if let snapshot {
                    Text(unit.format(snapshot.temperature))
                        .font(.weatherRowSubtitle.bold())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.14)))
            .foregroundColor(isActive ? .black : .white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}
