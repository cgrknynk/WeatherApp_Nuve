//
//  GlassCard.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

let weatherDetailBoxHeight: CGFloat = 160

// ortak cam kart efekti
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var accentTint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if let accentTint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(accentTint.opacity(0.3))
                            .blur(radius: 20)
                    }
                }
            )
            .modifier(GlassCardSurface(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder((accentTint ?? .white).opacity(accentTint == nil ? 0.16 : 0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
            .contentShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

// asıl cam yüzey: iOS 26'nın Liquid Glass efekti sadece iOS 26+'da var,
// altındaki sürümlerde (iOS 18-25) aynı görünümü taklit eden bir
// ultraThinMaterial arka planına düşüyor
private struct GlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.black.opacity(0.16)), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .background(.black.opacity(0.16), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    func weatherGlassCard(cornerRadius: CGFloat = 20, accentTint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, accentTint: accentTint))
    }

    // liste satırının varsayılan arka planını/ayırıcısını gizler
    @ViewBuilder
    func hiddenListRow(insets: EdgeInsets? = nil) -> some View {
        if let insets {
            self.listRowInsets(insets).listRowBackground(Color.clear).listRowSeparator(.hidden)
        } else {
            self.listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }

    // iOS 26'nın "glassProminent" buton stili yoksa en yakın muadili olan
    // "borderedProminent"a düşer
    @ViewBuilder
    func weatherProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    // GlassEffectContainer sadece iOS 26+'da var; altındaki sürümlerde
    // içeriği efektsiz, doğrudan kendisi olarak gösterir
    @ViewBuilder
    func weatherGlassEffectContainer() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
    }
}
