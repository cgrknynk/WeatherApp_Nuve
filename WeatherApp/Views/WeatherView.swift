import SwiftUI
import Charts

struct WeatherView: View {
    @EnvironmentObject var viewModel: WeatherViewModel
    let cityName: String

    var bgColors: [Color] {
        if case .success(let weather) = viewModel.state {
            return weather.backgroundColors
        }
        return [Color.blue.opacity(0.8), Color.indigo.opacity(0.7)]
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView(colors: bgColors)
                .ignoresSafeArea()

            VStack {
                switch viewModel.state {
                case .idle, .loading:
                    Spacer()
                    ProgressView().scaleEffect(1.5).tint(.white)
                    Spacer()
                    
                case .success(let weather):
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            
                            // 1. ÜST KISIM: Ana Bilgiler
                            VStack(spacing: 0) {
                                Text(weather.name)
                                    .font(.system(size: 34, weight: .regular))
                                    .foregroundColor(.white)
                                    .padding(.top, 40)
                               
                                Text("\(Int(weather.temperature))°")
                                    .font(.system(size: 96, weight: .thin))
                                    .foregroundColor(.white)
                                    .padding(.leading, 15)
                               
                                Text(weather.conditionDescription.capitalized)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .opacity(0.9)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            Spacer().frame(height: 30)
                            
                            // 2. ORTA KISIM: 24 Saatlik Grafik
                            if !viewModel.hourlyForecast.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "clock")
                                        Text("24 SAATLİK TAHMİN")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 5)
                                    
                                    Chart {
                                        ForEach(viewModel.hourlyForecast) { forecast in
                                            AreaMark(
                                                x: .value("Saat", forecast.time),
                                                y: .value("Sıcaklık", forecast.temperature)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                                            )
                                            
                                            LineMark(
                                                x: .value("Saat", forecast.time),
                                                y: .value("Sıcaklık", forecast.temperature)
                                            )
                                            .foregroundStyle(.white)
                                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                            
                                            PointMark(
                                                x: .value("Saat", forecast.time),
                                                y: .value("Sıcaklık", forecast.temperature)
                                            )
                                            .foregroundStyle(.white)
                                            .annotation(position: .top) {
                                                Text("\(Int(forecast.temperature))°")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .frame(height: 120)
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                                            AxisValueLabel(format: .dateTime.hour())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .chartYAxis(.hidden)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer().frame(height: 20)
                            
                            // 3. YENİ: 5 Günlük Tahmin Listesi (Apple Tarzı Cam Tasarım)
                            if !viewModel.dailyForecast.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text("5 GÜNLÜK HAVA DURUMU")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 5)
                                    
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.dailyForecast) { day in
                                            HStack {
                                                // Gün İsmi (Örn: Pazartesi veya Bugün)
                                                Text(day.date.formatted(.dateTime.weekday(.wide)))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 100, alignment: .leading)
                                                
                                                Spacer()
                                                
                                                // Hava Durumu İkonu
                                                Image(systemName: day.systemIconName)
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .symbolRenderingMode(.multicolor)
                                                
                                                Spacer()
                                                
                                                // Min / Max Sıcaklık Değerleri
                                                HStack(spacing: 12) {
                                                    Text("\(Int(day.minTemperature))°")
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .fontWeight(.medium)
                                                    
                                                    // Şık min-max aralık çubuğu temsili
                                                    Capsule()
                                                        .fill(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
                                                        .frame(width: 60, height: 4)
                                                    
                                                    Text("\(Int(day.maxTemperature))°")
                                                        .foregroundColor(.white)
                                                        .fontWeight(.bold)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            Spacer().frame(height: 20)
                            
                            // 4. ALT KISIM: Zenginleştirilmiş Detay Izgarası (Nem, Rüzgar, Basınç vb.)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                WeatherDetailBox(icon: "humidity", title: "NEM", value: "%\(weather.humidity)")
                                WeatherDetailBox(icon: "wind", title: "RÜZGAR", value: "\(Int(weather.windSpeed)) km/s")
                                
                                WeatherDetailBox(icon: "thermometer.sun", title: "HİSSEDİLEN", value: "\(Int(weather.feelsLike))°")
                                WeatherDetailBox(icon: "barometer", title: "BASINÇ", value: "\(weather.pressure) hPa")
                                
                                WeatherDetailBox(icon: "eye", title: "GÖRÜŞ", value: "\(weather.visibility / 1000) km")
                                WeatherDetailBox(icon: "cloud", title: "BULUTLULUK", value: "%\(weather.cloudiness)")
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                    
                case .error(let errorMessage):
                    Spacer()
                    VStack(spacing: 20) {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.6))
                            .cornerRadius(15)
                        
                        Button(action: { viewModel.fetchWeather(for: cityName) }) {
                            Text("Tekrar Dene")
                                .font(.headline).foregroundColor(.white)
                                .padding(.horizontal, 24).padding(.vertical, 12)
                                .background(.ultraThinMaterial).cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
            }
        }
        .onAppear { viewModel.fetchWeather(for: cityName) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.toggleFavorite(city: cityName) }) {
                    Image(systemName: viewModel.savedCities.contains(cityName) ? "star.fill" : "star")
                        .foregroundColor(.yellow).font(.title2)
                        .scaleEffect(viewModel.savedCities.contains(cityName) ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.savedCities.contains(cityName))
                }
            }
        }
    }
}

// MARK: - Cam Efektli Detay Kutusu
struct WeatherDetailBox: View {
    var icon: String
    var title: String
    var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption).fontWeight(.bold)
            }
            .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Nefes Alan Arka Plan (Ambient Mesh)
struct AmbientBackgroundView: View {
    var colors: [Color]
    @State private var animate = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            
            GeometryReader { geo in
                Circle()
                    .fill(colors.last ?? .blue)
                    .frame(width: geo.size.width * 1.5)
                    .offset(x: animate ? -geo.size.width * 0.2 : geo.size.width * 0.2,
                            y: animate ? -geo.size.height * 0.1 : geo.size.height * 0.2)
                    .blur(radius: 60)
                    .opacity(0.6)
                
                Circle()
                    .fill(colors.first ?? .white)
                    .frame(width: geo.size.width * 1.2)
                    .offset(x: animate ? geo.size.width * 0.5 : -geo.size.width * 0.1,
                            y: animate ? geo.size.height * 0.6 : geo.size.height * 0.2)
                    .blur(radius: 70)
                    .opacity(0.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
