//
//  GlitchFlipContainer.swift
//  HC
//
//  3D glitch/shatter transition between two views.
//  Replaces a standard flip with chromatic aberration + noise artifacts.
//

import SwiftUI

struct GlitchFlipContainer<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    let front: () -> Front
    let back: () -> Back

    @State private var rotation: Double = 0
    @State private var glitchIntensity: CGFloat = 0
    @State private var noiseOpacity: CGFloat = 0
    @State private var rgbSplit: CGFloat = 0
    @State private var shatterOffsets: [CGSize] = Array(repeating: .zero, count: 6)
    @State private var sliceOpacity: [CGFloat] = Array(repeating: 1, count: 6)

    private let duration: Double = 0.6
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ZStack {
            // ── Content Layer ──
            ZStack {
                // Front
                front()
                    .opacity(rotation < 90 ? 1 : 0)

                // Back (pre-flipped so it reads correctly)
                back()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(rotation >= 90 ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0.05 * glitchIntensity, y: 1, z: 0.02 * glitchIntensity),
                perspective: 0.4
            )

            // ── Glitch Artifacts ──
            if glitchIntensity > 0 {
                glitchOverlay
            }
        }
        .onChange(of: isFlipped) { _, newValue in
            triggerGlitchFlip(to: newValue)
        }
    }

    // MARK: - Glitch Overlay

    private var glitchOverlay: some View {
        ZStack {
            // RGB chromatic split
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(NeoTokyo.neonCyan.opacity(0.1 * glitchIntensity))
                .offset(x: rgbSplit, y: -rgbSplit * 0.5)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(NeoTokyo.laserRed.opacity(0.08 * glitchIntensity))
                .offset(x: -rgbSplit, y: rgbSplit * 0.3)
                .blendMode(.screen)

            // Horizontal glitch slices
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.04 * sliceOpacity[i]))
                        .frame(height: 12)
                        .offset(shatterOffsets[i])
                        .opacity(Double(sliceOpacity[i]))
                }
            }
            .blendMode(.overlay)

            // Noise scanlines
            VStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(Double.random(in: 0...0.06) * Double(noiseOpacity)))
                        .frame(height: CGFloat.random(in: 1...3))
                }
            }
            .blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Animation Sequence

    private func triggerGlitchFlip(to flipped: Bool) {
        haptic.prepare()

        // Phase 1: Pre-glitch (distortion builds)
        withAnimation(.easeIn(duration: duration * 0.2)) {
            glitchIntensity = 1.0
            rgbSplit = CGFloat.random(in: 6...14)
            noiseOpacity = 0.8
            randomizeShatter()
        }

        // Phase 2: The flip + peak glitch
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.2) {
            haptic.impactOccurred(intensity: 1.0)

            withAnimation(.easeInOut(duration: duration * 0.5)) {
                rotation = flipped ? 180 : 0
                rgbSplit = CGFloat.random(in: -18...18)
                randomizeShatter()
            }
        }

        // Phase 3: Settle — glitch fades
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.7) {
            withAnimation(.easeOut(duration: duration * 0.3)) {
                glitchIntensity = 0
                rgbSplit = 0
                noiseOpacity = 0
                shatterOffsets = Array(repeating: .zero, count: 6)
                sliceOpacity = Array(repeating: 1, count: 6)
            }
        }
    }

    private func randomizeShatter() {
        for i in 0..<6 {
            shatterOffsets[i] = CGSize(
                width: CGFloat.random(in: -20...20),
                height: CGFloat.random(in: -4...4)
            )
            sliceOpacity[i] = CGFloat.random(in: 0.3...1.0)
        }
    }
}

#Preview {
    @Previewable @State var flipped = false

    ZStack {
        NeoTokyo.vantablack.ignoresSafeArea()

        VStack(spacing: 30) {
            GlitchFlipContainer(isFlipped: $flipped) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(NeoTokyo.neonPurple.opacity(0.3))
                    .frame(width: 320, height: 400)
                    .overlay(Text("FRONT").foregroundColor(.white))
            } back: {
                RoundedRectangle(cornerRadius: 24)
                    .fill(NeoTokyo.neonCyan.opacity(0.3))
                    .frame(width: 320, height: 400)
                    .overlay(Text("BACK").foregroundColor(.white))
            }

            Button("FLIP") { flipped.toggle() }
                .foregroundColor(NeoTokyo.neonCyan)
        }
    }
    .preferredColorScheme(.dark)
}
