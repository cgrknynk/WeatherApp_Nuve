//
//  SearchResultRow.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

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
