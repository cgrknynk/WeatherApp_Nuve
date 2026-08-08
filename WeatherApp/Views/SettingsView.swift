//
//  SettingsView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - ayarlar ekranı
struct SettingsView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // hava durumu renklerini değil, kendine ait nötr bir palet
                // kullanıyor, hem okunabilirlik hem tutarlı bir görünüm için
                AmbientBackgroundView(colors: WeatherPalette.chromeColors)
                    .ignoresSafeArea()

                List {
                    Section {
                        Picker("Sıcaklık Birimi", selection: $viewModel.preferredUnit) {
                            Text("Santigrat (°C)").tag(TemperatureUnit.celsius)
                            Text("Fahrenayt (°F)").tag(TemperatureUnit.fahrenheit)
                        }
                        .tint(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .weatherGlassCard(cornerRadius: 16)
                        .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        Picker("Rüzgar Birimi", selection: $viewModel.preferredWindUnit) {
                            Text("km/s").tag(WindSpeedUnit.kilometersPerHour)
                            Text("mph").tag(WindSpeedUnit.milesPerHour)
                        }
                        .tint(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .weatherGlassCard(cornerRadius: 16)
                        .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("BİRİMLER")
                            .font(.weatherSectionHeader)
                            .tracking(1.1)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Section {
                        HStack {
                            Text("Sürüm")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .weatherGlassCard(cornerRadius: 16)
                        .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("HAKKINDA")
                            .font(.weatherSectionHeader)
                            .tracking(1.1)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WeatherViewModel())
}
