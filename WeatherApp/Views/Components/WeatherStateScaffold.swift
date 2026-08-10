//
//  WeatherStateScaffold.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

// yükleniyor/başarılı/hata durumlarının ortak iskeleti
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
                .weatherProminentButtonStyle()
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }
}
