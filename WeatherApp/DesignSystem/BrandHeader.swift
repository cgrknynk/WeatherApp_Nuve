//
//  BrandHeader.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

// üst çubuktaki logo + "Nuve" yazısı
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("BrandMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                )

            Text("Nuve")
                .font(.weatherBrandWordmark)
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.82)], startPoint: .leading, endPoint: .trailing)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nuve")
    }
}
