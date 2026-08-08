//
//  SearchResultRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - arama sonucu satırı
// eskiden mapkit'in ham alt başlığını da gösteriyordum (mesela "kayseri
// province, turkey" gibi) ama bu metin uygulamanın diline göre değil
// mapkit'in kendi veritabanına göre geliyordu, türkçe aramada bile ingilizce
// kelimeler çıkabiliyordu. güvenilir şekilde düzeltemediğim için tamamen
// kaldırdım, artık sadece şehir ismi var
struct SearchResultRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.weatherRowTitle)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weatherGlassCard(cornerRadius: 18)
    }
}
