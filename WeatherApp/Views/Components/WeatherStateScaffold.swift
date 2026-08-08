//
//  WeatherStateScaffold.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

// MARK: - yükleniyor/başarılı/hata durumlarının ortak iskeleti
// ekranın üç durumunu (yükleniyor, başarılı, hata) WeatherView'ın kendi
// dosyasından ayırıp buraya topladım, böylece o dosya sadece kendi düzenine
// (üst çubuk, favori şeridi) odaklanabiliyor. successContent closure'ı
// başarı durumundaki veriyi alıp WeatherContentView'ı üretiyor
struct WeatherStateScaffold<SuccessContent: View>: View {
    let state: WeatherViewState
    let onRetry: () -> Void
    @ViewBuilder let successContent: (CityWeather) -> SuccessContent

    var body: some View {
        switch state {
        case .idle, .loading:
            WeatherLoadingSkeleton()

        case .success(let weather):
            successContent(weather)

        case .error(let errorMessage):
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(.weatherBody)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button("Tekrar Dene") {
                    onRetry()
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}
