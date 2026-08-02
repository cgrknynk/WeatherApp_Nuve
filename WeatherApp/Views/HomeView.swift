import SwiftUI
import CoreLocation
import MapKit

struct HomeView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    @Environment(\.scenePhase) var scenePhase
    
    @State private var searchedCityToNavigate: String?
    @StateObject private var locationManager = LocationManager()
    
    // Otomatik tamamlama servisimizi View'a bağladık
    @StateObject private var searchService = LocationSearchService()

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Arka Plan (GÜNCELLENDİ: Hareketli Cam Efekti)
                // WeatherView'da oluşturduğumuz animasyonlu arka planı burada da kullanıyoruz
                AmbientBackgroundView(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)])
                    .ignoresSafeArea()
                
                // MARK: - Dashboard İçeriği
                List {
                    // EĞER ARAMA ÇUBUĞU BOŞSA NORMAL EKRANI GÖSTER
                    if searchService.searchQuery.isEmpty {
                        
                        // BÖLÜM 1: Akıllı ve Tıklanabilir Konum Kartı
                        if locationManager.authorizationStatus != .denied {
                            Section {
                                locationWeatherCard
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        
                        // BÖLÜM 2: Favoriler
                        Section {
                            if viewModel.savedCities.isEmpty {
                                GlassWarningView(
                                    iconName: "star.slash",
                                    message: "Favori listeniz boş.\nYukarıdan arayarak yeni şehirler ekleyin."
                                )
                                .listRowInsets(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else {
                                ForEach(viewModel.savedCities, id: \.self) { city in
                                    NavigationLink(destination: WeatherView(cityName: city)) {
                                        Text(city.capitalized)
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .padding(.vertical, 8)
                                            .foregroundColor(.white)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.toggleFavorite(city: city)
                                            }
                                        } label: {
                                            Label("Sil", systemImage: "trash")
                                        }
                                    }
                                    // GÜNCELLENDİ: Glassmorphism uyumlu liste arka planı
                                    .listRowBackground(Color.white.opacity(0.15).background(.ultraThinMaterial))
                                }
                                .onDelete(perform: deleteCity)
                            }
                        } header: {
                            Text("Favori Şehirler")
                                .font(.title3.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                    } else {
                        // EĞER ARAMA YAPILIYORSA ÖNERİLERİ GÖSTER
                        Section {
                            ForEach(searchService.searchResults, id: \.self) { result in
                                Button {
                                    // 1. Tıklanan şehrin ismini al ve yönlendir (Örn: "İstanbul")
                                    searchedCityToNavigate = result.title
                                    // 2. Arama çubuğunu temizle ki geri gelince ana ekran görünsün
                                    searchService.searchQuery = ""
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        // Ülke veya bölge detayı varsa (Örn: "Türkiye") onu da daha silik göster
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                // GÜNCELLENDİ: Glassmorphism uyumlu arama sonuçları
                                .listRowBackground(Color.white.opacity(0.15).background(.ultraThinMaterial))
                            }
                        } header: {
                            Text("Önerilen Şehirler")
                                .font(.title3.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Hava Durumu")
            // ARAMA ÇUBUĞUNU DOĞRUDAN SERVİSE BAĞLADIK
            .searchable(text: $searchService.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Şehir ara (Örn: İstanbul)")
            .onSubmit(of: .search) {
                // Eğer kullanıcı önerilere tıklamak yerine direkt klavyeden "Ara" tuşuna basarsa:
                searchedCityToNavigate = searchService.searchQuery
                searchService.searchQuery = ""
            }
            .navigationDestination(item: $searchedCityToNavigate) { city in
                WeatherView(cityName: city)
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    locationManager.requestLocation()
                }
            }
        }
    }
    
    // MARK: - Tıklanabilir Konum Kartı Görünümü
    private var locationWeatherCard: some View {
        NavigationLink(destination: Group {
            if let apiCity = locationManager.apiSearchCityName {
                WeatherView(cityName: apiCity)
            } else {
                Text("Konum aranıyor...")
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Mevcut Konum")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.8))
                    
                    if let locationName = locationManager.displayLocationName {
                        Text(locationName)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    } else if locationManager.location != nil {
                        Text("Adres Çözümleniyor...")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    } else {
                        Text("Konum Yükleniyor...")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.multicolor)
                    
                    Text("Detay için dokun")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func deleteCity(at offsets: IndexSet) {
        let citiesToRemove = offsets.map { viewModel.savedCities[$0] }
        for city in citiesToRemove {
            withAnimation {
                viewModel.toggleFavorite(city: city)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(WeatherViewModel())
}
