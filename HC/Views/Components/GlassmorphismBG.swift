//
//  GlassmorphismBG.swift
//  HC
//
//  Neo-Tokyo Data Terminal — Vantablack canvas, breathing halos,
//  CRT scanlines, detailed ASCII dragon, perspective grid.
//

import SwiftUI

// MARK: - Color Constants

enum NeoTokyo {
    static let vantablack      = Color(red: 0.020, green: 0.020, blue: 0.020)
    static let vantablackDeep  = Color(red: 0.008, green: 0.008, blue: 0.012)

    static let neonPurple      = Color(red: 0.749, green: 0.251, blue: 1.000)
    static let neonCyan        = Color(red: 0.000, green: 0.961, blue: 1.000)
    static let laserRed        = Color(red: 1.000, green: 0.090, blue: 0.267)
    static let laserGold       = Color(red: 1.000, green: 0.843, blue: 0.000)

    static let glassStroke     = Color.white.opacity(0.08)
    static let glassFill       = Color.white.opacity(0.04)

    static let terminalGreen   = Color(red: 0.180, green: 1.000, blue: 0.529)
    static let deepIndigo      = Color(red: 0.180, green: 0.090, blue: 0.420)
}

// MARK: - Glassmorphism Background

struct GlassmorphismBG: View {
    @State private var breathePhase: CGFloat = 0
    @State private var scanlineOffset: CGFloat = 0

    var body: some View {
        ZStack {
            NeoTokyo.vantablackDeep.ignoresSafeArea()

            perspectiveGrid.ignoresSafeArea().opacity(0.05)

            breathingHalos.ignoresSafeArea().blur(radius: 130).opacity(0.50)

            dragonWatermark.ignoresSafeArea()

            scanlines.ignoresSafeArea().opacity(0.03).blendMode(.overlay)

            RadialGradient(
                colors: [.clear, NeoTokyo.vantablackDeep.opacity(0.7)],
                center: .center, startRadius: 200, endRadius: 700
            ).ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                breathePhase = 1
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                scanlineOffset = 1
            }
        }
    }

    // MARK: - Breathing Halos

    private var breathingHalos: some View {
        Canvas { context, size in
            let p1 = CGPoint(
                x: size.width * (0.15 + 0.08 * sin(breathePhase * .pi)),
                y: size.height * (0.18 + 0.10 * cos(breathePhase * .pi))
            )
            let r1 = min(size.width, size.height) * (0.38 + 0.10 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p1.x - r1, y: p1.y - r1, width: r1 * 2, height: r1 * 2)),
                    with: .radialGradient(Gradient(colors: [NeoTokyo.neonPurple.opacity(0.5), .clear]),
                                          center: p1, startRadius: 0, endRadius: r1)
                )
            }

            let p2 = CGPoint(
                x: size.width * (0.82 - 0.06 * cos(breathePhase * .pi)),
                y: size.height * (0.75 - 0.08 * sin(breathePhase * .pi))
            )
            let r2 = min(size.width, size.height) * (0.32 + 0.08 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p2.x - r2, y: p2.y - r2, width: r2 * 2, height: r2 * 2)),
                    with: .radialGradient(Gradient(colors: [NeoTokyo.neonCyan.opacity(0.35), .clear]),
                                          center: p2, startRadius: 0, endRadius: r2)
                )
            }

            let p3 = CGPoint(
                x: size.width * (0.50 + 0.04 * sin(breathePhase * .pi * 1.5)),
                y: size.height * (0.88 - 0.05 * breathePhase)
            )
            let r3 = min(size.width, size.height) * (0.20 + 0.05 * breathePhase)
            context.drawLayer { ctx in
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p3.x - r3, y: p3.y - r3, width: r3 * 2, height: r3 * 2)),
                    with: .radialGradient(Gradient(colors: [NeoTokyo.laserRed.opacity(0.15), .clear]),
                                          center: p3, startRadius: 0, endRadius: r3)
                )
            }
        }
    }

    // MARK: - Perspective Grid

    private var perspectiveGrid: some View {
        Canvas { context, size in
            let lineCount = 24
            let spacing = size.width / CGFloat(lineCount)
            for i in 0...lineCount {
                let x = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height * 0.5))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(NeoTokyo.neonCyan.opacity(0.15)),
                               style: StrokeStyle(lineWidth: 0.5))
            }
            let hLines = 16
            for i in 0...hLines {
                let progress = CGFloat(i) / CGFloat(hLines)
                let y = size.height * (0.5 + progress * 0.5)
                let fade = progress * progress
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(NeoTokyo.neonPurple.opacity(0.08 + fade * 0.15)),
                               style: StrokeStyle(lineWidth: 0.4))
            }
        }
    }

    // MARK: - Dragon Watermark (Detailed ASCII)

    private var dragonWatermark: some View {
        let dragon = [
            "                                  __----~~~~~~~~~~~------___",
            "                       .  .   ~~//====......          __--~ ~~",
            "       -.            \\_|//     |||\\\\  ~~~~~~::::... /~",
            "    ___-==_       _-~o~  \\/    |||  \\\\            _/~~-",
            "__---~~~.==~|\\=_    -_--~/_----|  \\\\           _/~",
            "~-==____  ~~~|.----/~~    |   |  \\\\        _/~",
            "        ~-_~~ ~~ | |~|~~~---__   |   |     _-~",
            "           ~~--~~ \\~\\~| |__---~~~-__|  |---~~\\",
            "                    ~--~~~~---_  _~~\\  |-----/~\\",
            "                             ~~   \\  ~~/  /     \\",
            "                                   ~~ \\ /      /",
            "                                      ~|      |",
            "                                       |      |",
            "                                        \\     /",
            "                                         ~--~~"
        ]

        return VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(dragon.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 6, weight: .regular, design: .monospaced))
                    }
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            NeoTokyo.laserRed.opacity(0.05),
                            NeoTokyo.laserGold.opacity(0.04),
                            NeoTokyo.neonPurple.opacity(0.03)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .padding(.trailing, 30)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - CRT Scanlines

    private var scanlines: some View {
        GeometryReader { geo in
            let offset = scanlineOffset * geo.size.height
            Canvas { context, size in
                let lineSpacing: CGFloat = 3
                let count = Int(size.height / lineSpacing) + 1
                for i in 0..<count {
                    let y = CGFloat(i) * lineSpacing
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.04)),
                                   style: StrokeStyle(lineWidth: 0.5))
                }
                let beamY = offset.truncatingRemainder(dividingBy: size.height)
                var beam = Path()
                beam.move(to: CGPoint(x: 0, y: beamY))
                beam.addLine(to: CGPoint(x: size.width, y: beamY))
                context.stroke(beam, with: .color(NeoTokyo.neonCyan.opacity(0.08)),
                               style: StrokeStyle(lineWidth: 2))
            }
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var strokeOpacity: CGFloat = 0.10
    var glowColor: Color = NeoTokyo.neonPurple

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(NeoTokyo.vantablack.opacity(0.80))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.08))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.2),
                                Color.white.opacity(strokeOpacity * 0.05)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: glowColor.opacity(0.06), radius: 40, x: 0, y: 12)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, strokeOpacity: CGFloat = 0.10, glowColor: Color = NeoTokyo.neonPurple) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, glowColor: glowColor))
    }
}

#Preview {
    GlassmorphismBG()
        .preferredColorScheme(.dark)
}
