//
//  NeonTimeSlider.swift
//  HC
//
//  Premium frictionless neon slider — haptic 15-min snaps,
//  double-gradient track, glowing thumb with pulse, tick marks.
//

import SwiftUI

struct NeonTimeSlider: View {
    let label: String
    @Binding var minutes: Int
    var accentColor: Color = NeoTokyo.neonCyan

    private let step: Int = 15
    private let minMinutes: Int = 0
    private let maxMinutes: Int = 1440

    @State private var isDragging: Bool = false

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // ── Label + Time Display ──
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)

                Spacer()

                // Glowing time readout
                HStack(spacing: 0) {
                    Text(hourString)
                        .foregroundColor(accentColor)
                    Text(":")
                        .foregroundColor(accentColor.opacity(0.5))
                    Text(minuteString)
                        .foregroundColor(accentColor)
                }
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .shadow(color: accentColor.opacity(isDragging ? 0.7 : 0.3), radius: isDragging ? 16 : 5)
                .animation(.easeOut(duration: 0.15), value: isDragging)
                .animation(.easeOut(duration: 0.15), value: minutes)
            }

            // ── Slider Track ──
            GeometryReader { geo in
                let trackW = geo.size.width
                let progress = CGFloat(minutes - minMinutes) / CGFloat(maxMinutes - minMinutes)
                let thumbX = max(0, min(trackW, progress * trackW))

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 5)

                    // Tick marks every hour
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { _ in
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 0.5, height: 9)
                        }
                        Spacer()
                    }
                    .frame(height: 5)

                    // Active fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.4), accentColor.opacity(0.9), accentColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: thumbX, height: 5)
                        .shadow(color: accentColor.opacity(isDragging ? 0.5 : 0.2), radius: isDragging ? 12 : 4)

                    // Thumb
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(accentColor.opacity(isDragging ? 0.15 : 0))
                            .frame(width: 34, height: 34)

                        // Main thumb
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, accentColor.opacity(0.8)],
                                    center: .center, startRadius: 0, endRadius: 11
                                )
                            )
                            .frame(width: isDragging ? 22 : 17, height: isDragging ? 22 : 17)
                            .shadow(color: accentColor.opacity(0.6), radius: isDragging ? 12 : 5)
                            .overlay(
                                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .position(x: thumbX, y: 2.5)
                    .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.75), value: isDragging)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let fraction = max(0, min(1, value.location.x / trackW))
                                let raw = Int(fraction * CGFloat(maxMinutes - minMinutes)) + minMinutes
                                let snapped = (raw / step) * step
                                if snapped != minutes {
                                    impactGenerator.impactOccurred(intensity: 0.35)
                                    minutes = snapped
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.5)
                            }
                    )
                }
                .frame(height: 5)
            }
            .frame(height: 30)

            // ── Hour Labels ──
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    if hour > 0 { Spacer() }
                    Text("\(hour)h")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.18))
                    if hour < 24 { Spacer() }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 4)
        .onAppear { impactGenerator.prepare() }
    }

    private var hourString: String { "\(minutes / 60)" }
    private var minuteString: String { String(format: "%02d", minutes % 60) }
}

#Preview {
    ZStack {
        NeoTokyo.vantablack.ignoresSafeArea()
        VStack(spacing: 30) {
            NeonTimeSlider(label: "FROM", minutes: .constant(420), accentColor: NeoTokyo.neonCyan)
            NeonTimeSlider(label: "TO", minutes: .constant(960), accentColor: NeoTokyo.neonPurple)
        }
        .padding(40)
    }
    .preferredColorScheme(.dark)
}
