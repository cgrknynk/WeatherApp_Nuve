//
//  GlassCard.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// MARK: - detay ızgarasındaki kutuların paylaştığı sabit yükseklik
// WeatherDetailBox/WindDetailBox/SunTimesBox üçü de bunu kullanmak zorunda,
// yoksa ızgara satırları hizasız görünür. tek bir yerden geldiği için,
// birini güncelleyip diğer ikisini unutmak artık mümkün değil
let weatherDetailBoxHeight: CGFloat = 160

// MARK: - uygulamanın tek tip cam kart efekti
// eskiden her ekranda ayrı ayrı cam efekti kodu yazıyordum, hem tekrar oluyordu
// hem de parlak arka planlarda beyaz yazı okunmuyordu. şimdi tek bir yerde
// tanımlıyorum: camı hafif karartıyorum ki arka plan ne kadar parlak olursa
// olsun yazı hep okunsun, ince bir kenarlık ekliyorum, yumuşak bir gölge de
// derinlik katıyor.
//
// accentTint opsiyonel bir parametre: verilirse (mesela nem kartı için mavi)
// kartın arkasına o renkte bulanık bir parıltı ekliyorum, kenarlık da o renge
// bürünüyor. verilmezse eski nötr beyaz kenarlık aynen kalıyor.
//
// contentShape kısmı önemli: bir kart bir butonun etiketiyse, swiftui
// varsayılan olarak sadece yazının/ikonun kapladığı alanı dokunulabilir
// sayıyor, kartın boş kalan kısımlarını değil. bu yüzden "isme dokununca
// çalışıyor ama kartın boş kısmına dokununca çalışmıyor" diye bir sorun vardı.
// contentShape kartın tüm görünen alanını dokunulabilir yapıyor, bu düzeltme
// tek yerde yapıldığı için her kart (favori satırı, arama sonucu, konum
// kartı) otomatik düzeldi
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
            .glassEffect(.regular.tint(.black.opacity(0.16)), in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder((accentTint ?? .white).opacity(accentTint == nil ? 0.16 : 0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)
            .contentShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func weatherGlassCard(cornerRadius: CGFloat = 20, accentTint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, accentTint: accentTint))
    }

    // liste satırlarının varsayılan beyaz arka planını/ayırıcısını gizleyen
    // üçlü her ekranda ayrı ayrı tekrar yazılıyordu, tek yere topladım.
    // insets verilmezse sistemin varsayılan satır boşluğu aynen kalıyor,
    // verilirse (mesela camlı bir kart satırı için) o boşluk kullanılıyor
    @ViewBuilder
    func hiddenListRow(insets: EdgeInsets? = nil) -> some View {
        if let insets {
            self.listRowInsets(insets).listRowBackground(Color.clear).listRowSeparator(.hidden)
        } else {
            self.listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }
}
