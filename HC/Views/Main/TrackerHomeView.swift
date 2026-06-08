//
//  TrackerHomeView.swift
//  HC
//
//  Root composition — asymmetric layout with GlitchFlipContainer
//  (Calendar/Timesheet) on the left and terminal typing log on the right.
//

import SwiftUI

struct TrackerHomeView: View {
    @State private var viewModel = TrackerViewModel()
    @State private var isFlipped = false
    @State private var terminalLines: [String] = []
    @State private var cursorVisible = true
    @State private var showCopiedToast = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ──
                GlassmorphismBG()

                // ── Main Layout ──
                HStack(alignment: .top, spacing: 24) {
                    // ═══ LEFT: Flip Container ═══
                    leftPanel(geo: geo)

                    // ═══ RIGHT: Terminal Log ═══
                    rightPanel(geo: geo)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

                // ── Copied Toast ──
                if showCopiedToast {
                    copiedToast
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -10)),
                            removal: .opacity
                        ))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startCursorBlink()
        }
        .onChange(of: viewModel.sessions) { _, _ in
            refreshTerminalLog()
        }
    }

    // MARK: - Left Panel (Card)

    private func leftPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Flip Button
            HStack {
                flipButton
                Spacer()
                if isFlipped {
                    copyButton
                }
            }

            // GlitchFlip Card
            GlitchFlipContainer(isFlipped: $isFlipped) {
                GlassCalendarView(viewModel: viewModel)
            } back: {
                TimeInputTableView(viewModel: viewModel)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: min(geo.size.width * 0.48, 460))
    }

    // MARK: - Right Panel (Terminal)

    private func rightPanel(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Terminal Header
            terminalHeader

            Divider().background(Color.white.opacity(0.06))

            // Terminal Body
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(terminalLines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundColor(terminalLineColor(line))
                                .id(idx)
                        }

                        // Blinking cursor
                        HStack(spacing: 0) {
                            Text("> ")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(NeoTokyo.terminalGreen.opacity(0.6))
                            Rectangle()
                                .fill(NeoTokyo.terminalGreen)
                                .frame(width: 8, height: 16)
                                .opacity(cursorVisible ? 0.8 : 0)
                        }
                        .id("cursor")
                    }
                    .padding(16)
                }
                .onChange(of: terminalLines.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("cursor", anchor: .bottom)
                    }
                }
            }
        }
        .glassCard(cornerRadius: 20, strokeOpacity: 0.06)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Terminal Header

    private var terminalHeader: some View {
        HStack(spacing: 8) {
            // Traffic lights
            HStack(spacing: 6) {
                Circle().fill(NeoTokyo.laserRed.opacity(0.7)).frame(width: 10, height: 10)
                Circle().fill(NeoTokyo.laserGold.opacity(0.7)).frame(width: 10, height: 10)
                Circle().fill(NeoTokyo.terminalGreen.opacity(0.7)).frame(width: 10, height: 10)
            }

            Spacer()

            Text("HC://TERMINAL")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            Spacer()

            // Session count
            Text("[\(viewModel.sessions.count)]")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(NeoTokyo.neonCyan.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Buttons

    private var flipButton: some View {
        Button {
            isFlipped.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isFlipped ? "calendar" : "tablecells")
                    .font(.system(size: 12, weight: .bold))
                Text(isFlipped ? "CALENDAR" : "TIMESHEET")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundColor(NeoTokyo.neonCyan)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(NeoTokyo.neonCyan.opacity(0.06))
                    .overlay(Capsule().strokeBorder(NeoTokyo.neonCyan.opacity(0.15), lineWidth: 0.5))
            )
        }
    }

    private var copyButton: some View {
        Button {
            let report = viewModel.generateReportString()
            guard !report.isEmpty else { return }
            ClipboardManager.copy(report)
            withAnimation(.spring(response: 0.3)) { showCopiedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { showCopiedToast = false }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc").font(.system(size: 11))
                Text("COPY LOG").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
            }
            .foregroundColor(NeoTokyo.terminalGreen)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                Capsule().fill(NeoTokyo.terminalGreen.opacity(0.06))
                    .overlay(Capsule().strokeBorder(NeoTokyo.terminalGreen.opacity(0.15), lineWidth: 0.5))
            )
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(NeoTokyo.terminalGreen)
                Text("COPIED TO CLIPBOARD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(NeoTokyo.terminalGreen)
                    .tracking(1.5)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(NeoTokyo.vantablack.opacity(0.9))
                    .overlay(Capsule().strokeBorder(NeoTokyo.terminalGreen.opacity(0.3), lineWidth: 0.5))
                    .shadow(color: NeoTokyo.terminalGreen.opacity(0.2), radius: 20)
            )
            .padding(.top, 20)
            Spacer()
        }
    }

    // MARK: - Terminal Logic

    private func refreshTerminalLog() {
        var lines: [String] = []
        lines.append("┌─────────────────────────────────┐")
        lines.append("│  HC WORK SESSION LOG             │")
        lines.append("└─────────────────────────────────┘")
        lines.append("")

        if viewModel.sessions.isEmpty {
            lines.append("  [IDLE] No sessions recorded.")
            lines.append("  Select dates from the calendar.")
        } else {
            let df = DateFormatter()
            df.dateFormat = "d MMM"

            for session in viewModel.sessions {
                let dateStr = df.string(from: session.date)
                lines.append("  \(dateStr): \(session.startTimeString) to \(session.endTimeString)")
                lines.append("  Hour: \(session.durationString)")
                lines.append("")
            }

            lines.append("  ──────────────────────────────")
            lines.append("  Total Hours: \(viewModel.calculateTotalHours())")
        }

        terminalLines = lines
    }

    private func terminalLineColor(_ line: String) -> Color {
        if line.contains("Total Hours") { return NeoTokyo.neonCyan }
        if line.contains("Hour:") { return NeoTokyo.neonPurple.opacity(0.7) }
        if line.contains("IDLE") { return .white.opacity(0.25) }
        if line.contains("───") || line.contains("┌") || line.contains("└") || line.contains("│") {
            return NeoTokyo.neonCyan.opacity(0.3)
        }
        return NeoTokyo.terminalGreen.opacity(0.75)
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
        refreshTerminalLog()
    }
}

#Preview {
    TrackerHomeView()
}
