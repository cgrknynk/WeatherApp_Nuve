import SwiftUI
import UIKit

// tek bir konumun hava durumu ekranı; arama sonucu, mevcut konum, favoriler hepsi buraya gelir
struct WeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    let zoomNamespace: Namespace.ID
    let zoomSourceID: String

    private let favorites: [FavoriteCity]

    @State private var activeLocation: WeatherLocation
    @State private var activeName: String
    @State private var shareImage: Image?

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

    private var favoriteKey: String {
        currentWeather?.name ?? activeLocation.displayName
    }

    var body: some View {
        ZStack {
            WeatherBackground(
                conditionCode: currentWeather?.conditionCode ?? 800,
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
        .onChange(of: currentWeather) { _, newWeather in
            guard let newWeather else { return }
            shareImage = renderShareImage(for: newWeather)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleFavorite(name: favoriteKey, weather: currentWeather)
                    }
                } label: {
                    Image(systemName: viewModel.isFavorite(favoriteKey) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.selection, trigger: viewModel.isFavorite(favoriteKey))
            }

            if let weather = currentWeather {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let shareImage {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview(weather.name, image: shareImage)
                        )
                    } else {
                        ShareLink(item: shareText(for: weather))
                    }
                }
            }
        }
    }

    private func shareText(for weather: CityWeather) -> String {
        String(
            format: String(localized: "share.summary_format", defaultValue: "%@: %@, %@"),
            weather.name,
            viewModel.preferredUnit.format(weather.temperature),
            weather.conditionDescription.capitalized
        )
    }

    @MainActor
    private func renderShareImage(for weather: CityWeather) -> Image? {
        let renderer = ImageRenderer(content: ShareableWeatherCard(weather: weather, unit: viewModel.preferredUnit))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// favoriler arası dokunmatik geçiş şeridi (eski kaydırmalı karuselin yerine)
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
