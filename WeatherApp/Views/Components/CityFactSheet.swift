//
//  CityFactSheet.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import SwiftUI

// MARK: - "ilginç bilgi" kartının üç hâli
// yükleniyor / bulundu / bulunamadı — sheet bu üçünü ayrı ayrı gösteriyor
private enum FactLoadState: Equatable {
    case loading
    case found(CityFact)
    case notFound
}

// MARK: - şehir/yer hakkında vikipedi'den çekilen ilginç bilgi kartı
// weatherview'ın köşesindeki düğmeye basınca açılıyor. bu view kendi ağ
// isteğini kendisi yönetiyor (weathercontentview gibi tamamen durumsuz
// kalmasına gerek yok, çünkü sadece kendi içindeki bir sheet'in yaşam
// döngüsüyle ilgili — dışarıya hiçbir şey sızdırmıyor)
struct CityFactSheet: View {
    let cityName: String
    let countryName: String
    @Environment(\.dismiss) private var dismiss
    @State private var state: FactLoadState = .loading

    private let service = WikipediaFactService()

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(colors: WeatherPalette.chromeColors)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle(String(localized: "fact.title", defaultValue: "İlginç Bilgi"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close", defaultValue: "Kapat")) { dismiss() }
                }
            }
        }
        .task {
            let fact = await service.fetchFact(cityName: cityName, countryName: countryName)
            state = fact.map(FactLoadState.found) ?? .notFound
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)

        case .notFound:
            GlassWarningView(
                iconName: "sparkles",
                message: String(
                    localized: "fact.not_found",
                    defaultValue: "Bu yer hakkında henüz bir bilgi bulamadım.\nBaşka bir şehri deneyebilirsin."
                )
            )
            .padding(.horizontal, 20)

        case .found(let fact):
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let thumbnailURL = fact.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.white.opacity(0.08)
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text(fact.title)
                            .font(.weatherRowTitle)
                    }
                    .foregroundColor(.white)

                    Text(fact.extract)
                        .font(.weatherBody)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)

                    Text(String(localized: "fact.source", defaultValue: "Kaynak: Wikipedia"))
                        .font(.weatherCaption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding()
                .weatherGlassCard()
                .padding(20)
            }
        }
    }
}

#Preview {
    CityFactSheet(cityName: "İzmir", countryName: "Türkiye")
}
