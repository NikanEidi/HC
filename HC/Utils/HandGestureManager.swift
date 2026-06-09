//
//  HandGestureManager.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  FRONT-CAMERA GESTURE ENGINE                                  ║
//  ║                                                               ║
//  ║  Pipeline: AVFoundation → Vision → One-Euro Filter → UI State  ║
//  ║                                                               ║
//  ║  Gesture vocabulary:                                          ║
//  ║    • Index finger tracking = screen pointer                    ║
//  ║    • Thumb-index pinch    = click (with hysteresis)            ║
//  ║    • Wrist rotation       = view flip trigger                 ║
//  ║    • Directional swipes   = slider drag / list scroll          ║
//  ║    • Hand depth (MCP)     = depth estimation                   ║
//  ║                                                               ║
//  ║  Supports both LEFT and RIGHT hands. No mirror mode.          ║
//  ║  Camera: VGA preset, beginConfiguration/commitConfiguration.  ║
//  ║  Orientation: Tracks UIWindowScene interface orientation.     ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import AVFoundation
import Vision
import Observation
import UIKit

/// Observable gesture engine that processes front-camera video frames
/// through Apple’s Vision framework to extract hand pose landmarks.
/// Publishes smoothed finger position, pinch detection, wrist flip,
/// directional swipes, and hand depth as reactive state properties.
@Observable
final class HandGestureManager {

    // ━━━━━ Public: Finger Tracking ━━━━━

    /// Smoothed index-finger position in screen-normalized coords.
    /// (0,0) = top-left, (1,1) = bottom-right.
    var fingerPosition: CGPoint = .zero
    /// Whether any hand is currently being tracked by the Vision pipeline.
    var isTracking = false

    /// Whether camera access has been authorized by the user.
    var isCameraAuthorized = false

    // ━━━━━ Public: Click (Thumb-Index Pinch) ━━━━━

    /// Fires true for ~150 ms on pinch-release click.
    var isClickDetected = false
    /// Screen-normalized position where click occurred.
    var clickPosition: CGPoint = .zero
    /// True while thumb and index are pinched (finger "down").
    var isFingerDown = false

    // ━━━━━ Public: Flip Gesture (Wrist Rotation) ━━━━━

    /// Momentarily set to `true` when a wrist flip is detected.
    /// Consumed by `TrackerHomeView` to trigger the 3D card flip.
    var shouldSwitchView = false

    // ━━━━━ Public: Directional Swipe Deltas ━━━━━

    /// Horizontal velocity delta for slider adjustment (points/frame).
    var horizontalSliderDelta: CGFloat = 0

    /// Vertical velocity delta for list scrolling (points/frame).
    var verticalScrollDelta: CGFloat = 0

    // ━━━━━ Public: Hand Depth Estimation ━━━━━

    /// Estimated hand depth based on wrist-to-middleMCP distance.
    /// Larger values = hand closer to camera.
    var handDepth: CGFloat = 0

    // ── Private: Session ──

    private var session: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "hc.gesture.capture", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "hc.gesture.analysis", qos: .userInitiated)
    private var frameDelegate: FrameDelegate?

    // ── Private: Vision ──

    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    // ── Private: Orientation & Caching ──

    private var currentInterfaceOrientation: UIInterfaceOrientation = .portrait

    // ── Private: Smoothing ──
    
    private let oneEuroFilter = OneEuroFilter2D(minCutoff: 1.0, beta: 0.20, dCutoff: 1.0)
    /// Tracking gain centered on 0.5. Reduced from 1.5→1.25 for
    /// better calendar precision while still reaching screen edges.
    private let trackingGain: CGFloat = 1.25

    // ── Private: Click Detection ──

    private var wasPinched = false
    private var lastClickTime: Date = .distantPast
    private let clickCooldown: TimeInterval = 0.30
    private var emaPinchRatio: CGFloat?

    // ── Private: Flip Detection ──

    private var prevWristAngle: CGFloat?
    private var emaWristAngle: CGFloat?
    private var angleHistory: [AngleSample] = []
    private var lastFlipTime: Date = .distantPast
    private let flipCooldown: TimeInterval = 1.2
    private let flipRotThreshold: CGFloat = 0.60
    private var emaDepth: CGFloat?

    // ── Private: Swipe Detection ──

    private var prevFinger: CGPoint?
    private var velocityRing: [CGPoint] = []
    private let ringSize = 5
    private let hSwipeThresh: CGFloat = 0.010
    private let vSwipeThresh: CGFloat = 0.010

    // ── Private: Hand Loss ──

    private var framesWithoutHand = 0
    private let handLossThreshold = 10

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Lifecycle
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    init() {
        if Thread.isMainThread {
            updateInterfaceOrientation()
        } else {
            DispatchQueue.main.sync {
                self.updateInterfaceOrientation()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateInterfaceOrientation()
        }
    }

    private func updateInterfaceOrientation() {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            self.currentInterfaceOrientation = scene.effectiveGeometry.interfaceOrientation
        }
    }

    /// Begins the camera capture session on a background queue.
    /// Safe to call multiple times — no-ops if already running.
    func startSession() {
        captureQueue.async { [weak self] in
            guard let self,
                  self.session == nil || !(self.session?.isRunning ?? false)
            else { return }
            self.authorize()
        }
    }

    /// Stops the camera capture session and resets tracking state.
    func stopSession() {
        captureQueue.async { [weak self] in
            self?.session?.stopRunning()
            DispatchQueue.main.async {
                self?.isTracking = false
                self?.isFingerDown = false
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Camera Setup
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Checks camera authorization status and configures capture if authorized.
    private func authorize() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isCameraAuthorized = true }
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { self?.isCameraAuthorized = granted }
                if granted { self?.configure() }
            }
        default:
            DispatchQueue.main.async { self.isCameraAuthorized = false }
        }
    }

    /// Configures the AVCaptureSession with front camera input and video output.
    /// Uses VGA preset for optimal performance with Vision hand pose detection.
    private func configure() {
        if let existing = session, existing.isRunning { return }

        let s = AVCaptureSession()

        guard let cam = AVCaptureDevice.default(
                  .builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: cam)
        else { return }

        // ╔═══════════════════════════════════════════════════════╗
        // ║  Batch all config changes between begin/commit to     ║
        // ║  prevent FigCaptureSourceRemote assertion failures.    ║
        // ╚═══════════════════════════════════════════════════════╝
        s.beginConfiguration()

        // VGA is sufficient for hand-pose landmarks and most
        // reliable across all iPad/iPhone front cameras.
        if s.canSetSessionPreset(.vga640x480) {
            s.sessionPreset = .vga640x480
        } else if s.canSetSessionPreset(.low) {
            s.sessionPreset = .low
        }

        guard s.canAddInput(input) else { s.commitConfiguration(); return }
        s.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let del = FrameDelegate { [weak self] buf in self?.analyze(buf) }
        output.setSampleBufferDelegate(del, queue: analysisQueue)
        frameDelegate = del

        guard s.canAddOutput(output) else { s.commitConfiguration(); return }
        s.addOutput(output)

        // No mirror — we handle coordinate flip in processHand
        // so both left and right hands map naturally.
        if let c = output.connection(with: .video) {
            c.isVideoMirrored = false
        }

        s.commitConfiguration()

        session = s
        s.startRunning()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Vision Pipeline
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Processes a single video frame through the Vision hand pose pipeline.
    /// Dispatches detected landmarks to `processHand(_:)` or triggers
    /// `handleHandLost()` when no hand is visible.
    private func analyze(_ buffer: CMSampleBuffer) {
        guard let px = CMSampleBufferGetImageBuffer(buffer) else { return }

        let orientation = self.visionOrientation()

        do {
            try VNImageRequestHandler(
                cvPixelBuffer: px,
                orientation: orientation
            ).perform([handPoseRequest])

            guard let obs = handPoseRequest.results?.first else {
                handleHandLost()
                return
            }
            framesWithoutHand = 0
            processHand(obs)
        } catch {
            handleHandLost()
        }
    }

    /// Returns the correct CGImagePropertyOrientation for the front camera
    /// based on cached interface orientation.
    private func visionOrientation() -> CGImagePropertyOrientation {
        switch currentInterfaceOrientation {
        case .portrait:           return .left
        case .portraitUpsideDown: return .right
        case .landscapeLeft:      return .down
        case .landscapeRight:     return .up
        default:                  return .left
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Hand Lost
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Resets all tracking state after consecutive frames without a visible hand.
    /// Clears filters, gesture history, and dispatches UI state reset to main queue.
    private func handleHandLost() {
        framesWithoutHand += 1
        guard framesWithoutHand >= handLossThreshold else { return }

        prevFinger = nil
        prevWristAngle = nil
        oneEuroFilter.reset()
        emaDepth = nil
        emaPinchRatio = nil
        angleHistory.removeAll()
        velocityRing.removeAll()
        wasPinched = false

        DispatchQueue.main.async {
            self.isTracking = false
            self.isFingerDown = false
            self.horizontalSliderDelta = 0
            self.verticalScrollDelta = 0
            self.handDepth = 0
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Hand Pose Processing
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func processHand(_ obs: VNHumanHandPoseObservation) {
        guard let indexTip  = try? obs.recognizedPoint(.indexTip),
              let thumbTip  = try? obs.recognizedPoint(.thumbTip),
              let wrist     = try? obs.recognizedPoint(.wrist),
              let middleMCP = try? obs.recognizedPoint(.middleMCP),
              indexTip.confidence  > 0.15,
              thumbTip.confidence  > 0.15,
              wrist.confidence     > 0.15,
              middleMCP.confidence > 0.15
        else { return }

        let now = Date()

        // ┌──────────────────────────────────────────────┐
        // │  COORDINATE MAPPING & ORIENTATION MATCHING   │
        // └──────────────────────────────────────────────┘

        let rawX: CGFloat
        let rawY: CGFloat

        // In Landscape Left, front camera coordinates map directly horizontally.
        // In other orientations, they are mirrored.
        // Y is always bottom-origin to top-origin flipped.
        switch currentInterfaceOrientation {
        case .landscapeLeft:
            rawX = indexTip.location.x
            rawY = 1.0 - indexTip.location.y
        default:
            rawX = 1.0 - indexTip.location.x
            rawY = 1.0 - indexTip.location.y
        }

        // Apply tracking gain (centered on 0.5)
        let gainedX = 0.5 + (rawX - 0.5) * trackingGain
        let gainedY = 0.5 + (rawY - 0.5) * trackingGain
        let rawFinger = CGPoint(x: gainedX, y: gainedY)

        // ┌──────────────────────────────────────────────┐
        // │  ONE-EURO ADAPTIVE SMOOTHING                 │
        // └──────────────────────────────────────────────┘

        let filteredFinger = oneEuroFilter.filter(rawFinger, timestamp: now)
        let finger = CGPoint(
            x: min(1, max(0, filteredFinger.x)),
            y: min(1, max(0, filteredFinger.y))
        )

        // Z-depth estimation with strong EMA smoothing to stabilize pinch thresholds.
        // Uses the rigid distance between wrist and middleMCP (knuckle) which is
        // invariant to finger curling/pinching.
        let rawDepth = hypot(
            wrist.location.x - middleMCP.location.x,
            wrist.location.y - middleMCP.location.y
        )
        let smoothedDepth: CGFloat
        if let prev = emaDepth {
            smoothedDepth = prev + 0.10 * (rawDepth - prev)
        } else {
            smoothedDepth = rawDepth
        }
        emaDepth = smoothedDepth

        // ┌──────────────────────────────────────────────┐
        // │  CLICK — Scale-Invariant Pinch & Hysteresis  │
        // └──────────────────────────────────────────────┘

        let thumbIndexDist = hypot(
            thumbTip.location.x - indexTip.location.x,
            thumbTip.location.y - indexTip.location.y
        )

        // Compute scale-invariant pinch ratio based on hand size
        let rawPinchRatio = thumbIndexDist / max(0.01, smoothedDepth)
        
        let smoothedPinchRatio: CGFloat
        if let prev = emaPinchRatio {
            smoothedPinchRatio = prev + 0.30 * (rawPinchRatio - prev)
        } else {
            smoothedPinchRatio = rawPinchRatio
        }
        emaPinchRatio = smoothedPinchRatio

        let pinchDownThreshold: CGFloat = 0.40
        let pinchUpThreshold: CGFloat = 0.55

        var clickFired = false

        if smoothedPinchRatio < pinchDownThreshold {
            if !wasPinched {
                wasPinched = true
                if now.timeIntervalSince(lastClickTime) > clickCooldown {
                    lastClickTime = now
                    clickFired = true
                }
            }
        } else if smoothedPinchRatio > pinchUpThreshold && wasPinched {
            wasPinched = false
        }

        // ┌──────────────────────────────────────────────┐
        // │  FLIP — Wrist Spin (Unwrapped Sliding Window) │
        // └──────────────────────────────────────────────┘

        let wPt  = CGPoint(x: wrist.location.x, y: wrist.location.y)
        let mcpP = CGPoint(x: middleMCP.location.x, y: middleMCP.location.y)
        let wristAngle = atan2(mcpP.y - wPt.y, mcpP.x - wPt.x)

        angleHistory.append(AngleSample(angle: wristAngle, timestamp: now))
        angleHistory = angleHistory.filter { now.timeIntervalSince($0.timestamp) < 0.35 }

        var flipFired = false
        if angleHistory.count >= 3, now.timeIntervalSince(lastFlipTime) > flipCooldown {
            // Unwrap angle history to handle branch cuts at -pi/pi
            var unwrappedHistory: [CGFloat] = []
            if !angleHistory.isEmpty {
                var unwrapped = angleHistory[0].angle
                unwrappedHistory.append(unwrapped)
                for i in 1..<angleHistory.count {
                    var diff = angleHistory[i].angle - angleHistory[i-1].angle
                    while diff < -.pi { diff += 2 * .pi }
                    while diff > .pi { diff -= 2 * .pi }
                    unwrapped += diff
                    unwrappedHistory.append(unwrapped)
                }
            }
            
            if let minAngle = unwrappedHistory.min(),
               let maxAngle = unwrappedHistory.max() {
                let totalRotation = abs(maxAngle - minAngle)
                // Trigger flip only if hand rotates > 1.1 radians (~63 degrees) within 0.35s
                if totalRotation > flipRotThreshold {
                    lastFlipTime = now
                    flipFired = true
                    angleHistory.removeAll() // Clear history to prevent double triggering
                }
            }
        }

        // ┌──────────────────────────────────────────────┐
        // │  SWIPE — Directional Velocity                │
        // └──────────────────────────────────────────────┘

        var hDelta: CGFloat = 0
        var vDelta: CGFloat = 0
        if let pp = prevFinger {
            let d = CGPoint(x: finger.x - pp.x, y: finger.y - pp.y)
            velocityRing.append(d)
            if velocityRing.count > ringSize { velocityRing.removeFirst() }
            let n  = CGFloat(velocityRing.count)
            let ax = velocityRing.reduce(0) { $0 + $1.x } / n
            let ay = velocityRing.reduce(0) { $0 + $1.y } / n
            hDelta = (abs(ax) > hSwipeThresh && abs(ax) > abs(ay) * 1.5) ? ax * 800 : 0
            vDelta = (abs(ay) > vSwipeThresh && abs(ay) > abs(ax) * 1.5) ? ay * 600 : 0
        }
        prevFinger = finger

        // ┌──────────────────────────────────────────────┐
        // │  DISPATCH → Main Thread                      │
        // └──────────────────────────────────────────────┘

        DispatchQueue.main.async {
            self.fingerPosition = finger
            self.isTracking = true
            self.handDepth = smoothedDepth
            self.horizontalSliderDelta = hDelta
            self.verticalScrollDelta = vDelta

            self.isFingerDown = self.wasPinched

            if clickFired {
                self.clickPosition = finger
                self.isClickDetected = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.isClickDetected = false
                }
            }
            if flipFired {
                self.shouldSwitchView = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldSwitchView = false
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - AVCapture Delegate Bridge
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private final class FrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let onFrame: (CMSampleBuffer) -> Void
    init(onFrame: @escaping (CMSampleBuffer) -> Void) { self.onFrame = onFrame }
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sb: CMSampleBuffer,
                       from conn: AVCaptureConnection) {
        onFrame(sb)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - One-Euro Adaptive Filter & Helpers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AngleSample {
    let angle: CGFloat
    let timestamp: Date
}

private final class OneEuroFilter {
    var minCutoff: CGFloat
    var beta: CGFloat
    var dCutoff: CGFloat
    
    private var xPrev: CGFloat?
    private var dxPrev: CGFloat = 0
    private var lastTime: Date?
    
    init(minCutoff: CGFloat, beta: CGFloat, dCutoff: CGFloat = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    func filter(_ value: CGFloat, timestamp: Date) -> CGFloat {
        guard let prev = xPrev, let prevTime = lastTime else {
            xPrev = value
            lastTime = timestamp
            return value
        }
        
        let dt = CGFloat(timestamp.timeIntervalSince(prevTime))
        lastTime = timestamp
        
        guard dt > 0 else { return prev }
        
        // Filter rate of change (derivative)
        let dx = (value - prev) / dt
        let alphaD = alphaValue(dt: dt, cutoff: dCutoff)
        let dxFiltered = alphaD * dx + (1.0 - alphaD) * dxPrev
        dxPrev = dxFiltered
        
        // Calculate adaptive cutoff based on speed
        let cutoff = minCutoff + beta * abs(dxFiltered)
        let alpha = alphaValue(dt: dt, cutoff: cutoff)
        
        let xFiltered = alpha * value + (1.0 - alpha) * prev
        xPrev = xFiltered
        return xFiltered
    }
    
    private func alphaValue(dt: CGFloat, cutoff: CGFloat) -> CGFloat {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return dt / (dt + tau)
    }
    
    func reset() {
        xPrev = nil
        dxPrev = 0
        lastTime = nil
    }
}

private final class OneEuroFilter2D {
    let filterX: OneEuroFilter
    let filterY: OneEuroFilter
    
    init(minCutoff: CGFloat = 0.5, beta: CGFloat = 0.03, dCutoff: CGFloat = 1.0) {
        self.filterX = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        self.filterY = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
    }
    
    func filter(_ point: CGPoint, timestamp: Date) -> CGPoint {
        let x = filterX.filter(point.x, timestamp: timestamp)
        let y = filterY.filter(point.y, timestamp: timestamp)
        return CGPoint(x: x, y: y)
    }
    
    func reset() {
        filterX.reset()
        filterY.reset()
    }
}
