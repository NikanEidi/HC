//
//  TimeInputTableView.swift
//  HC
//
//  Back card — premium session rows with NeonTimeSliders.
//

import SwiftUI

struct TimeInputTableView: View {
    @Bindable var viewModel: TrackerViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 14)

            // Gradient divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [NeoTokyo.neonPurple.opacity(0.0), NeoTokyo.neonPurple.opacity(0.15), NeoTokyo.neonCyan.opacity(0.0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .padding(.horizontal, 22)

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                            sessionRow(session, index: index)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
            }

            if !viewModel.sessions.isEmpty {
                totalBar
                    .padding(.horizontal, 20).padding(.bottom, 18)
            }
        }
        .glassCard(cornerRadius: 26, glowColor: NeoTokyo.neonCyan)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("⬡")
                        .font(.system(size: 12))
                        .foregroundColor(NeoTokyo.neonPurple.opacity(0.5))
                    Text("TIMESHEET")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(4)
                }
                Text("\(viewModel.sessions.count) entr\(viewModel.sessions.count == 1 ? "y" : "ies") logged")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(1)
            }
            Spacer()
            Button {
                ClipboardManager.copy(viewModel.generateReportString())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill").font(.system(size: 11))
                    Text("COPY").font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2)
                }
                .foregroundColor(NeoTokyo.terminalGreen)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(
                    Capsule().fill(NeoTokyo.terminalGreen.opacity(0.05))
                        .overlay(Capsule().strokeBorder(NeoTokyo.terminalGreen.opacity(0.15), lineWidth: 0.5))
                        .shadow(color: NeoTokyo.terminalGreen.opacity(0.06), radius: 8)
                )
            }
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: WorkSession, index: Int) -> some View {
        let startB = viewModel.startMinutesBinding(for: session.id)
        let endB = viewModel.endMinutesBinding(for: session.id)
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMM"; return f }()
        let isWknd = viewModel.isWeekend(session.date)

        return VStack(spacing: 14) {
            HStack {
                // Index + Date
                HStack(spacing: 8) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.03))
                        )

                    Circle()
                        .fill(isWknd ? NeoTokyo.laserRed : NeoTokyo.neonPurple)
                        .frame(width: 7, height: 7)
                        .shadow(color: (isWknd ? NeoTokyo.laserRed : NeoTokyo.neonPurple).opacity(0.5), radius: 4)

                    Text(df.string(from: session.date).uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1.5)
                }

                Spacer()

                // Duration
                Text(session.durationString)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [NeoTokyo.neonCyan, NeoTokyo.neonPurple],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: NeoTokyo.neonCyan.opacity(0.35), radius: 8)
            }

            NeonTimeSlider(label: "FROM", minutes: Binding(get: { startB.get() }, set: { startB.set($0) }), accentColor: NeoTokyo.neonCyan)
            NeonTimeSlider(label: "TO", minutes: Binding(get: { endB.get() }, set: { endB.set($0) }), accentColor: NeoTokyo.neonPurple)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.015))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.10))

            Text("NO SESSIONS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
                .tracking(3)

            Text("Flip to calendar → select dates")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.08))
            Spacer()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - Total Bar

    private var totalBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("★")
                    .font(.system(size: 12))
                    .foregroundColor(NeoTokyo.neonCyan.opacity(0.5))
                Text("TOTAL HOURS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2.5)
            }
            Spacer()
            Text(viewModel.calculateTotalHours())
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(colors: [NeoTokyo.neonCyan, NeoTokyo.neonPurple], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: NeoTokyo.neonCyan.opacity(0.3), radius: 12)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [NeoTokyo.neonCyan.opacity(0.12), NeoTokyo.neonPurple.opacity(0.12)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: NeoTokyo.neonCyan.opacity(0.04), radius: 12)
        )
    }
}

#Preview {
    ZStack {
        GlassmorphismBG()
        TimeInputTableView(viewModel: {
            let vm = TrackerViewModel()
            let cal = Calendar.current
            for i in 0..<3 {
                if let d = cal.date(byAdding: .day, value: i, to: Date()) { vm.toggleDate(d) }
            }
            return vm
        }())
        .frame(width: 440).padding()
    }
    .preferredColorScheme(.dark)
}
