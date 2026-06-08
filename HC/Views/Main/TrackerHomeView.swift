//
//  TrackerHomeView.swift
//  HC
//
//  Root — asymmetric layout, ANSI terminal, dragon motif,
//  premium buttons, and glitch flip container.
//

import SwiftUI

struct TrackerHomeView: View {
    @State private var viewModel = TrackerViewModel()
    @State private var isFlipped = false
    @State private var terminalLines: [TerminalLine] = []
    @State private var cursorVisible = true
    @State private var showCopiedToast = false
    @State private var bootComplete = false
    @State private var uptimeSeconds = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GlassmorphismBG()

                // ── Main Layout ──
                HStack(alignment: .top, spacing: 28) {
                    leftPanel(geo: geo)
                    rightPanel(geo: geo)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)

                // ── Toast ──
                if showCopiedToast {
                    copiedToast
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startSystems()
        }
        .onChange(of: viewModel.sessions) { _, _ in
            refreshTerminalLog()
        }
    }

    // MARK: - Left Panel

    private func leftPanel(geo: GeometryProxy) -> some View {
        VStack(spacing: 18) {
            // ── Top Bar ──
            HStack(spacing: 12) {
                flipButton
                Spacer()
                if isFlipped { copyButton }
                statusPill
            }

            // ── Card ──
            GlitchFlipContainer(isFlipped: $isFlipped) {
                GlassCalendarView(viewModel: viewModel)
            } back: {
                TimeInputTableView(viewModel: viewModel)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: min(geo.size.width * 0.46, 480))
    }

    // MARK: - Right Panel (ANSI Terminal)

    private func rightPanel(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            terminalTitleBar
            terminalStatusBar
            Divider().background(NeoTokyo.neonCyan.opacity(0.1))
            terminalBody
        }
        .glassCard(cornerRadius: 18, strokeOpacity: 0.08, glowColor: NeoTokyo.neonCyan)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Terminal Title Bar

    private var terminalTitleBar: some View {
        HStack(spacing: 0) {
            // Traffic lights
            HStack(spacing: 7) {
                Circle().fill(NeoTokyo.laserRed).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
                Circle().fill(NeoTokyo.laserGold).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
                Circle().fill(NeoTokyo.terminalGreen).frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
            }
            .padding(.leading, 16)

            Spacer()

            // Title
            HStack(spacing: 6) {
                Text("⬡")
                    .font(.system(size: 10))
                    .foregroundColor(NeoTokyo.neonCyan.opacity(0.5))
                Text("HC://DRAGON-TERMINAL v1.0")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.5)
            }

            Spacer()

            // Live indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(NeoTokyo.terminalGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: NeoTokyo.terminalGreen.opacity(0.8), radius: 4)
                Text("LIVE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(NeoTokyo.terminalGreen.opacity(0.6))
                    .tracking(2)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.015))
    }

    // MARK: - Terminal Status Bar

    private var terminalStatusBar: some View {
        HStack(spacing: 0) {
            statusTag(label: "SYS", value: "ONLINE", color: NeoTokyo.terminalGreen)
            dividerBar
            statusTag(label: "SESS", value: "\(viewModel.sessions.count)", color: NeoTokyo.neonCyan)
            dividerBar
            statusTag(label: "TOTAL", value: viewModel.sessions.isEmpty ? "--:--" : viewModel.calculateTotalHours(), color: NeoTokyo.neonPurple)
            dividerBar
            statusTag(label: "UP", value: formatUptime(), color: .white.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.01))
    }

    private func statusTag(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
                .tracking(1)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private var dividerBar: some View {
        Text("│")
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.08))
            .padding(.horizontal, 8)
    }

    // MARK: - Terminal Body

    private var terminalBody: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(terminalLines.enumerated()), id: \.offset) { idx, line in
                        terminalRow(line)
                            .id(idx)
                    }

                    // Blinking cursor
                    HStack(spacing: 0) {
                        Text("root@hc")
                            .foregroundColor(NeoTokyo.laserRed.opacity(0.5))
                        Text(":")
                            .foregroundColor(.white.opacity(0.3))
                        Text("~")
                            .foregroundColor(NeoTokyo.neonCyan.opacity(0.5))
                        Text("$ ")
                            .foregroundColor(.white.opacity(0.3))
                        Rectangle()
                            .fill(NeoTokyo.terminalGreen)
                            .frame(width: 8, height: 14)
                            .opacity(cursorVisible ? 0.9 : 0)
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .id("cursor")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .onChange(of: terminalLines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("cursor", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func terminalRow(_ line: TerminalLine) -> some View {
        HStack(spacing: 0) {
            if line.showLineNumber {
                Text(String(format: "%3d", line.lineNum))
                    .foregroundColor(.white.opacity(0.10))
                    .padding(.trailing, 8)
            }
            Text(line.content)
                .foregroundColor(line.color)
        }
        .font(.system(size: 12, weight: line.bold ? .bold : .regular, design: .monospaced))
        .padding(.vertical, 0.5)
    }

    // MARK: - Buttons

    private var flipButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isFlipped.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isFlipped ? "calendar" : "tablecells")
                    .font(.system(size: 13, weight: .bold))
                Text(isFlipped ? "CALENDAR" : "TIMESHEET")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            .foregroundColor(NeoTokyo.neonCyan)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(NeoTokyo.neonCyan.opacity(0.05))
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [NeoTokyo.neonCyan.opacity(0.25), NeoTokyo.neonCyan.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.6
                        )
                    )
                    .shadow(color: NeoTokyo.neonCyan.opacity(0.1), radius: 12)
            )
        }
    }

    private var copyButton: some View {
        Button {
            let report = viewModel.generateReportString()
            guard !report.isEmpty else { return }
            ClipboardManager.copy(report)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showCopiedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut) { showCopiedToast = false }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill").font(.system(size: 11))
                Text("EXPORT").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
            }
            .foregroundColor(NeoTokyo.terminalGreen)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(NeoTokyo.terminalGreen.opacity(0.05))
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(colors: [NeoTokyo.terminalGreen.opacity(0.25), NeoTokyo.terminalGreen.opacity(0.05)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.6
                        )
                    )
                    .shadow(color: NeoTokyo.terminalGreen.opacity(0.1), radius: 12)
            )
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(viewModel.sessions.isEmpty ? NeoTokyo.laserRed : NeoTokyo.terminalGreen)
                .frame(width: 5, height: 5)
                .shadow(color: (viewModel.sessions.isEmpty ? NeoTokyo.laserRed : NeoTokyo.terminalGreen).opacity(0.6), radius: 3)
            Text(viewModel.sessions.isEmpty ? "IDLE" : "\(viewModel.sessions.count) ACTIVE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.02))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5))
        )
    }

    // MARK: - Toast

    private var copiedToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(NeoTokyo.terminalGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPORTED TO CLIPBOARD")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(NeoTokyo.terminalGreen)
                        .tracking(1.5)
                    Text("Report ready to paste")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .glassCard(cornerRadius: 30, strokeOpacity: 0.08, glowColor: NeoTokyo.terminalGreen)
            .overlay(
                Capsule().strokeBorder(NeoTokyo.terminalGreen.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: NeoTokyo.terminalGreen.opacity(0.15), radius: 30)
            .padding(.top, 24)
            Spacer()
        }
    }

    // MARK: - Terminal Content Builder

    private func refreshTerminalLog() {
        var lines: [TerminalLine] = []
        var num = 1

        // Dragon ASCII header
        let dragonArt = [
            "            /\\_/\\",
            "           ( o.o )",
            "            > ^ <     ╔══════════════════════════════════╗",
            "           /|   |\\    ║   🐉  HC DRAGON TERMINAL  v1.0  ║",
            "          (_|   |_)   ╚══════════════════════════════════╝"
        ]

        for art in dragonArt {
            lines.append(TerminalLine(lineNum: num, content: art, color: NeoTokyo.neonCyan.opacity(0.4), bold: false, showLineNumber: true))
            num += 1
        }

        lines.append(TerminalLine(lineNum: num, content: "", color: .clear, showLineNumber: false)); num += 1

        // System info
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lines.append(TerminalLine(lineNum: num, content: "  [SYS] Initialized at \(df.string(from: Date()))", color: .white.opacity(0.2), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "  [SYS] Calendar engine .............. ✓ OK", color: NeoTokyo.terminalGreen.opacity(0.4), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "  [SYS] Haptic subsystem ............. ✓ OK", color: NeoTokyo.terminalGreen.opacity(0.4), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "  [SYS] Clipboard bridge ............. ✓ OK", color: NeoTokyo.terminalGreen.opacity(0.4), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "", color: .clear, showLineNumber: false)); num += 1

        // Separator
        lines.append(TerminalLine(lineNum: num, content: "  ╔══════════════════════════════════════════╗", color: NeoTokyo.neonCyan.opacity(0.2), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "  ║          WORK SESSION REPORT             ║", color: NeoTokyo.neonCyan.opacity(0.5), bold: true, showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "  ╚══════════════════════════════════════════╝", color: NeoTokyo.neonCyan.opacity(0.2), showLineNumber: true)); num += 1
        lines.append(TerminalLine(lineNum: num, content: "", color: .clear, showLineNumber: false)); num += 1

        if viewModel.sessions.isEmpty {
            lines.append(TerminalLine(lineNum: num, content: "  ⚠ [IDLE] No sessions recorded", color: NeoTokyo.laserGold.opacity(0.5), showLineNumber: true)); num += 1
            lines.append(TerminalLine(lineNum: num, content: "  → Select dates from the calendar to begin", color: .white.opacity(0.2), showLineNumber: true)); num += 1
        } else {
            let sessionDF = DateFormatter()
            sessionDF.dateFormat = "d MMM"

            for (i, session) in viewModel.sessions.enumerated() {
                let dateStr = sessionDF.string(from: session.date)
                let isWknd = viewModel.isWeekend(session.date)
                let marker = isWknd ? "🔴" : "🟢"

                lines.append(TerminalLine(lineNum: num, content: "  \(marker) [\(String(format: "%02d", i + 1))] \(dateStr): \(session.startTimeString) → \(session.endTimeString)",
                                          color: isWknd ? NeoTokyo.laserGold.opacity(0.8) : NeoTokyo.terminalGreen.opacity(0.85),
                                          bold: true, showLineNumber: true)); num += 1
                lines.append(TerminalLine(lineNum: num, content: "       Hour: \(session.durationString)",
                                          color: NeoTokyo.neonPurple.opacity(0.65), showLineNumber: true)); num += 1
            }

            lines.append(TerminalLine(lineNum: num, content: "", color: .clear, showLineNumber: false)); num += 1
            lines.append(TerminalLine(lineNum: num, content: "  ──────────────────────────────────────────", color: NeoTokyo.neonCyan.opacity(0.15), showLineNumber: true)); num += 1
            lines.append(TerminalLine(lineNum: num, content: "  ★ Total Hours: \(viewModel.calculateTotalHours())",
                                      color: NeoTokyo.neonCyan, bold: true, showLineNumber: true)); num += 1
            lines.append(TerminalLine(lineNum: num, content: "  ──────────────────────────────────────────", color: NeoTokyo.neonCyan.opacity(0.15), showLineNumber: true)); num += 1
        }

        terminalLines = lines
    }

    // MARK: - Systems

    private func startSystems() {
        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
        // Uptime counter
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            uptimeSeconds += 1
        }
        refreshTerminalLog()
    }

    private func formatUptime() -> String {
        let m = uptimeSeconds / 60
        let s = uptimeSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Terminal Line Model

struct TerminalLine {
    let lineNum: Int
    let content: String
    let color: Color
    var bold: Bool = false
    var showLineNumber: Bool = true
}

#Preview {
    TrackerHomeView()
}
