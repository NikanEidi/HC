//
//  TimeInputTableView.swift
//  HC
//
//  Back card — dynamic rows with NeonTimeSlider for From/To.
//

import SwiftUI

struct TimeInputTableView: View {
    @Bindable var viewModel: TrackerViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 20)

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.sessions) { session in
                            sessionRow(session)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }

            if !viewModel.sessions.isEmpty {
                totalBar.padding(.horizontal, 20).padding(.bottom, 16)
            }
        }
        .glassCard(cornerRadius: 28)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TIMESHEET")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(3)
                Text("\(viewModel.sessions.count) entries")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer()
            Button {
                ClipboardManager.copy(viewModel.generateReportString())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc").font(.system(size: 11))
                    Text("COPY").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
                }
                .foregroundColor(NeoTokyo.terminalGreen)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    Capsule().fill(NeoTokyo.terminalGreen.opacity(0.08))
                        .overlay(Capsule().strokeBorder(NeoTokyo.terminalGreen.opacity(0.2), lineWidth: 0.5))
                )
            }
        }
    }

    private func sessionRow(_ session: WorkSession) -> some View {
        let startB = viewModel.startMinutesBinding(for: session.id)
        let endB = viewModel.endMinutesBinding(for: session.id)
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMM"; return f }()

        return VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isWeekend(session.date) ? NeoTokyo.laserRed : NeoTokyo.neonPurple)
                        .frame(width: 6, height: 6)
                    Text(df.string(from: session.date).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85)).tracking(1)
                }
                Spacer()
                Text(session.durationString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(NeoTokyo.neonCyan)
                    .shadow(color: NeoTokyo.neonCyan.opacity(0.4), radius: 6)
            }
            NeonTimeSlider(label: "FROM", minutes: Binding(get: { startB.get() }, set: { startB.set($0) }), accentColor: NeoTokyo.neonCyan)
            NeonTimeSlider(label: "TO", minutes: Binding(get: { endB.get() }, set: { endB.set($0) }), accentColor: NeoTokyo.neonPurple)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.plus").font(.system(size: 32)).foregroundColor(.white.opacity(0.15))
            Text("SELECT DATES TO BEGIN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.2)).tracking(2)
            Text("Flip back to the calendar")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.12))
            Spacer()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private var totalBar: some View {
        HStack {
            Text("TOTAL HOURS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5)).tracking(2)
            Spacer()
            Text(viewModel.calculateTotalHours())
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(colors: [NeoTokyo.neonCyan, NeoTokyo.neonPurple], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: NeoTokyo.neonCyan.opacity(0.3), radius: 10)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                    LinearGradient(colors: [NeoTokyo.neonCyan.opacity(0.15), NeoTokyo.neonPurple.opacity(0.15)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.5))
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
        .frame(width: 420).padding()
    }
    .preferredColorScheme(.dark)
}
