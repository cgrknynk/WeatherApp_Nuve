//
//  WeatherFilterView.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - favori listesini filtreleme sayfası
// hava durumu türüne ve sıcaklık aralığına göre favori şehirleri filtrelemeyi
// sağlıyor. sıcaklık hep celsius saklanıyor, kaydırıcılar kullanıcının
// tercih ettiği birime göre anlık çevriliyor. "uygula"ya basmadan hiçbir şey
// değişmiyor, bu ekran sadece bir taslak düzenliyor, sonuçlar ayrı bir
// ekranda gösteriliyor
struct WeatherFilterView: View {
    @Binding var filter: WeatherFilter
    let unit: TemperatureUnit
    @Environment(\.dismiss) private var dismiss

    @State private var showResults = false

    private var bounds: ClosedRange<Double> {
        unit == .celsius ? -30...50 : -22...122
    }

    private var minBinding: Binding<Double> {
        Binding(
            get: { displayValue(filter.minTemperatureCelsius) },
            set: { filter.minTemperatureCelsius = min(celsiusValue($0), filter.maxTemperatureCelsius) }
        )
    }

    private var maxBinding: Binding<Double> {
        Binding(
            get: { displayValue(filter.maxTemperatureCelsius) },
            set: { filter.maxTemperatureCelsius = max(celsiusValue($0), filter.minTemperatureCelsius) }
        )
    }

    private func displayValue(_ celsius: Double) -> Double {
        unit == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    private func celsiusValue(_ displayed: Double) -> Double {
        unit == .celsius ? displayed : (displayed - 32) * 5 / 9
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(colors: WeatherPalette.chromeColors)
                    .ignoresSafeArea()

                List {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
                            ForEach(WeatherConditionCategory.allCases) { category in
                                ConditionChip(category: category, isSelected: filter.categories.contains(category)) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if filter.categories.contains(category) {
                                            filter.categories.remove(category)
                                        } else {
                                            filter.categories.insert(category)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .hiddenListRow()
                    } header: {
                        Text("HAVA DURUMU")
                            .font(.weatherSectionHeader)
                            .tracking(1.1)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("En Az")
                                    Spacer()
                                    Text(unit.format(filter.minTemperatureCelsius))
                                        .font(.weatherTemperatureSmall)
                                }
                                Slider(value: minBinding, in: bounds, step: 1)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("En Çok")
                                    Spacer()
                                    Text(unit.format(filter.maxTemperatureCelsius))
                                        .font(.weatherTemperatureSmall)
                                }
                                Slider(value: maxBinding, in: bounds, step: 1)
                            }
                        }
                        .tint(.white)
                        .foregroundColor(.white)
                        .padding()
                        .weatherGlassCard(cornerRadius: 16)
                        .hiddenListRow(insets: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } header: {
                        Text("SICAKLIK ARALIĞI")
                            .font(.weatherSectionHeader)
                            .tracking(1.1)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Section {
                        Button {
                            showResults = true
                        } label: {
                            Text("Uygula")
                                .font(.weatherRowTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .hiddenListRow()
                        .padding(.vertical, 6)
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                if filter.isActive {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Temizle") {
                            withAnimation { filter = WeatherFilter() }
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showResults) {
                FilterResultsView(filter: filter, unit: unit)
            }
        }
    }
}

// MARK: - hava durumu seçim çipi
// eskiden bir fonksiyondu, ayrı bir View yaptım ki her çipin seçili olup
// olmadığı kesin olarak kendi isSelected değerinden gelsin, birbirine
// karışma ihtimali kalmasın. seçiliyken dolgun beyaz arka plan + siyah yazı
// + onay işareti kullanıyorum, eskiden aradaki fark çok az belliydi
private struct ConditionChip: View {
    let category: WeatherConditionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.label)
                    .font(.weatherRowSubtitle)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .black : .white)
        .background(isSelected ? Color.white : Color.white.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(.white.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
        )
        // çipin tüm alanı (yazının etrafındaki boşluk dahil) dokunulabilir
        // olsun diye, GlassCard'daki aynı düzeltmenin notuna bak
        .contentShape(Capsule())
    }
}

#Preview {
    WeatherFilterView(filter: .constant(WeatherFilter()), unit: .celsius)
        .environmentObject(WeatherViewModel())
}
