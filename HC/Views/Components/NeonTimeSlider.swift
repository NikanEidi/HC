//
//  NeonTimeSlider.swift
//  HC
//
//  Custom frictionless neon slider for time selection.
//  Haptic clicks on 15-minute snap increments.
//

import SwiftUI

struct NeonTimeSlider: View {
    let label: String
    @Binding var minutes: Int          // Total minutes from midnight (0–1440)
    var accentColor: Color = NeoTokyo.neonCyan

    // 15-minute snap increments
    private let step: Int = 15
    private let minMinutes: Int = 0
    private let maxMinutes: Int = 1440  // 24h

    @State private var isDragging: Bool = false
    @GestureState private var dragOffset: CGFloat = 0

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label + Time Display
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer()

                Text(timeString)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                    .shadow(color: accentColor.opacity(0.6), radius: isDragging ? 12 : 4)
                    .animation(.easeOut(duration: 0.2), value: isDragging)
            }

            // Slider Track
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let progress = CGFloat(minutes - minMinutes) / CGFloat(maxMinutes - minMinutes)
                let thumbX = progress * trackWidth

                ZStack(alignment: .leading) {
                    // ── Background Track ──
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    // ── Active Track ──
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.7),
                                    accentColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: thumbX, height: 6)
                        .shadow(color: accentColor.opacity(isDragging ? 0.6 : 0.3), radius: isDragging ? 10 : 4)

                    // ── Thumb ──
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white,
                                    accentColor
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: isDragging ? 26 : 20, height: isDragging ? 26 : 20)
                        .shadow(color: accentColor.opacity(0.7), radius: isDragging ? 14 : 6)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .position(x: thumbX, y: 3)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.75), value: isDragging)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let fraction = max(0, min(1, value.location.x / trackWidth))
                                    let rawMinutes = Int(fraction * CGFloat(maxMinutes - minMinutes)) + minMinutes
                                    let snapped = (rawMinutes / step) * step

                                    if snapped != minutes {
                                        impactGenerator.impactOccurred(intensity: 0.4)
                                        minutes = snapped
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    impactGenerator.impactOccurred(intensity: 0.6)
                                }
                        )
                }
                .frame(height: 6)
            }
            .frame(height: 26)

            // ── Hour ticks ──
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    if hour > 0 { Spacer() }
                    Text("\(hour)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                    if hour < 24 { Spacer() }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 4)
        .onAppear {
            impactGenerator.prepare()
        }
    }

    private var timeString: String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }
}

#Preview {
    ZStack {
        NeoTokyo.vantablack.ignoresSafeArea()

        VStack(spacing: 30) {
            NeonTimeSlider(
                label: "FROM",
                minutes: .constant(420),
                accentColor: NeoTokyo.neonCyan
            )

            NeonTimeSlider(
                label: "TO",
                minutes: .constant(960),
                accentColor: NeoTokyo.neonPurple
            )
        }
        .padding(40)
    }
    .preferredColorScheme(.dark)
}
