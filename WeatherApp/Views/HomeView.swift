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
    @State private var editingFavorite: FavoriteCity?

    @StateObject private var searchService = LocationSearchService()
    @Namespace private var heroNamespace

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "greeting.morning", defaultValue: "Günaydın")
        case 12..<18: return String(localized: "greeting.afternoon", defaultValue: "İyi Günler")
        case 18..<22: return String(localized: "greeting.evening", defaultValue: "İyi Akşamlar")
        default: return String(localized: "greeting.night", defaultValue: "İyi Geceler")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(colors: WeatherPalette.colors(
                    conditionCode: currentLocationWeather?.conditionCode ?? 800,
                    isNight: WeatherPalette.isCurrentlyNight
                ))
                .ignoresSafeArea()

                List {
                    if searchService.searchQuery.isEmpty {

                        Section {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(greeting)
                                    .font(.weatherCityName)
                                    .foregroundColor(.white)
                                Text(Date.now.formatted(date: .complete, time: .omitted))
                                    .font(.weatherCaption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hiddenListRow(insets: EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                        }

                        if locationManager.authorizationStatus != .denied {
                            Section {
                                locationWeatherCard
                                    .hiddenListRow(insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }
                        } else {
                            Section {
                                GlassWarningView(
                                    iconName: "location.slash",
                                    message: String(
                                        localized: "home.location_denied",
                                        defaultValue: "Konum izni kapalı.\nAyarlar'dan izin verirsen bulunduğun yerin hava durumunu buradan görebilirsin."
                                    )
                                )
                                .hiddenListRow(insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            }
                        }

                        Section {
                            if viewModel.savedCities.isEmpty {
                                GlassWarningView(
                                    iconName: "star.slash",
                                    message: String(
                                        localized: "home.favorites_empty",
                                        defaultValue: "Favori listeniz boş.\nYukarıdan arayarak yeni şehirler ekleyin."
                                    )
                                )
                                .hiddenListRow(insets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                            } else {
                                ForEach(viewModel.savedCities) { favorite in
                                    NavigationLink(destination: WeatherView(location: favorite.location, zoomNamespace: heroNamespace, zoomSourceID: favorite.name, favorites: viewModel.savedCities)) {
                                        FavoriteCityRow(
                                            favorite: favorite,
                                            snapshot: viewModel.favoriteSnapshots[favorite.name.lowercased()],
                                            unit: viewModel.preferredUnit
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .matchedTransitionSource(id: favorite.name, in: heroNamespace)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.toggleFavorite(name: favorite.name, weather: nil)
                                            }
                                        } label: {
                                            Label("Sil", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingFavorite = favorite
                                        } label: {
                                            Label("Düzenle", systemImage: "pencil")
                                        }
                                        .tint(.indigo)
                                    }
                                    .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .onMove(perform: moveFavorite)
                            }
                        } header: {
                            Text("FAVORİ ŞEHİRLER")
                                .font(.weatherSectionHeader)
                                .tracking(1.1)
                                .foregroundColor(.white.opacity(0.75))
                        }

                    } else if searchService.searchResults.isEmpty {
                        Section {
                            GlassWarningView(
                                iconName: "magnifyingglass",
                                message: String(
                                    format: String(
                                        localized: "search.no_results_format",
                                        defaultValue: "\"%@\" için sonuç bulunamadı."
                                    ),
                                    searchService.searchQuery
                                )
                            )
                            .hiddenListRow(insets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                        }
                    } else {
                        Section {
                            ForEach(searchService.searchResults, id: \.self) { result in
                                Button {
                                    Task { await selectSearchResult(result) }
                                } label: {
                                    SearchResultRow(title: result.title)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .matchedTransitionSource(id: result.title, in: heroNamespace)
                                .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        } header: {
                            Text("ÖNERİLEN ŞEHİRLER")
                                .font(.weatherSectionHeader)
                                .tracking(1.1)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .refreshable {
                    viewModel.refreshFavoriteSnapshots()
                    if let coordinate = locationManager.location {
                        currentLocationWeather = await viewModel.snapshotWeather(
                            for: .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: locationManager.displayLocationName ?? "")
                        )
                    }
                }
                .sensoryFeedback(.selection, trigger: viewModel.savedCities.count)
            }
            .navigationTitle("Nuve") // görünmüyor ama voiceover/geri buton etiketi için lazım
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandHeader()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .searchable(text: $searchService.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Şehir ara (Örn: İstanbul)")
            .onSubmit(of: .search) {
                let query = searchService.searchQuery
                Task { searchedLocation = await searchService.resolve(freeText: query) }
            }
            .navigationDestination(item: $searchedLocation) { location in
                WeatherView(location: location, zoomNamespace: heroNamespace)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showFilter) {
                WeatherFilterView(filter: $filter, unit: viewModel.preferredUnit)
            }
            .sheet(item: $editingFavorite) { favorite in
                EditFavoriteSheet(favorite: favorite) { nickname, colorName in
                    viewModel.updateFavorite(id: favorite.id, nickname: nickname, accentColorName: colorName)
                }
            }
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
                currentLocationWeather = await viewModel.snapshotWeather(
                    for: .coordinate(lat: coordinate.latitude, lon: coordinate.longitude, displayName: locationManager.displayLocationName ?? "")
                )
            }
            .onChange(of: currentLocationWeather) { _, newWeather in
                guard let newWeather else { return }
                AppIconManager.update(for: newWeather.conditionCode)
            }
        }
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) async {
        searchedLocation = await searchService.resolve(result)
    }

    private var locationWeatherCard: some View {
        NavigationLink(destination: Group {
            if let coordinate = locationManager.location {
                WeatherView(
                    location: .coordinate(
                        lat: coordinate.latitude,
                        lon: coordinate.longitude,
                        displayName: locationManager.displayLocationName ?? locationManager.apiSearchCityName ?? "Konum"
                    ),
                    zoomNamespace: heroNamespace,
                    zoomSourceID: "current-location"
                )
            } else {
                Text("Konum aranıyor...")
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Mevcut Konum")
                            .font(.weatherRowSubtitle)
                    }
                    .foregroundColor(.white.opacity(0.8))

                    if let locationName = locationManager.displayLocationName {
                        Text(locationName)
                            .font(.weatherRowTitle)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    } else if locationManager.location != nil {
                        Text("Adres Çözümleniyor...")
                            .font(.weatherRowTitle)
                            .foregroundColor(.white)
                    } else {
                        Text("Konum Yükleniyor...")
                            .font(.weatherRowTitle)
                            .foregroundColor(.white)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let weather = currentLocationWeather {
                        Image(systemName: weather.systemIconName)
                            .font(.system(size: 36))
                            .symbolRenderingMode(.multicolor)
                        Text(viewModel.preferredUnit.format(weather.temperature))
                            .font(.weatherRowTemperature)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .symbolRenderingMode(.multicolor)
                        Text("Detay için dokun")
                            .font(.weatherCaption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(20)
            .weatherGlassCard()
        }
        .matchedTransitionSource(id: "current-location", in: heroNamespace)
        .buttonStyle(PlainButtonStyle())
    }

    private func moveFavorite(from source: IndexSet, to destination: Int) {
        viewModel.savedCities.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    HomeView()
        .environmentObject(WeatherViewModel())
}
