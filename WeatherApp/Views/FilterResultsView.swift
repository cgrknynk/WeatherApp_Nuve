//
//  FilterResultsView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - filtreye uyan şehirlerin ülkeye göre listesi
// "uygula"ya basınca açılan sonuç ekranı. elimde tüm dünyayı tarayan ücretsiz
// bir servis olmadığı için sadece favori şehirleri filtreleyip ülkelerine
// göre grupluyorum.
//
// eskiden ülkeye dokununca ayrı bir ekrana geçip oradaki şehirleri
// gösteriyordum, bu gereksiz bir adımdı. şimdi tek liste var, ülke sadece
// bir başlık, altındaki şehirlere direkt dokunulabiliyor
struct FilterResultsView: View {
    let filter: WeatherFilter
    let unit: TemperatureUnit
    @EnvironmentObject var viewModel: WeatherViewModel

    @Namespace private var zoomNamespace

    // burada bir hata vardı: groups eskiden düz bir computed property'ydi,
    // yani body her çağrıldığında yeniden hesaplanıyordu. bu ekranla hiç
    // ilgisi olmayan bir veri değişse bile (paylaşılan viewModel yüzünden)
    // body tekrar çalışıyordu. arka plandaki sürekli dönen animasyon açıkken
    // bu sık tekrarlanan yeniden hesaplama, listenin yavaşça yukarı aşağı
    // kayıyormuş gibi görünmesine sebep oluyordu. çözüm: sonucu bir kere
    // hesaplayıp saklamak, sadece gerçekten gerektiğinde yeniden hesaplamak
    @State private var groups: [CountryGroup] = []

    private func recomputeGroups() {
        let matches: [FilteredCity] = viewModel.savedCities.compactMap { favorite in
            guard let weather = viewModel.favoriteSnapshots[favorite.name.lowercased()],
                  filter.matches(weather) else { return nil }
            return FilteredCity(
                name: favorite.name,
                temperature: weather.temperature,
                systemIconName: weather.systemIconName,
                country: weather.localizedCountryName,
                location: favorite.location
            )
        }

        let grouped = Dictionary(grouping: matches, by: \.country)
        groups = grouped
            .map { country, cities in CountryGroup(country: country, cities: cities.sorted { $0.name < $1.name }) }
            .sorted { $0.country < $1.country }
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView(colors: WeatherPalette.chromeColors)
                .ignoresSafeArea()

            if groups.isEmpty {
                GlassWarningView(
                    iconName: "line.3.horizontal.decrease.circle",
                    message: String(
                        localized: "home.filter_no_matches",
                        defaultValue: "Filtreye uyan şehir yok.\nFiltreyi değiştirmeyi dene."
                    )
                )
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.cities) { city in
                                NavigationLink(destination: WeatherView(location: city.location, zoomNamespace: zoomNamespace)) {
                                    CityWeatherRow(
                                        name: city.name,
                                        temperature: city.temperature,
                                        systemIconName: city.systemIconName,
                                        unit: unit
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .matchedTransitionSource(id: city.name, in: zoomNamespace)
                                .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        } header: {
                            // ülke adı artık sadece bir başlık, dokunulabilir bir satır değil
                            Text(group.country)
                                .font(.weatherSectionHeader)
                                .tracking(1.1)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .foregroundColor(.white)
        .navigationTitle("Sonuçlar")
        .navigationBarTitleDisplayMode(.inline)
        // gezinme çubuğu bazen ilk karede kendi varsayılan rengini gösterip
        // hemen ardından koyu temaya geçiyordu, bu bir titreme gibi
        // görünüyordu. burayı açıkça koyu moda sabitleyince düzeldi
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { recomputeGroups() }
        .onChange(of: viewModel.favoriteSnapshots) { _, _ in recomputeGroups() }
        .onChange(of: viewModel.savedCities) { _, _ in recomputeGroups() }
    }
}

// MARK: - filtre sonucu modelleri
// sadece ekranda göstermek için gereken bilgiyi tutuyorum, tüm CityWeather'ı değil
struct FilteredCity: Identifiable, Hashable {
    let name: String
    let temperature: Double
    let systemIconName: String
    let country: String
    let location: WeatherLocation
    var id: String { name }
}

struct CountryGroup: Identifiable, Hashable {
    let country: String
    let cities: [FilteredCity]
    var id: String { country }
}

#Preview {
    NavigationStack {
        FilterResultsView(filter: WeatherFilter(), unit: .celsius)
            .environmentObject(WeatherViewModel())
    }
}
