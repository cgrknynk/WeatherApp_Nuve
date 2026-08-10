//
//  FilterResultsView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

struct FilterResultsView: View {
    let filter: WeatherFilter
    let unit: TemperatureUnit
    @EnvironmentObject var viewModel: WeatherViewModel

    @Namespace private var zoomNamespace

    @State private var groups: [CountryGroup] = [] // @State: gereksiz yeniden hesaplama olmasın

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
                                cityRow(city)
                            }
                        } header: {
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { recomputeGroups() }
        .onChange(of: viewModel.favoriteSnapshots) { _, _ in recomputeGroups() }
        .onChange(of: viewModel.savedCities) { _, _ in recomputeGroups() }
    }

    @ViewBuilder
    private func cityRow(_ city: FilteredCity) -> some View {
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
}

struct FilteredCity: Identifiable {
    let name: String
    let temperature: Double
    let systemIconName: String
    let country: String
    let location: WeatherLocation
    var id: String { name }
}

struct CountryGroup: Identifiable {
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
