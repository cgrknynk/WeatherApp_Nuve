//
//  BrandHeader.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 03.08.2026.
//

import SwiftUI

// MARK: - üst çubuktaki logo
// ana ekranın en üstünde düz "nuve" yazısı çok sıkıcı duruyordu. bunun yerine
// kendi çizdiğim küçük bir simgeyi (uygulama ikonuyla aynı motif, bir yörünge
// halkasına sarılı küre) ince harfli "nuve" yazısıyla yan yana koydum. sistemin
// kalın varsayılan başlık fontu yerine kendi ince fontumu kullanıyorum, daha
// şık duruyor
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
