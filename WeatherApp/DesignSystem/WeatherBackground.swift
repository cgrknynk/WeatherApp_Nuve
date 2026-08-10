//
//  WeatherBackground.swift
//  WeatherApp
//
//  Created by Çağrı Kaan YANIK on 29.07.2026.
//

import SwiftUI

// hava koduna ve gece/gündüz durumuna göre renk paleti
enum WeatherPalette {
    static var isCurrentlyNight: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 6 || hour >= 19
    }

    static func colors(conditionCode: Int, isNight: Bool) -> [Color] {
        isNight ? nightColors(for: conditionCode) : dayColors(for: conditionCode)
    }

    // ayarlar/filtre gibi hava durumuna bağlı olmayan ekranlar için nötr, ama
    // saatle birlikte gündüz/gece arasında geçiş yapan bir palet
    static var chromeColors: [Color] {
        isCurrentlyNight ? chromeColorsNight : chromeColorsDay
    }

    private static let chromeColorsNight: [Color] = [
        Color(red: 0.05, green: 0.08, blue: 0.18),
        Color(red: 0.11, green: 0.15, blue: 0.32)
    ]

    private static let chromeColorsDay: [Color] = [
        Color(red: 0.22, green: 0.30, blue: 0.42),
        Color(red: 0.35, green: 0.44, blue: 0.58)
    ]

    private static func dayColors(for conditionCode: Int) -> [Color] {
        switch conditionCode {
        case 200...232: return [Color.gray.opacity(0.9), Color.black.opacity(0.8)]
        case 300...531: return [Color.blue.opacity(0.6), Color.gray.opacity(0.8)]
        case 600...622: return [Color.blue.opacity(0.4), Color.white.opacity(0.5)]
        case 701...781: return [Color.gray.opacity(0.6), Color.gray.opacity(0.8)]
        case 800:       return [Color.blue.opacity(0.6), Color.orange.opacity(0.5)]
        case 801...804: return [Color.blue.opacity(0.5), Color.gray.opacity(0.6)]
        default:        return [Color.blue.opacity(0.7), Color.purple.opacity(0.6)]
        }
    }

    private static func nightColors(for conditionCode: Int) -> [Color] {
        switch conditionCode {
        case 200...232: return [Color.black.opacity(0.9), Color.indigo.opacity(0.6)]
        case 300...531: return [Color(red: 0.05, green: 0.09, blue: 0.22), Color.blue.opacity(0.45)]
        case 600...622: return [Color(red: 0.07, green: 0.1, blue: 0.24), Color.white.opacity(0.2)]
        case 701...781: return [Color.gray.opacity(0.7), Color.black.opacity(0.7)]
        case 800:       return [Color(red: 0.02, green: 0.04, blue: 0.18), Color(red: 0.1, green: 0.08, blue: 0.32)]
        case 801...804: return [Color(red: 0.07, green: 0.09, blue: 0.2), Color.gray.opacity(0.5)]
        default:        return [Color.black.opacity(0.85), Color.indigo.opacity(0.5)]
        }
    }
}

enum WeatherParticleStyle: Hashable {
    case rain
    case storm
    case snow
    case stars
    case clouds
    case fog
    case none

    static func style(forConditionCode conditionCode: Int, isNight: Bool) -> WeatherParticleStyle {
        switch conditionCode {
        case 200...232: return .storm
        case 300...531: return .rain
        case 600...622: return .snow
        case 701...781: return .fog
        case 800: return isNight ? .stars : .none
        case 801...804: return .clouds
        default: return .none
        }
    }
}

// zamana göre hesaplanan, durum tutmayan parçacık katmanı
struct WeatherParticleLayer: View {
    let style: WeatherParticleStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let seeds: [ParticleSeed]
    private let windTilt: Double

    init(style: WeatherParticleStyle, windDeg: Int? = nil) {
        self.style = style
        self.seeds = (0..<Self.particleCount(for: style)).map { _ in .random() }
        if let windDeg {
            self.windTilt = sin(Double(windDeg) * .pi / 180)
        } else {
            self.windTilt = -0.25
        }
    }

    private static func particleCount(for style: WeatherParticleStyle) -> Int {
        switch style {
        case .rain, .storm: return 70
        case .snow:   return 55
        case .stars:  return 50
        case .clouds: return 4
        case .fog:    return 3
        case .none:   return 0
        }
    }

    var body: some View {
        if style == .none {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    draw(in: &context, size: size, elapsed: elapsed)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        switch style {
        case .rain, .storm: drawRain(in: &context, size: size, elapsed: elapsed)
        case .snow:   drawSnow(in: &context, size: size, elapsed: elapsed)
        case .stars:  drawStars(in: &context, size: size, elapsed: elapsed)
        case .clouds: drawClouds(in: &context, size: size, elapsed: elapsed)
        case .fog:    drawFog(in: &context, size: size, elapsed: elapsed)
        case .none:   break
        }
    }

    private func drawRain(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for seed in seeds {
            let depthSpeed = 0.7 + seed.depth * 0.9
            let fallDuration = 0.9 / (seed.speed * depthSpeed)
            let progress = ((elapsed / fallDuration) + seed.phase).truncatingRemainder(dividingBy: 1)
            let startY = progress * (size.height + 60) - 40
            let x = seed.x * size.width
            let dropLength = 14 + seed.depth * 10
            let dx = windTilt * (12 + seed.depth * 10)

            var path = Path()
            path.move(to: CGPoint(x: x, y: startY))
            path.addLine(to: CGPoint(x: x + dx, y: startY + dropLength))

            let opacity = (0.18 + seed.depth * 0.3) * seed.scale
            let lineWidth = 1.0 + seed.depth * 0.9
            context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: lineWidth)
        }
    }

    private func drawSnow(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for seed in seeds {
            let depthSpeed = 0.6 + seed.depth * 0.8
            let fallDuration = 4.5 / (seed.speed * depthSpeed)
            let progress = ((elapsed / fallDuration) + seed.phase).truncatingRemainder(dividingBy: 1)
            let y = progress * (size.height + 20) - 10
            let driftAmplitude = 10 + seed.depth * 10
            let drift = sin(elapsed * 0.8 + seed.phase * .pi * 2) * driftAmplitude
            let x = seed.x * size.width + drift

            let radius = (1.1 + seed.depth * 1.4) * seed.scale
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let opacity = 0.35 + seed.depth * 0.4
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private func drawClouds(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for seed in seeds {
            let driftSpeed = 0.025 * seed.speed
            let loopPosition = (elapsed * driftSpeed + seed.phase).truncatingRemainder(dividingBy: 1.6) - 0.3
            let x = loopPosition * size.width
            let y = seed.y * size.height * 0.65

            let cloudWidth = size.width * (0.4 + seed.scale * 0.25)
            let cloudHeight = cloudWidth * 0.45
            let rect = CGRect(x: x - cloudWidth / 2, y: y - cloudHeight / 2, width: cloudWidth, height: cloudHeight)

            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05 + seed.depth * 0.05)))
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for seed in seeds {
            let twinkle = (sin(elapsed * seed.speed + seed.phase * .pi * 2) + 1) / 2
            let opacity = 0.25 + twinkle * 0.55
            let radius = 0.8 + seed.scale * 0.6
            let x = seed.x * size.width
            let y = seed.y * size.height * 0.6

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private func drawFog(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for (index, seed) in seeds.enumerated() {
            let bandHeight = size.height / CGFloat(seeds.count) * 1.6
            let baseY = size.height * (CGFloat(index) / CGFloat(seeds.count))
            let drift = sin(elapsed * 0.05 * seed.speed + seed.phase) * size.width * 0.15
            let rect = CGRect(x: -size.width * 0.3 + drift, y: baseY, width: size.width * 1.6, height: bandHeight)

            let breathe = (sin(elapsed * 0.15 + seed.phase * .pi * 2) + 1) / 2
            let opacity = 0.04 + breathe * 0.05
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }
}

struct LightningFlashOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let opacity = flashOpacity(at: elapsed)
                    guard opacity > 0 else { return }
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(opacity)))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func flashOpacity(at elapsed: Double) -> Double {
        let cycleLength = 7.0
        let flashDuration = 0.18
        let t = elapsed.truncatingRemainder(dividingBy: cycleLength)
        guard t < flashDuration else { return 0 }
        let progress = t / flashDuration
        return sin(progress * .pi) * 0.35
    }
}

struct WeatherParticleField: View {
    let style: WeatherParticleStyle
    let windDeg: Int?

    var body: some View {
        ZStack {
            WeatherParticleLayer(style: style, windDeg: windDeg)
            if style == .storm {
                LightningFlashOverlay()
            }
        }
    }
}

// rastgele ama sabit başlangıç değerleri, zamana göre ilerletiliyor
private struct ParticleSeed {
    let x: Double
    let y: Double
    let speed: Double
    let phase: Double
    let scale: Double
    let depth: Double

    static func random() -> ParticleSeed {
        ParticleSeed(
            x: .random(in: 0...1),
            y: .random(in: 0...1),
            speed: .random(in: 0.7...1.3),
            phase: .random(in: 0...1),
            scale: .random(in: 0.5...1.2),
            depth: .random(in: 0...1)
        )
    }
}

struct AmbientBackgroundView: View {
    var colors: [Color]
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { geo in
                Circle()
                    .fill(colors.last ?? .blue)
                    .frame(width: geo.size.width * 1.5)
                    .offset(x: animate ? -geo.size.width * 0.2 : geo.size.width * 0.2,
                            y: animate ? -geo.size.height * 0.1 : geo.size.height * 0.2)
                    .blur(radius: 60)
                    .opacity(0.6)

                Circle()
                    .fill(colors.first ?? .white)
                    .frame(width: geo.size.width * 1.2)
                    .offset(x: animate ? geo.size.width * 0.5 : -geo.size.width * 0.1,
                            y: animate ? geo.size.height * 0.6 : geo.size.height * 0.2)
                    .blur(radius: 70)
                    .opacity(0.5)
            }

            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: .center,
                startRadius: 160,
                endRadius: 480
            )
            .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// şehir detay ekranının tam arka planı: renk paleti + parçacık katmanı
struct WeatherBackground: View {
    let conditionCode: Int
    let isNight: Bool
    let windDeg: Int?

    private var particleStyle: WeatherParticleStyle {
        WeatherParticleStyle.style(forConditionCode: conditionCode, isNight: isNight)
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView(colors: WeatherPalette.colors(conditionCode: conditionCode, isNight: isNight))
            WeatherParticleField(style: particleStyle, windDeg: windDeg)
        }
    }
}
