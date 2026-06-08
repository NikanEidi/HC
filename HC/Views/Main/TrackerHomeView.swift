//
//  TrackerHomeView.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  Root composition — Asymmetric split layout:                  ║
//  ║    LEFT:  GlitchFlipContainer (Calendar <-> Timesheet)       ║
//  ║    RIGHT: ANSI-styled Dragon Terminal with live data feed    ║
//  ║                                                               ║
//  ║  Forge palette. Apple Pencil hover. Full logic wired.        ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

struct TrackerHomeView: View {

    @State private var vm = TrackerViewModel()
    @State private var flipped = false
    @State private var lines: [TLine] = []
    @State private var blink = true
    @State private var toast = false
    @State private var uptime = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GlassmorphismBG()

                HStack(alignment: .top, spacing: 30) {
                    cardPanel(geo).frame(width: min(geo.size.width * 0.45, 490))
                    terminal.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)

                if toast { toastBanner.transition(.scale(scale: 0.92).combined(with: .opacity)) }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { boot() }
        .onChange(of: vm.sessions) { _, _ in render() }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Left Panel (Card)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func cardPanel(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) { flipBtn; Spacer(); if flipped { exportBtn }; pill }
            GlitchFlipContainer(isFlipped: $flipped) {
                GlassCalendarView(viewModel: vm)
            } back: {
                TimeInputTableView(viewModel: vm)
            }.frame(maxHeight: .infinity)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Right Panel (Terminal)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            statusBar
            Rectangle().fill(Forge.cipher.opacity(0.08)).frame(height: 0.5)
            body_
        }
        .glassCard(radius: 16, border: 0.06, glow: Forge.cipher)
    }

    // ── Title Bar ──

    private var titleBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Forge.crimson).frame(width: 11, height: 11)
                Circle().fill(Forge.ember).frame(width: 11, height: 11)
                Circle().fill(Forge.jade).frame(width: 11, height: 11)
            }.padding(.leading, 18)
            Spacer()
            Text("HC://DRAGON-TERMINAL v2.0")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Forge.steel.opacity(0.45)).tracking(1.5)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Forge.jade).frame(width: 6, height: 6).shadow(color: Forge.jade.opacity(0.7), radius: 4)
                Text("LIVE").font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(Forge.jade.opacity(0.55)).tracking(2)
            }.padding(.trailing, 18)
        }
        .padding(.vertical, 11).background(Forge.frost.opacity(0.012))
    }

    // ── Status Bar ──

    private var statusBar: some View {
        HStack(spacing: 0) {
            tag("SYS", "ONLINE", Forge.jade)
            sep; tag("SESS", "\(vm.sessions.count)", Forge.cipher)
            sep; tag("HRS", vm.sessions.isEmpty ? "--:--" : vm.calculateTotalHours(), Forge.arcane)
            sep; tag("UP", fmtUp(), Forge.steel.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 8).background(Forge.frost.opacity(0.008))
    }

    private func tag(_ l: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Text(l).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.3)).tracking(1)
            Text(v).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(c)
        }
    }
    private var sep: some View {
        Text("|").font(.system(size: 10, design: .monospaced)).foregroundColor(Forge.frost.opacity(0.06)).padding(.horizontal, 10)
    }

    // ── Body ──

    private var body_: some View {
        ScrollViewReader { px in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, l in row(l).id(i) }
                    prompt.id("cur")
                }.padding(.horizontal, 20).padding(.vertical, 16)
            }
            .onChange(of: lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { px.scrollTo("cur", anchor: .bottom) }
            }
        }
    }

    @ViewBuilder private func row(_ l: TLine) -> some View {
        HStack(spacing: 0) {
            if l.ln {
                Text(String(format: "%3d", l.n)).foregroundColor(Forge.steel.opacity(0.08)).padding(.trailing, 10)
            }
            Text(l.t).foregroundColor(l.c)
        }
        .font(.system(size: 12, weight: l.b ? .bold : .regular, design: .monospaced)).padding(.vertical, 0.5)
    }

    private var prompt: some View {
        HStack(spacing: 0) {
            Text("root@hc").foregroundColor(Forge.crimson.opacity(0.45))
            Text(":").foregroundColor(Forge.steel.opacity(0.3))
            Text("~").foregroundColor(Forge.cipher.opacity(0.45))
            Text("$ ").foregroundColor(Forge.steel.opacity(0.3))
            Rectangle().fill(Forge.jade).frame(width: 8, height: 14).opacity(blink ? 0.85 : 0)
        }.font(.system(size: 12, weight: .medium, design: .monospaced))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Buttons
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var flipBtn: some View {
        Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); flipped.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: flipped ? "calendar" : "tablecells").font(.system(size: 13, weight: .bold))
                Text(flipped ? "CALENDAR" : "TIMESHEET")
                    .font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
            }
            .foregroundColor(Forge.cipher)
            .padding(.horizontal, 22).padding(.vertical, 13)
            .background(Capsule().fill(Forge.cipher.opacity(0.04))
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [Forge.cipher.opacity(0.20), Forge.cipher.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                .shadow(color: Forge.cipher.opacity(0.08), radius: 14))
        }.hoverEffect(.lift)
    }

    private var exportBtn: some View {
        Button {
            guard !vm.generateReportString().isEmpty else { return }
            ClipboardManager.copy(vm.generateReportString())
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(.easeOut) { toast = false } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill").font(.system(size: 11))
                Text("EXPORT").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
            }
            .foregroundColor(Forge.jade)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Capsule().fill(Forge.jade.opacity(0.04))
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [Forge.jade.opacity(0.20), Forge.jade.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                .shadow(color: Forge.jade.opacity(0.08), radius: 14))
        }.hoverEffect(.lift)
    }

    private var pill: some View {
        HStack(spacing: 5) {
            Circle().fill(vm.sessions.isEmpty ? Forge.crimson : Forge.jade).frame(width: 5, height: 5)
                .shadow(color: (vm.sessions.isEmpty ? Forge.crimson : Forge.jade).opacity(0.5), radius: 3)
            Text(vm.sessions.isEmpty ? "IDLE" : "\(vm.sessions.count) ACTIVE")
                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.35)).tracking(1.5)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Forge.frost.opacity(0.015)).overlay(Capsule().strokeBorder(Forge.frost.opacity(0.04), lineWidth: 0.5)))
    }

    // MARK: - Toast

    private var toastBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Text("[OK]").font(.system(size: 12, weight: .black, design: .monospaced)).foregroundColor(Forge.jade)
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPORTED TO CLIPBOARD")
                        .font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(Forge.jade).tracking(1.5)
                    Text("Report ready to paste")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(Forge.steel.opacity(0.4))
                }
            }
            .padding(.horizontal, 26).padding(.vertical, 16)
            .glassCard(radius: 28, border: 0.06, glow: Forge.jade)
            .overlay(Capsule().strokeBorder(Forge.jade.opacity(0.15), lineWidth: 0.5))
            .shadow(color: Forge.jade.opacity(0.12), radius: 25)
            .padding(.top, 28)
            Spacer()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Terminal Renderer
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func render() {
        var l: [TLine] = []; var n = 1
        let dragon = [
            "                 \\                    /",
            "      _    /\\     \\\\               / /    /\\",
            "     / \\  / /\\     \\\\             / /    / /\\",
            "    /   \\/ /  \\     \\\\           / /    /  \\ \\",
            "   / /\\  /    _\\    \\\\         / /    _/   /\\ \\",
            "  / /  \\/ /\\ / /     \\\\       / /    / /\\ /  \\ \\",
            " / /   /  / / /       \\\\     / /    / / / \\   \\ \\",
            "/ /   / _/ / /         \\\\___/ /    / / /   \\   \\ \\",
            "\\/   / / \\/ /          /     /    / / /     \\  / /",
            "    / /   / /          \\   \\/    / / /      / / /",
            "   / /   / /            \\  /    / / /      / / /",
            "  / /   / /              \\/    /_/_/      /_/ /",
            "  \\/   /_/               /    (____\\     (___/",
            "       (_)              /",
            "                      /"
        ]

        for a in dragon { l.append(TLine(n: n, t: a, c: Forge.cipher.opacity(0.25), ln: true)); n += 1 }
        l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        l.append(TLine(n: n, t: "  [SYS] Midnight Forge v2.0 -- \(df.string(from: Date()))", c: Forge.steel.opacity(0.25), ln: true)); n += 1
        for mod in ["Calendar engine", "Haptic subsystem", "Clipboard bridge", "Pencil input", "Glitch renderer"] {
            let pad = String(repeating: ".", count: 30 - mod.count)
            l.append(TLine(n: n, t: "  [SYS] \(mod) \(pad) [OK]", c: Forge.jade.opacity(0.35), ln: true)); n += 1
        }
        l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1

        l.append(TLine(n: n, t: "  +================================================+", c: Forge.cipher.opacity(0.18), ln: true)); n += 1
        l.append(TLine(n: n, t: "  |            WORK SESSION REPORT                  |", c: Forge.cipher.opacity(0.45), b: true, ln: true)); n += 1
        l.append(TLine(n: n, t: "  +================================================+", c: Forge.cipher.opacity(0.18), ln: true)); n += 1
        l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1

        if vm.sessions.isEmpty {
            l.append(TLine(n: n, t: "  [!] WARNING: No sessions recorded", c: Forge.ember.opacity(0.45), ln: true)); n += 1
            l.append(TLine(n: n, t: "  --> Select dates from the calendar", c: Forge.steel.opacity(0.2), ln: true))
        } else {
            let sdf = DateFormatter(); sdf.dateFormat = "d MMM"
            for (i, s) in vm.sessions.enumerated() {
                let w = vm.isWeekend(s.date); let tag = w ? "[WE]" : "[WD]"
                l.append(TLine(n: n, t: "  \(tag) [\(String(format: "%02d", i+1))] \(sdf.string(from: s.date)): \(s.startTimeString) --> \(s.endTimeString)",
                               c: w ? Forge.ember.opacity(0.8) : Forge.jade.opacity(0.85), b: true, ln: true)); n += 1
                l.append(TLine(n: n, t: "        Hour: \(s.durationString)", c: Forge.arcane.opacity(0.6), ln: true)); n += 1
            }
            l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1
            l.append(TLine(n: n, t: "  +------------------------------------------------+", c: Forge.cipher.opacity(0.12), ln: true)); n += 1
            l.append(TLine(n: n, t: "  | >>> Total Hours: \(vm.calculateTotalHours())", c: Forge.cipher, b: true, ln: true)); n += 1
            l.append(TLine(n: n, t: "  +------------------------------------------------+", c: Forge.cipher.opacity(0.12), ln: true))
        }
        lines = l
    }

    // MARK: - Boot Sequence

    private func boot() {
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in blink.toggle() }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in uptime += 1 }
        render()
    }

    private func fmtUp() -> String { String(format: "%02d:%02d", uptime / 60, uptime % 60) }
}

/// A single terminal output line with metadata for rendering.
struct TLine { let n: Int; let t: String; let c: Color; var b: Bool = false; var ln: Bool = true }

#Preview { TrackerHomeView() }
