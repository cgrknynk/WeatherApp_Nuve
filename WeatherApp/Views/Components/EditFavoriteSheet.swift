//
//  EditFavoriteSheet.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 08.08.2026.
//

import SwiftUI

// MARK: - özgünlük turu: favoriye takma isim ve kart rengi verme
// ana ekranda bir favoriyi SAĞA kaydırınca açılan küçük düzenleme sayfası.
// hava durumu sorgusu her zaman şehrin GERÇEK ismi/koordinatıyla yapılmaya
// devam ediyor — burada değiştirdiğimiz şey SADECE görünüm (bkz.
// FavoriteCity.displayName/accentColor)
struct EditFavoriteSheet: View {
    let favorite: FavoriteCity
    let onSave: (String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String
    @State private var selectedColorName: String?

    init(favorite: FavoriteCity, onSave: @escaping (String?, String?) -> Void) {
        self.favorite = favorite
        self.onSave = onSave
        _nickname = State(initialValue: favorite.nickname ?? "")
        _selectedColorName = State(initialValue: favorite.accentColorName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackgroundView(colors: WeatherPalette.chromeColors)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "edit_favorite.nickname_title", defaultValue: "TAKMA İSİM"))
                            .weatherLabelStyle()
                            .foregroundColor(.white.opacity(0.7))

                        TextField(favorite.name.capitalized, text: $nickname)
                            .font(.weatherRowTitle)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .weatherGlassCard(cornerRadius: 14)
                            .submitLabel(.done)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "edit_favorite.color_title", defaultValue: "KART RENGİ"))
                            .weatherLabelStyle()
                            .foregroundColor(.white.opacity(0.7))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                colorSwatch(name: nil, color: .white.opacity(0.4))
                                ForEach(FavoriteCity.namedColors.keys.sorted(), id: \.self) { name in
                                    colorSwatch(name: name, color: FavoriteCity.namedColors[name] ?? .white)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Spacer()
                }
                .padding(20)
                .padding(.top, 12)
            }
            .navigationTitle(String(localized: "edit_favorite.title", defaultValue: "Favoriyi Düzenle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close", defaultValue: "Kapat")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", defaultValue: "Kaydet")) {
                        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? nil : trimmed, selectedColorName)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func colorSwatch(name: String?, color: Color) -> some View {
        Button {
            selectedColorName = name
        } label: {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().strokeBorder(.white, lineWidth: selectedColorName == name ? 2.5 : 0)
                )
                .overlay {
                    if name == nil {
                        Image(systemName: "slash.circle")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditFavoriteSheet(favorite: FavoriteCity(name: "İzmir", lat: 38.4, lon: 27.1), onSave: { _, _ in })
}
