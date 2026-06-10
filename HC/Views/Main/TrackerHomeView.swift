//
//  TrackerHomeView.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  ROOT COMPOSITION — Asymmetric Split Layout                    ║
//  ║                                                               ║
//  ║  Layout:                                                      ║
//  ║    LEFT  — GlitchFlipContainer (Calendar ↔ Timesheet)         ║
//  ║    RIGHT — ANSI-styled Dragon Terminal with live data feed    ║
//  ║                                                               ║
//  ║  Subsystems:                                                   ║
//  ║    • GestureCursorOverlay: cursor rendering + hit-testing      ║
//  ║    • TLine/TLineType: terminal line data models               ║
//  ║    • PreferenceKey consumers: slider/calendar/button frames    ║
//  ║                                                               ║
//  ║  Forge palette. Apple Pencil hover. Full gesture wiring.      ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

/// The root view of HC — orchestrates layout, gesture wiring,
/// terminal rendering, and all PreferenceKey consumption.
struct TrackerHomeView: View {

    // ── Core State ───────────────────────────────────────────

    /// The shared ViewModel ("Brain") driving all app state.
    @State private var vm = TrackerViewModel()

    /// Continuous AI Voice Assistant processing neural speech matrix.
    @StateObject private var voiceManager = VoiceCommandManager()

    /// Front-camera gesture engine for hand tracking.
    @State private var gesture = HandGestureManager()

    /// Whether the card panel is showing the back (Timesheet) face.
    @State private var flipped = false

    /// Terminal line buffer for the right-side dragon console.
    @State private var lines: [TLine] = []

    /// Cursor blink state for the terminal prompt.
    @State private var blink = true

    /// Clipboard copy success toast visibility flag.
    @State private var toast = false

    /// Running uptime counter in seconds (displayed in terminal).
    @State private var uptime = 0

    /// Dragon ASCII art pulse value for animated eye/flame glow.
    @State private var dragonPulse: Double = 0.0

    // ── Gesture-Driven State ─────────────────────────────────

    /// Whether the COPY button is currently glowing from gesture hover.
    @State private var isCopyButtonGlowing = false

    /// Calendar date currently being hovered by the air-gesture cursor.
    @State private var gestureHoveredDate: Date? = nil

    /// ID of the tappable element currently under the gesture cursor.
    @State private var hoveredElementID: String? = nil

    /// Global frame of the COPY button (from CopyButtonFrameKey).
    @State private var copyButtonFrame: CGRect = .zero

    /// Global frame of the calendar grid (from CalendarGridFrameKey).
    @State private var calendarGridFrame: CGRect = .zero

    /// Global frames of all visible time sliders (from SliderFramesKey).
    @State private var sliderFrames: [SliderFrameInfo] = []

    /// Global frames of all tappable elements (from TappableFramesKey).
    @State private var tappableFrames: [TappableElement] = []

    /// Click ripple animation trigger for the gesture cursor.
    @State private var clickRipple = false

    /// Whether the front camera capture session is currently active.
    @State private var cameraActive = false

    /// Index to programmatically scroll the timesheet list to.
    @State private var scrollTargetIndex: Int? = nil

    /// Task to debounce / coalesce terminal re-renders across frame updates
    @State private var renderTask: Task<Void, Never>? = nil
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

                // ━━━ High-Frequency Gesture Cursor & Hover Overlay ━━━
                GestureCursorOverlay(
                    gesture: gesture,
                    windowSize: geo.size,
                    gestureHoveredDate: $gestureHoveredDate,
                    hoveredElementID: $hoveredElementID,
                    isCopyButtonGlowing: $isCopyButtonGlowing,
                    tappableFrames: tappableFrames,
                    copyButtonFrame: copyButtonFrame,
                    sliderFrames: sliderFrames,
                    flipped: flipped,
                    scrollTargetIndex: $scrollTargetIndex,
                    sessionCount: vm.sessions.count,
                    onAction: { dispatchTappableAction($0) },
                    onToggleDate: { vm.toggleDate($0) },
                    onCopy: {
                        ClipboardManager.copy(vm.generateReportString())
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut) { toast = false }
                        }
                    },
                    resolveDate: { index in
                        guard index >= 0, index < vm.daysInMonth.count else { return nil }
                        return vm.daysInMonth[index]
                    },
                    startMinutesBinding: { vm.startMinutesBinding(for: $0) },
                    endMinutesBinding: { vm.endMinutesBinding(for: $0) }
                )
            }
            .onAppear {
                boot()
                voiceManager.setup(viewModel: vm)
                voiceManager.onActivateCamera = {
                    if !cameraActive {
                        cameraActive = true
                        gesture.startSession()
                    }
                }
                voiceManager.onDeactivateCamera = {
                    if cameraActive {
                        cameraActive = false
                        gesture.stopSession()
                    }
                }
                voiceManager.onSwitchView = { showTimesheet in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        flipped = showTimesheet
                    }
                }
                // Camera starts disabled by default. User must toggle it ON to start hand gestures.
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    dragonPulse = 1.0
                }
            }
            .onDisappear { gesture.stopSession() }
            .onChange(of: vm.sessions) { _, _ in queueRender() }
            .onChange(of: gestureHoveredDate) { _, newDate in
                voiceManager.hoveredDate = newDate
            }
            .onChange(of: voiceManager.liveTranscript) { _, _ in queueRender() }
            .onChange(of: voiceManager.systemStatus) { _, _ in queueRender() }
            .onChange(of: voiceManager.voiceLogs) { _, _ in queueRender() }
            // ── Gesture: Card flip ──
            .onChange(of: gesture.shouldSwitchView) { _, new in
                if new {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { flipped.toggle() }
                }
            }
            // ── Collect preference frames asynchronously to prevent layout loops ──
            .onPreferenceChange(CopyButtonFrameKey.self) { newFrame in
                if copyButtonFrame != newFrame {
                    DispatchQueue.main.async {
                        self.copyButtonFrame = newFrame
                    }
                }
            }
            .onPreferenceChange(CalendarGridFrameKey.self) { newFrame in
                if calendarGridFrame != newFrame {
                    DispatchQueue.main.async {
                        self.calendarGridFrame = newFrame
                    }
                }
            }
            .onPreferenceChange(SliderFramesKey.self) { newFrames in
                if sliderFrames != newFrames {
                    DispatchQueue.main.async {
                        self.sliderFrames = newFrames
                    }
                }
            }
            .onPreferenceChange(TappableFramesKey.self) { newFrames in
                if tappableFrames != newFrames {
                    DispatchQueue.main.async {
                        self.tappableFrames = newFrames
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Left Panel (Card)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func cardPanel(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) { flipBtn; Spacer(); if flipped { exportBtn }; cameraToggleBtn; pill }
            GlitchFlipContainer(isFlipped: $flipped) {
                GlassCalendarView(viewModel: vm, gestureHoveredDate: gestureHoveredDate)
            } back: {
                TimeInputTableView(viewModel: vm, isCopyButtonGlowing: isCopyButtonGlowing, scrollTargetIndex: $scrollTargetIndex)
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
            switch l.type {
            case .normal:
                Text(l.t).foregroundColor(l.c)
            case .dragonBorder:
                DragonArtRenderer.tokenizeBorderLine(l.t)
            case .dragonContent(let rowIdx):
                DragonArtRenderer.tokenizeDragonLine(l.t, row: rowIdx, pulse: dragonPulse)
            }
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
                Image(systemName: flipped ? "calendar" : "tablecells")
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Forge.cipher)
                    .symbolEffect(.bounce, value: flipped)
                Text(flipped ? "CALENDAR" : "TIMESHEET")
                    .font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(Forge.cipher)
            .padding(.horizontal, 22).padding(.vertical, 13)
            .background(Capsule().fill(Forge.cipher.opacity(0.04))
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [Forge.cipher.opacity(0.20), Forge.cipher.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                .shadow(color: Forge.cipher.opacity(0.12), radius: 14))
        }
        .hoverEffect(.lift)
        .reportTappableFrame(id: "flipBtn")
    }

    private var exportBtn: some View {
        Button {
            guard !vm.generateReportString().isEmpty else { return }
            ClipboardManager.copy(vm.generateReportString())
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(.easeOut) { toast = false } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 11))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Forge.jade, Forge.cipher)
                    .symbolEffect(.bounce, value: toast)
                Text("EXPORT").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(Forge.jade)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(Capsule().fill(Forge.jade.opacity(0.04))
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [Forge.jade.opacity(0.20), Forge.jade.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                .shadow(color: Forge.jade.opacity(0.12), radius: 14))
        }
        .hoverEffect(.lift)
        .reportTappableFrame(id: "exportBtn")
    }

    private var cameraToggleBtn: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            cameraActive.toggle()
            if cameraActive {
                gesture.startSession()
            } else {
                gesture.stopSession()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: cameraActive ? "video.fill" : "video.slash.fill")
                    .font(.system(size: 11, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(cameraActive ? Forge.jade : Forge.crimson)
                    .symbolEffect(.pulse, options: .repeating, isActive: cameraActive)
                Text(cameraActive ? "CAM ON" : "CAM OFF")
                    .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(1.5)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(cameraActive ? Forge.jade : Forge.crimson)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(Capsule().fill((cameraActive ? Forge.jade : Forge.crimson).opacity(0.04))
                .overlay(Capsule().strokeBorder(
                    (cameraActive ? Forge.jade : Forge.crimson).opacity(0.15), lineWidth: 0.5))
                .shadow(color: (cameraActive ? Forge.jade : Forge.crimson).opacity(0.12), radius: 14))
        }
        .hoverEffect(.lift)
        .reportTappableFrame(id: "cameraToggleBtn")
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

    private func queueRender() {
        renderTask?.cancel()
        renderTask = Task { @MainActor in
            do {
                // Coalesce updates by sleeping for 30ms (30,000,000 ns)
                try await Task.sleep(nanoseconds: 30_000_000)
                guard !Task.isCancelled else { return }
                render()
            } catch {}
        }
    }

    private func render() {
        var l: [TLine] = []; var n = 1
        let dragon: [String] = [
            "  +--------------------------------------------------------+",
            "  | [SYSTEM: MIDNIGHT_DRAGON]                 [SECTOR: 09] |",
            "  +--------------------------------------------------------+",
            "  |                                                        |",
            "  |               _===~_  _~===_                           |",
            "  |         _--^^#####//     \\#####^^--_                   |",
            "  |      _-^##########// ( ) \\##########^-_                |",
            "  |     -############// |\\^^/| \\############-              |",
            "  |   _/############//  (o::o)  \\############\\_            |",
            "  |  /#############((    \\//    ))#############\\           |",
            "  | -###############\\\\  (    )  //###############-         |",
            "  |-#################\\\\ / VV \\ //#################-        |",
            "  |-###################\\\\/    \\\\//###################-     |",
            "  |_#/|##########/\\######(  /\\  )######/\\##########|\\#_    |",
            "  ||/  |#/\\#/\\#/\\  \\#/\\##\\ |  | /##/\\#/ /\\#/\\#/\\#|  \\|     |",
            "  |`   |/  V  V `   V \\#\\| |  | |/#/ V  ` V  V  \\|   `     |",
            "  |    `   `  `      ` / | |  | | \\ `     `  `   `         |",
            "  |                    (  | |  | |  )                      |",
            "  |                   __\\ | |  | | /__                     |",
            "  |                  (vvv(VVV)(VVV)vvv)                    |",
            "  |                                                        |",
            "  +--------------------------------------------------------+",
            "  | [BLUEPRINT v2.0]        [CORE_CORE]       [SCALE: 100] |",
            "  +--------------------------------------------------------+"
        ]

        let dragonColors: [Color] = [
            Forge.steel.opacity(0.3),
            Forge.jade.opacity(0.7),
            Forge.steel.opacity(0.3),
            .clear,
            Forge.supernova.opacity(0.55),
            Forge.supernova.opacity(0.55),
            Forge.arcane.opacity(0.50),
            Forge.arcane.opacity(0.50),
            Forge.arcane.opacity(0.45),
            Forge.cipher.opacity(0.45),
            Forge.cipher.opacity(0.40),
            Forge.cipher.opacity(0.40),
            Forge.cipher.opacity(0.35),
            Forge.jade.opacity(0.35),
            Forge.jade.opacity(0.30),
            Forge.ember.opacity(0.30),
            Forge.ember.opacity(0.25),
            Forge.ember.opacity(0.25),
            Forge.ember.opacity(0.20),
            Forge.ember.opacity(0.20),
            .clear,
            Forge.steel.opacity(0.3),
            Forge.cipher.opacity(0.6),
            Forge.steel.opacity(0.3)
        ]

        for (i, a) in dragon.enumerated() {
            let color = dragonColors[i]
            let type: TLineType
            if i >= 4 && i <= 19 {
                type = .dragonContent(row: i - 4)
            } else {
                type = .dragonBorder
            }
            l.append(TLine(n: n, t: a, c: color, ln: true, type: type))
            n += 1
        }
        l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        l.append(TLine(n: n, t: "  [SYS] Midnight Forge v2.0 -- \(df.string(from: Date()))", c: Forge.steel.opacity(0.25), ln: true)); n += 1
        for mod in ["Calendar engine", "Haptic subsystem", "Clipboard bridge", "Pencil input", "Glitch renderer"] {
            let pad = String(repeating: ".", count: 30 - mod.count)
            l.append(TLine(n: n, t: "  [SYS] \(mod) \(pad) [OK]", c: Forge.jade.opacity(0.35), ln: true)); n += 1
        }
        l.append(TLine(n: n, t: "", c: .clear, ln: false)); n += 1

        l.append(TLine(n: n, t: "  [SYS] Voice Assistant: \(voiceManager.systemStatus)", c: voiceManager.systemStatus == "ACTIVE" ? Forge.ember : Forge.steel.opacity(0.35), ln: true)); n += 1
        if !voiceManager.liveTranscript.isEmpty {
            l.append(TLine(n: n, t: "  [SYS] Transcript: \"\(voiceManager.liveTranscript)\"", c: Forge.supernova.opacity(0.85), ln: true)); n += 1
        }
        for log in voiceManager.voiceLogs {
            let color = log.contains("[OK]") ? Forge.jade
                      : log.contains("[ERR]") ? Forge.crimson
                      : Forge.steel.opacity(0.4)
            l.append(TLine(n: n, t: "  \(log)", c: color, ln: true)); n += 1
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

    // MARK: - Gesture Handlers

    /// Converts normalized finger position (0-1) → global coordinates (relative to window)
    /// and determines what the cursor is hovering over.


    /// Routes a tappable element ID to its corresponding action.
    private func dispatchTappableAction(_ id: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Handle calendar day cell selection
        if id.hasPrefix("date_") {
            if let indexStr = id.split(separator: "_").last,
               let index = Int(indexStr),
               index >= 0, index < vm.daysInMonth.count,
               let date = vm.daysInMonth[index] {
                vm.toggleDate(date)
            }
            return
        }

        switch id {
        case "cameraToggleBtn":
            cameraActive.toggle()
            if cameraActive {
                gesture.startSession()
            } else {
                gesture.stopSession()
            }
        case "flipBtn":
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { flipped.toggle() }
        case "exportBtn":
            guard !vm.generateReportString().isEmpty else { return }
            ClipboardManager.copy(vm.generateReportString())
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut) { toast = false }
            }
        case "prevMonth":
            vm.previousMonth()
        case "nextMonth":
            vm.nextMonth()
        case "copyBtn":
            ClipboardManager.copy(vm.generateReportString())
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut) { toast = false }
            }
        default:
            break
        }
    }

    // MARK: - Boot Sequence

    private func boot() {
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in blink.toggle() }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in uptime += 1 }
        queueRender()
    }

    private func fmtUp() -> String { String(format: "%02d:%02d", uptime / 60, uptime % 60) }
}

enum TLineType {
    case normal
    case dragonBorder
    case dragonContent(row: Int)
}

/// A single terminal output line with metadata for rendering.
struct TLine {
    let n: Int
    let t: String
    let c: Color
    var b: Bool = false
    var ln: Bool = true
    var type: TLineType = .normal
    
    init(n: Int, t: String, c: Color, b: Bool = false, ln: Bool = true, type: TLineType = .normal) {
        self.n = n
        self.t = t
        self.c = c
        self.b = b
        self.ln = ln
        self.type = type
    }
}

#Preview { TrackerHomeView() }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Gesture Cursor & Hover Overlay (High Frequency)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct GestureCursorOverlay: View {
    let gesture: HandGestureManager
    let windowSize: CGSize
    @Binding var gestureHoveredDate: Date?
    @Binding var hoveredElementID: String?
    @Binding var isCopyButtonGlowing: Bool

    let tappableFrames: [TappableElement]
    let copyButtonFrame: CGRect
    let sliderFrames: [SliderFrameInfo]
    let flipped: Bool
    @Binding var scrollTargetIndex: Int?
    let sessionCount: Int
    
    let onAction: (String) -> Void
    let onToggleDate: (Date) -> Void
    let onCopy: () -> Void
    let resolveDate: (Int) -> Date?
    
    let startMinutesBinding: (UUID) -> (get: () -> Int, set: (Int) -> Void)
    let endMinutesBinding: (UUID) -> (get: () -> Int, set: (Int) -> Void)

    @State private var clickRipple = false
    @State private var frozenCursorPosition: CGPoint? = nil
    @State private var activeDraggingSlider: SliderFrameInfo? = nil

    // Drag-to-scroll states
    @State private var isDraggingList = false
    @State private var dragListStartY: CGFloat = 0
    @State private var dragListStartScrollIndex: Int = 0

    var body: some View {
        ZStack {
            if gesture.isTracking {
                cursorView
            }
        }
        .onChange(of: gesture.isClickDetected) { _, new in
            if new { handleClick() }
        }
        .onChange(of: gesture.fingerPosition) { _, pos in
            updateHoverState(pos)
        }
        .onChange(of: gesture.isFingerDown) { _, isDown in
            let pos = gesture.fingerPosition
            let globalPos = CGPoint(
                x: pos.x * windowSize.width,
                y: pos.y * windowSize.height
            )
            if isDown {
                var hitSlider = false
                
                // Find the closest slider frame mathematically to avoid picking wrong from/to
                var closestSlider: SliderFrameInfo? = nil
                var minSliderDistY: CGFloat = CGFloat.infinity
                
                for slider in sliderFrames {
                    let dx = max(slider.frame.minX - globalPos.x, 0, globalPos.x - slider.frame.maxX)
                    let dy = max(slider.frame.minY - globalPos.y, 0, globalPos.y - slider.frame.maxY)
                    
                    // Very generous thresholds to make selection effortless:
                    // 150pt horizontally and 60pt vertically
                    if dx < 150.0 && dy < 60.0 {
                        if dy < minSliderDistY {
                            minSliderDistY = dy
                            closestSlider = slider
                        }
                    }
                }
                
                if let slider = closestSlider {
                    activeDraggingSlider = slider
                    hitSlider = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                // If not dragging a slider, lock the cursor position or drag-scroll the timesheet list
                if !hitSlider {
                    if flipped {
                        // Pinching down on the timesheet card area (left side) scrolls it
                        let cardWidth = min(windowSize.width * 0.45, 490.0)
                        if globalPos.x < cardWidth {
                            isDraggingList = true
                            dragListStartY = globalPos.y
                            dragListStartScrollIndex = scrollTargetIndex ?? 0
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.25)
                        } else {
                            frozenCursorPosition = globalPos
                        }
                    } else {
                        frozenCursorPosition = globalPos
                    }
                }
            } else {
                activeDraggingSlider = nil
                frozenCursorPosition = nil
                isDraggingList = false
            }
        }
    }

    @ViewBuilder private var cursorView: some View {
        let rawPos = CGPoint(
            x: gesture.fingerPosition.x * windowSize.width,
            y: gesture.fingerPosition.y * windowSize.height
        )
        let pos = frozenCursorPosition ?? rawPos
        let isHovering = hoveredElementID != nil || gestureHoveredDate != nil || isCopyButtonGlowing
        let accentColor = gesture.isFingerDown ? Forge.jade
                        : isHovering ? Forge.arcane
                        : Forge.cipher

        ZStack {
            // Outer ring — expands/contracts on pinch
            Circle()
                .stroke(accentColor.opacity(0.4), lineWidth: gesture.isFingerDown ? 2.0 : 1.2)
                .frame(
                    width: gesture.isFingerDown ? 14 : (isHovering ? 30 : 24),
                    height: gesture.isFingerDown ? 14 : (isHovering ? 30 : 24)
                )
                .shadow(color: accentColor.opacity(0.5), radius: gesture.isFingerDown ? 6 : 10)

            // Inner dot
            Circle()
                .fill(accentColor)
                .frame(width: gesture.isFingerDown ? 6 : 4, height: gesture.isFingerDown ? 6 : 4)
                .shadow(color: accentColor.opacity(0.7), radius: 4)

            // Click ripple
            if clickRipple {
                Circle()
                    .stroke(Forge.jade.opacity(0.6), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .scaleEffect(clickRipple ? 1.5 : 0.5)
                    .opacity(clickRipple ? 0 : 1)
            }

            // Crosshair lines (subtle)
            if !gesture.isFingerDown {
                Rectangle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 1, height: isHovering ? 18 : 12)
                Rectangle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: isHovering ? 18 : 12, height: 1)
            }
        }
        .position(pos)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: gesture.isFingerDown)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
    }

    private func updateHoverState(_ pos: CGPoint) {
        let globalPos = CGPoint(
            x: pos.x * windowSize.width,
            y: pos.y * windowSize.height
        )

        // ── 1. If currently dragging a time slider, update it and return ──
        if let slider = activeDraggingSlider {
            let frac = max(0, min(1, (globalPos.x - slider.frame.minX) / slider.frame.width))
            let snapped = (Int(frac * 1440) / 15) * 15
            
            let currentVal = slider.isStartSlider ? startMinutesBinding(slider.sessionID).get() : endMinutesBinding(slider.sessionID).get()
            if snapped != currentVal {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.3)
                if slider.isStartSlider {
                    startMinutesBinding(slider.sessionID).set(snapped)
                } else {
                    endMinutesBinding(slider.sessionID).set(snapped)
                }
            }
            return
        }

        // ── 2. If currently dragging the timesheet list, scroll it and return ──
        if isDraggingList {
            let deltaY = globalPos.y - dragListStartY
            let rowsToScroll = Int(deltaY / 30.0)
            let targetIndex = max(0, min(sessionCount - 1, dragListStartScrollIndex - rowsToScroll))
            if targetIndex != scrollTargetIndex {
                scrollTargetIndex = targetIndex
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)
            }
            return
        }

        // ── 3. If cursor is locked, do not update hover targets ──
        if frozenCursorPosition != nil { return }

        // ── 4. Precision Target Matching ──
        let foundHover = findTargetElement(at: globalPos)
        hoveredElementID = foundHover

        // ── Map hovered element to calendar date if applicable ──
        if let hoverId = foundHover, hoverId.hasPrefix("date_"),
           let indexStr = hoverId.split(separator: "_").last,
           let index = Int(indexStr) {
            gestureHoveredDate = resolveDate(index)
        } else {
            gestureHoveredDate = nil
        }

        // ── Copy button glow ──
        if let hoverId = foundHover, hoverId == "copyBtn" {
            isCopyButtonGlowing = true
        } else {
            isCopyButtonGlowing = false
        }
    }

    private func handleClick() {
        if isDraggingList { return }

        // Proactively freeze cursor position immediately if not already frozen to prevent click coordinate drift
        let pos = gesture.fingerPosition
        let globalPos = CGPoint(
            x: pos.x * windowSize.width,
            y: pos.y * windowSize.height
        )
        if frozenCursorPosition == nil {
            frozenCursorPosition = globalPos
        }

        // Fire ripple animation
        withAnimation(.easeOut(duration: 0.35)) { clickRipple = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { clickRipple = false }

        // ── 1. Check registered tappable elements (buttons + calendar days) ──
        if let targetId = findTargetElement(at: globalPos) {
            onAction(targetId)
            return
        }

        // ── 2. Check copy button (in timesheet view) fallback ──
        let expandedCopy = copyButtonFrame.insetBy(dx: -20, dy: -20)
        if flipped, expandedCopy.contains(globalPos) {
            onCopy()
            return
        }

        // ── 3. Check calendar day cells ──
        if !flipped, let date = gestureHoveredDate {
            onToggleDate(date)
            return
        }
    }

    private func findTargetElement(at globalPos: CGPoint) -> String? {
        let activeElements = tappableFrames.filter { el in
            if flipped {
                return !el.id.hasPrefix("date_") && el.id != "prevMonth" && el.id != "nextMonth"
            } else {
                return el.id != "copyBtn"
            }
        }
        
        // Exact bounding box matches
        let exactMatches = activeElements.filter { $0.frame.contains(globalPos) }
        if !exactMatches.isEmpty {
            return exactMatches.min(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })?.id
        }
        
        // Close matches within 15 points
        var closestId: String? = nil
        var minDistance: CGFloat = CGFloat.infinity
        
        for el in activeElements {
            let dist = distanceToFrame(globalPos, el.frame)
            if dist < 15.0 && dist < minDistance {
                minDistance = dist
                closestId = el.id
            }
        }
        
        return closestId
    }

    private func distanceToFrame(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
