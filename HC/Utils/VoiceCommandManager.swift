//
//  VoiceCommandManager.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  VOICE COGNITION ENGINE — Continuous speech assistant.       ║
//  ║                                                               ║
//  ║  Responsibilities:                                            ║
//  ║    - Passive wake word detection ("Hey Vision", "Hi Vision")  ║
//  ║    - Thread-safe @MainActor audio tapping & recognition       ║
//  ║    - Multi-intent NLP regex date and time parser              ║
//  ║    - Automatic silence & absolute timeout execution state    ║
//  ║    - Tactile confirmation & cyberpunk terminal output         ║
//  ║    - Backward-compatible iOS 16/17 record permission safety   ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import Foundation
import Speech
import AVFoundation
import NaturalLanguage
import UIKit
import Combine
import SwiftUI

/// Structured representation of parsed NLP intents
enum CommandIntent {
    case selectDate(dates: [Date])
    case removeDate(dates: [Date])
    case timeMutation(dates: [Date], startMinutes: Int, endMinutes: Int)
    case navigateMonth(targetMonth: Date)
    case activateCamera
    case deactivateCamera
    case copyReport
    case switchView(showTimesheet: Bool)
    case unknown(command: String)
}

/// A thread-safe, continuous voice assistant that parses commands
/// in natural language and executes timesheet modifications.
@MainActor
class VoiceCommandManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    // ── Published States ──
    @Published var liveTranscript: String = ""
    @Published var systemStatus: String = "STANDBY"
    @Published var voiceLogs: [String] = []
    
    // ── External Context & Callbacks ──
    var hoveredDate: Date? = nil
    var onActivateCamera: (() -> Void)?
    var onDeactivateCamera: (() -> Void)?
    var onSwitchView: ((Bool) -> Void)?
    private var viewModel: TrackerViewModel?
    
    // ── Speech Pipeline State ──
    private var audioEngine: AVAudioEngine? = nil
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isListening = false
    private var isActiveSession = false
    
    // ── Silence / Timeout Tasks ──
    private var silenceTask: Task<Void, Never>?
    private var activeTimeoutTask: Task<Void, Never>?
    private var greetDelayTask: Task<Void, Never>?
    
    // ── Conversational Context & Memory ──
    private var lastSelectedDates: [Date] = []
    private var lastErrorSpeechTime: Date? = nil
    private let errorCooldownSeconds: TimeInterval = 8.0
    
    // ── Speech Synthesis Pipeline ──
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isSynthesizerSpeaking = false
    private var activeUtterance: AVSpeechUtterance?
    private lazy var cachedVoice: AVSpeechSynthesisVoice? = {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.first(where: {
            $0.gender == .male && ($0.language == "en-US" || $0.language == "en-GB") && $0.quality == .premium
        }) ?? voices.first(where: {
            $0.gender == .male && ($0.language == "en-US" || $0.language == "en-GB") && $0.quality == .enhanced
        }) ?? voices.first(where: {
            $0.gender == .male && $0.language.hasPrefix("en")
        }) ?? AVSpeechSynthesisVoice(language: "en-US")
    }()
    private let requestHolder = SpeechRequestHolder()
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAudioSessionObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Initializes the speech recognizer, requests system permissions,
    /// and boots the passive audio engine tap.
    func setup(viewModel: TrackerViewModel) {
        self.viewModel = viewModel
        requestPermissions()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Permission Processing
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { micGranted in
                    DispatchQueue.main.async { [weak self] in
                        self?.handlePermissionsResult(speechStatus: speechStatus, micGranted: micGranted)
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                    DispatchQueue.main.async { [weak self] in
                        self?.handlePermissionsResult(speechStatus: speechStatus, micGranted: micGranted)
                    }
                }
            }
        }
    }
    
    private func handlePermissionsResult(speechStatus: SFSpeechRecognizerAuthorizationStatus, micGranted: Bool) {
        // Log Speech Recognition status
        switch speechStatus {
        case .authorized:
            self.addLog("[SYS] Speech Recognition Matrix authorized.")
        case .denied, .restricted, .notDetermined:
            self.addLog("[SYS] Speech Recognition access denied/restricted.")
        @unknown default:
            break
        }
        
        // Log Microphone status
        if micGranted {
            self.addLog("[SYS] Audio input sensor enabled.")
        } else {
            self.addLog("[SYS] Audio input sensor access denied.")
        }
        
        // Only start listening if both authorizations are granted
        if speechStatus == .authorized && micGranted {
            self.startListening()
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Audio Pipeline & Listening Lifecycle
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func startListening() {
        if let engine = audioEngine, engine.isRunning {
            return
        }
        
        // Dispatch to the main thread runloop to run audio setup safely
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                self.addLog("[ERR] Failed to tap hardware audio bus: \(error.localizedDescription)")
                return
            }
            
            if self.audioEngine == nil {
                self.audioEngine = AVAudioEngine()
            }
            guard let engine = self.audioEngine else { return }
            
            engine.stop()
            engine.reset()
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
                self.addLog("[ERR] Audio hardware format has 0 channels.")
                return
            }
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard buffer.frameLength > 0 else { return }
                
                let bufferList = buffer.audioBufferList.pointee
                if bufferList.mNumberBuffers > 0 {
                    guard bufferList.mBuffers.mDataByteSize > 0 else { return }
                }
                
                self?.requestHolder.request?.append(buffer)
            }
            
            engine.prepare()
            do {
                try engine.start()
                self.isListening = true
                self.systemStatus = "STANDBY"
                self.addLog("[SYS] Voice Engine: Passive listening online.")
                self.startNewRecognitionSession()
            } catch {
                self.addLog("[ERR] Failed to start audio engine: \(error.localizedDescription)")
            }
        }
    }
    
    func stopListening() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isListening = false
            self.stopAudioEngineOnly()
            self.greetDelayTask?.cancel()
            self.greetDelayTask = nil
            self.silenceTask?.cancel()
            self.silenceTask = nil
            self.activeTimeoutTask?.cancel()
            self.activeTimeoutTask = nil
            self.addLog("[SYS] Voice Engine: Passive listening offline.")
        }
    }
    
    private func stopAudioEngineOnly() {
        self.cancelCurrentRecognitionSession()
        if let engine = self.audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        self.audioEngine = nil
    }
    
    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case .began:
                self.addLog("[SYS] Audio session interrupted. Pausing engine.")
                self.stopAudioEngineOnly()
            case .ended:
                self.addLog("[SYS] Audio session interruption ended. Resuming engine.")
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.startListening()
                    } else {
                        self.startListening()
                    }
                } else {
                    self.startListening()
                }
            @unknown default:
                break
            }
        }
    }
    
    @objc private func handleMediaServicesWereReset() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.addLog("[SYS] Media services reset. Re-initializing audio pipeline.")
            self.audioEngine = nil
            if self.isListening {
                self.startListening()
            }
        }
    }
    
    private func cancelCurrentRecognitionSession() {
        requestHolder.request = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func startNewRecognitionSession() {
        guard isListening else { return }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            addLog("[ERR] Speech recognition hardware offline.")
            return
        }
        
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.taskHint = .dictation
        newRequest.requiresOnDeviceRecognition = false
        newRequest.contextualStrings = [
            "Vision", "Hey Vision", "Hi Vision", "Vijay", "Hey Vijay", "Hi Vijay",
            "Nik", "Timesheet", "Copy", "Select", "Remove", "Deselect", "Unselect",
            "Delete", "Add", "Set", "Go to", "Show", "Navigate", "Switch", "Open", "Export",
            "Today", "Tomorrow", "Yesterday", "Weekdays", "Weekends", "Calendar", "Grid", "Table",
            "Clear all", "Remove all", "Deselect all",
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        
        let oldRequest = self.recognitionRequest
        let oldTask = self.recognitionTask
        self.recognitionRequest = newRequest
        self.requestHolder.request = newRequest
        
        oldRequest?.endAudio()
        oldTask?.cancel()
        
        let task = speechRecognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                var isFinal = false
                
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.processTranscript(transcript)
                    isFinal = result.isFinal
                }
                
                if let error = error {
                    isFinal = true
                    let nsError = error as NSError
                    if nsError.code != 301 && nsError.code != 203 && nsError.code != 1110 {
                        self.addLog("[ERR] Speech recognizer error: \(error.localizedDescription)")
                    }
                }
                
                if isFinal {
                    if self.recognitionRequest === newRequest {
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        
                        if self.isListening && !self.isSynthesizerSpeaking {
                            self.startNewRecognitionSession()
                        } else {
                            self.requestHolder.request = nil
                        }
                    }
                    
                    if let engine = self.audioEngine, !engine.isRunning {
                        self.startListening()
                    }
                }
            }
        }
        
        self.recognitionTask = task
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - State Machine & Transcription Handling
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func processTranscript(_ text: String) {
        guard isListening else { return }
        guard !isSynthesizerSpeaking else { return }
        
        let lowerText = text.lowercased()
        
        if !isActiveSession {
            if let wakeRange = VoiceCommandParser.findFuzzyWakeWord(in: lowerText) {
                isActiveSession = true
                systemStatus = "ACTIVE"
                triggerHapticFeedback(.medium)
                
                let commandPart = String(lowerText.suffix(from: wakeRange.upperBound)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !commandPart.isEmpty && VoiceCommandParser.containsCommandKeywords(commandPart) {
                    addLog("[SYS] Voice Engine: ACTIVE. Parsing command stream...")
                    liveTranscript = commandPart
                    resetTimers()
                    startSilenceTimer(seconds: 2.0)
                } else {
                    addLog("[SYS] Voice Engine: ACTIVE. Awaiting command...")
                    liveTranscript = ""
                    
                    greetDelayTask?.cancel()
                    greetDelayTask = Task { @MainActor in
                        do {
                            try await Task.sleep(nanoseconds: 600_000_000)
                            guard !Task.isCancelled else { return }
                            self.speak(text: "Hey Nik, how can I help you today?")
                        } catch {}
                    }
                    
                    resetTimers()
                    startSilenceTimer(seconds: 5.0)
                }
            }
        } else {
            greetDelayTask?.cancel()
            greetDelayTask = nil
            
            if let wakeRange = VoiceCommandParser.findFuzzyWakeWord(in: lowerText) {
                let commandPart = String(lowerText.suffix(from: wakeRange.upperBound))
                liveTranscript = commandPart.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                liveTranscript = lowerText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            resetTimers()
            startSilenceTimer(seconds: 2.5)
        }
    }
    
    private func resetTimers() {
        silenceTask?.cancel()
        silenceTask = nil
        
        activeTimeoutTask?.cancel()
        activeTimeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                self.handleTimeout()
            } catch {}
        }
    }
    
    private func startSilenceTimer(seconds: Double = 2.5) {
        silenceTask?.cancel()
        silenceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.executeCommand()
            } catch {}
        }
    }
    
    private func handleTimeout() {
        guard isActiveSession else { return }
        addLog("[SYS] Voice Engine: Session timed out.")
        deactivateSession()
    }
    
    private func deactivateSession() {
        isActiveSession = false
        systemStatus = "STANDBY"
        liveTranscript = ""
        resetTimers()
        startNewRecognitionSession()
    }
    
    private func executeCommand() {
        guard !isSynthesizerSpeaking else { return }
        
        let command = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if command.isEmpty {
            deactivateSession()
            return
        }
        
        addLog("[SYS] Voice Input: \"\(command)\"")
        
        let success = parseAndExecute(command: command)
        
        if success {
            triggerHapticFeedback(.success)
        } else {
            addLog("[ERR] Failed to process command: \"\(command)\"")
            triggerHapticFeedback(.error)
        }
        
        deactivateSession()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Parser Dispatch & Execution
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func parseAndExecute(command: String) -> Bool {
        guard let vm = viewModel else { return false }
        
        let intent = VoiceCommandParser.parse(
            command: command,
            currentMonth: vm.currentMonth,
            hoveredDate: hoveredDate,
            lastSelectedDates: lastSelectedDates,
            sessions: vm.sessions
        )
        
        switch intent {
        case .activateCamera:
            addLog("[SYS] Optical sensors engaged. Air-gesture tracking: ACTIVE.")
            triggerRigidHaptic()
            onActivateCamera?()
            speak(text: "Optical matrix online. You have the conn, Nik.")
            return true
            
        case .deactivateCamera:
            addLog("[SYS] Optical sensors disengaged. Air-gesture tracking: OFFLINE.")
            triggerRigidHaptic()
            onDeactivateCamera?()
            speak(text: "Optical matrix offline, Nik.")
            return true
            
        case .copyReport:
            let report = vm.generateReportString()
            if !report.isEmpty {
                ClipboardManager.copy(report)
                triggerRigidHaptic()
                addLog("[OK] Clipboard exported.")
                speak(text: "Clipboard exported successfully, Nik.")
                return true
            } else {
                addLog("[ERR] No session data available to export.")
                speak(text: "Error: No session data available to export.")
                return false
            }
            
        case .switchView(let showTimesheet):
            triggerRigidHaptic()
            if showTimesheet {
                addLog("[SYS] UI Matrix: Switching to Timesheet View.")
                speak(text: "Switching to timesheet panel, Nik.")
            } else {
                addLog("[SYS] UI Matrix: Switching to Calendar View.")
                speak(text: "Switching to calendar panel, Nik.")
            }
            onSwitchView?(showTimesheet)
            return true
            
        case .navigateMonth(let targetMonth):
            triggerRigidHaptic()
            let df = DateFormatter()
            df.dateFormat = "MMMM"
            let monthNameUpper = df.string(from: targetMonth).uppercased()
            addLog("[SYS] Shifting calendar matrix to \(monthNameUpper)... [OK]")
            speak(text: "Shifting your calendar to \(formatMonthNatural(targetMonth)), Nik.")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                vm.currentMonth = targetMonth
            }
            return true
            
        case .selectDate(let dates):
            for date in dates {
                checkAndNavigateMonth(for: date)
                
                if !vm.isSelected(date) {
                    triggerRigidHaptic()
                    withAnimation {
                        vm.toggleDate(date)
                    }
                    let day = Calendar.current.component(.day, from: date)
                    addLog("[SYS] Ghost-click applied to day \(day).")
                }
            }
            if !dates.isEmpty {
                lastSelectedDates = dates
            }
            if dates.count == 1 {
                speak(text: "I have selected \(formatDateNatural(dates[0])) for you.")
            } else {
                speak(text: "I've highlighted those \(dates.count) dates on your calendar, Nik.")
            }
            return true
            
        case .removeDate(let dates):
            var count = 0
            for date in dates {
                checkAndNavigateMonth(for: date)
                
                if vm.isSelected(date) {
                    triggerRigidHaptic()
                    withAnimation {
                        vm.toggleDate(date)
                    }
                    let day = Calendar.current.component(.day, from: date)
                    addLog("[SYS] Ghost-click removed day \(day).")
                    count += 1
                }
            }
            if count > 0 {
                if dates.count == 1 {
                    speak(text: "Alright, I've cleared the session for \(formatDateNatural(dates[0])).")
                } else {
                    speak(text: "Done. I've cleared those \(count) sessions, Nik.")
                }
                return true
            } else {
                addLog("[ERR] Specified dates were not active.")
                speak(text: "None of those dates are currently active, Nik.")
                return false
            }
            
        case .timeMutation(let dates, let start, let end):
            let startStr = String(format: "%02d:%02d", start / 60, start % 60)
            let endStr = String(format: "%02d:%02d", end / 60, end % 60)
            let timePhrase = formatTimeRangeNatural(start: start, end: end)
            
            if !dates.isEmpty {
                for date in dates {
                    checkAndNavigateMonth(for: date)
                    if !vm.isSelected(date) {
                        triggerRigidHaptic()
                        withAnimation {
                            vm.toggleDate(date)
                        }
                    }
                    triggerRigidHaptic()
                    withAnimation {
                        vm.updateSessionTimes(for: date, startMinutes: start, endMinutes: end)
                    }
                }
                lastSelectedDates = dates
                let dateStr = dates.map { formatDateShort($0) }.joined(separator: ", ")
                addLog("[OK] Set \(dateStr) from \(startStr) to \(endStr).")
                
                if dates.count == 1 {
                    speak(text: "I've updated the hours for \(formatDateNatural(dates[0])) to \(timePhrase).")
                } else {
                    speak(text: "I've updated those sessions to \(timePhrase) for you.")
                }
                return true
            } else {
                if let hovered = hoveredDate, vm.isSelected(hovered) {
                    triggerRigidHaptic()
                    withAnimation {
                        vm.updateSessionTimes(for: hovered, startMinutes: start, endMinutes: end)
                    }
                    addLog("[OK] Set hovered date to \(startStr) till \(endStr).")
                    speak(text: "I've set the hovered session to \(timePhrase), Nik.")
                    return true
                } else if !vm.sessions.isEmpty {
                    for session in vm.sessions {
                        triggerRigidHaptic()
                        withAnimation {
                            vm.updateSessionTimes(for: session.date, startMinutes: start, endMinutes: end)
                        }
                    }
                    addLog("[OK] Set all active sessions to \(startStr) till \(endStr).")
                    speak(text: "All active sessions have been set to \(timePhrase), Nik.")
                    return true
                } else {
                    addLog("[ERR] No target session active for time mutation.")
                    speak(text: "No session active to apply the time mutation, Nik.")
                    return false
                }
            }
            
        case .unknown(let command):
            addLog("[ERR] Directive unrecognized: \"\(command)\"")
            speakFallbackError()
            return false
        }
    }
    
    private func checkAndNavigateMonth(for date: Date) {
        guard let vm = viewModel else { return }
        let calendar = Calendar.current
        let targetMonthComps = calendar.dateComponents([.year, .month], from: date)
        let currentMonthComps = calendar.dateComponents([.year, .month], from: vm.currentMonth)
        
        if targetMonthComps.year != currentMonthComps.year || targetMonthComps.month != currentMonthComps.month {
            triggerRigidHaptic()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            addLog("[NLP] Extracted: \(df.string(from: date))")
            df.dateFormat = "MMMM"
            let monthNameUpper = df.string(from: date).uppercased()
            addLog("[SYS] Shifting calendar matrix to \(monthNameUpper)... [OK]")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                let targetMonth = calendar.date(from: targetMonthComps) ?? date
                vm.currentMonth = targetMonth
            }
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Logging & Feedback Utilities
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func addLog(_ message: String) {
        voiceLogs.append(message)
        if voiceLogs.count > 15 {
            voiceLogs.removeFirst()
        }
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "d MMM"
        return df.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    
    private func triggerRigidHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private enum HapticType {
        case medium
        case success
        case error
    }
    
    private func triggerHapticFeedback(_ type: HapticType) {
        switch type {
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Text-to-Speech Engine & Delegate
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func speak(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.cancelCurrentRecognitionSession()
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = self.cachedVoice
            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.0
            
            if self.speechSynthesizer.isSpeaking {
                self.speechSynthesizer.stopSpeaking(at: .immediate)
            }
            
            self.isSynthesizerSpeaking = true
            self.activeUtterance = utterance
            self.speechSynthesizer.speak(utterance)
            self.addLog("[SYS] Vision: \"\(text)\"")
        }
    }
    
    private func speakFallbackError() {
        guard isActiveSession else { return }
        
        let now = Date()
        if let lastTime = lastErrorSpeechTime, now.timeIntervalSince(lastTime) < errorCooldownSeconds {
            addLog("[SYS] Error response suppressed under cooldown.")
            return
        }
        lastErrorSpeechTime = now
        
        let badAssFallbacks = [
            "Audio interference detected, repeat order Nik.",
            "Command matrix unclear. Say again?",
            "I didn't catch that frequency, Nik.",
            "Neural net transmission degraded. Rephrase, Nik.",
            "Sensors scrambled, Nik. Restate intent.",
            "Vocal override unrecognized. Input new command stream."
        ]
        let randomPhrase = badAssFallbacks.randomElement() ?? "Audio interference detected, repeat order Nik."
        speak(text: randomPhrase)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let active = self.activeUtterance, ObjectIdentifier(active) == utteranceID else { return }
            self.isSynthesizerSpeaking = false
            self.activeUtterance = nil
            if self.isListening {
                self.startNewRecognitionSession()
                self.resetTimers()
                self.startSilenceTimer(seconds: 4.0)
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let active = self.activeUtterance, ObjectIdentifier(active) == utteranceID else { return }
            self.isSynthesizerSpeaking = false
            self.activeUtterance = nil
            if self.isListening {
                self.startNewRecognitionSession()
                self.resetTimers()
                self.startSilenceTimer(seconds: 4.0)
            }
        }
    }
    
    // ── Conversational & Voice confirmation helpers ──
    
    private func formatDateNatural(_ date: Date) -> String {
        let calendar = Calendar.current
        let df = DateFormatter()
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            df.dateFormat = "MMMM"
            let monthName = df.string(from: date)
            let day = calendar.component(.day, from: date)
            let suffix: String
            switch day {
            case 1, 21, 31: suffix = "st"
            case 2, 22: suffix = "nd"
            case 3, 23: suffix = "rd"
            default: suffix = "th"
            }
            return "the \(day)\(suffix) of \(monthName)"
        }
    }
    
    private func formatMonthNatural(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df.string(from: date)
    }
    
    private func formatTimeRangeNatural(start: Int, end: Int) -> String {
        let startHour = start / 60
        let startMin = start % 60
        let endHour = end / 60
        let endMin = end % 60
        
        let startPeriod = startHour >= 12 ? "PM" : "AM"
        let startHourNormalized = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour)
        
        let endPeriod = endHour >= 12 ? "PM" : "AM"
        let endHourNormalized = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour)
        
        let startStr = startMin == 0 ? "\(startHourNormalized) \(startPeriod)" : "\(startHourNormalized) \(startMin) \(startPeriod)"
        let endStr = endMin == 0 ? "\(endHourNormalized) \(endPeriod)" : "\(endHourNormalized) \(endMin) \(endPeriod)"
        
        return "\(startStr) to \(endStr)"
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Voice Command Parser (Local NLP Pipeline)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct VoiceCommandParser {
    
    struct ParsedTimeRange {
        let startMinutes: Int
        let endMinutes: Int
    }
    
    static func parse(
        command: String,
        currentMonth: Date,
        hoveredDate: Date?,
        lastSelectedDates: [Date],
        sessions: [WorkSession]
    ) -> CommandIntent {
        let lower = command.lowercased()
        
        // 1. Camera Toggle
        if fuzzyContains(lower, target: "open your eyes") || fuzzyContains(lower, target: "open eyes") ||
           fuzzyContains(lower, target: "open your vision") || fuzzyContains(lower, target: "open vision") ||
           fuzzyContains(lower, target: "activate camera") || fuzzyContains(lower, target: "start camera") ||
           fuzzyContains(lower, target: "camera on") {
            return .activateCamera
        }
        if fuzzyContains(lower, target: "close your eyes") || fuzzyContains(lower, target: "close eyes") ||
           fuzzyContains(lower, target: "close your vision") || fuzzyContains(lower, target: "close vision") ||
           fuzzyContains(lower, target: "deactivate camera") || fuzzyContains(lower, target: "stop camera") ||
           fuzzyContains(lower, target: "camera off") {
            return .deactivateCamera
        }
        
        // 2. Clipboard copy
        if fuzzyContains(lower, target: "copy") || fuzzyContains(lower, target: "export") || fuzzyContains(lower, target: "generate report") {
            return .copyReport
        }
        
        // 3. Switch view
        if fuzzyContains(lower, target: "timesheet") || fuzzyContains(lower, target: "time sheet") || fuzzyContains(lower, target: "table") || fuzzyContains(lower, target: "list") {
            if fuzzyContains(lower, target: "switch") || fuzzyContains(lower, target: "show") ||
               fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "view") ||
               fuzzyContains(lower, target: "display") || fuzzyContains(lower, target: "open") {
                return .switchView(showTimesheet: true)
            }
        }
        if fuzzyContains(lower, target: "calendar") || fuzzyContains(lower, target: "calander") || fuzzyContains(lower, target: "grid") {
            if fuzzyContains(lower, target: "switch") || fuzzyContains(lower, target: "show") ||
               fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "view") ||
               fuzzyContains(lower, target: "display") || fuzzyContains(lower, target: "open") {
                return .switchView(showTimesheet: false)
            }
        }
        
        // 4. Navigate month
        let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
                      "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "show") ||
           fuzzyContains(lower, target: "navigate") || fuzzyContains(lower, target: "switch to") {
            for monthName in months {
                if fuzzyContains(lower, target: monthName), let monthInt = monthIndex(for: monthName) {
                    let currentYear = Calendar.current.component(.year, from: Date())
                    var comps = DateComponents()
                    comps.year = currentYear
                    comps.month = monthInt
                    comps.day = 1
                    if let targetMonth = Calendar.current.date(from: comps) {
                        return .navigateMonth(targetMonth: targetMonth)
                    }
                }
            }
        }
        
        // 5. Bulk remove / clear
        if lower.contains("remove all") || lower.contains("deselect all") ||
           lower.contains("unselect all") || lower.contains("clear all") ||
           lower.contains("delete all") {
            let allDates = sessions.map { Calendar.current.startOfDay(for: $0.date) }
            return .removeDate(dates: allDates)
        }
        
        // --- Date & Time parsing pipeline ---
        let preprocessedTime = preprocessTimeWords(lower)
        let preprocessedForDates = preprocessNumbers(preprocessedTime)
        
        var mutableTextForDates = preprocessedForDates
        
        // 5b. Extract day ranges first and remove them from the parsing stream
        var dates = extractAndRemoveDayRanges(from: &mutableTextForDates, currentMonth: currentMonth)
        
        // 6. Extract time range or standard shift
        let timeRange = parseTimeRange(from: mutableTextForDates)
        
        // Strip time range substrings from preprocessedForDates to avoid number collision
        let cleanedForDates = stripTimeRangePatterns(from: mutableTextForDates)
        
        // 7. Resolve dates
        let calendar = Calendar.current
        
        // Relative Dates
        if let relative = parseRelativeDate(from: cleanedForDates) {
            dates.append(relative)
        }
        
        // NSDataDetector dates
        let parsedDates = parseDates(from: cleanedForDates, currentMonth: currentMonth)
        dates.append(contentsOf: parsedDates)
        
        // Weekday patterns
        let patternDates = parseWeekdayPatterns(from: cleanedForDates, currentMonth: currentMonth)
        dates.append(contentsOf: patternDates)
        
        // Implicit day numbers & Day ranges (if no dates resolved yet)
        if dates.isEmpty {
            let baseDate = currentMonth
            let currentYear = calendar.component(.year, from: baseDate)
            let currentMonthInt = calendar.component(.month, from: baseDate)
            
            let implicitDays = parseImplicitDaysAndRanges(from: cleanedForDates)
            for day in implicitDays {
                var comps = DateComponents()
                comps.year = currentYear
                comps.month = currentMonthInt
                comps.day = day
                if let date = calendar.date(from: comps) {
                    dates.append(calendar.startOfDay(for: date))
                }
            }
        }
        
        // Pronoun resolution
        let words = cleanedForDates.split(separator: " ").map(String.init)
        let hasPronoun = words.contains("it") || words.contains("that") || words.contains("them") ||
                         words.contains("those") || words.contains("these") || words.contains("this") ||
                         words.contains("other") || words.contains("others")
        
        if dates.isEmpty && hasPronoun {
            dates = lastSelectedDates
        }
        
        // Remove duplicates and sort
        var uniqueDates: [Date] = []
        for d in dates {
            let start = calendar.startOfDay(for: d)
            if !uniqueDates.contains(start) {
                uniqueDates.append(start)
            }
        }
        uniqueDates.sort()
        
        // If we still have no dates, predict/fallback to contexts
        if uniqueDates.isEmpty {
            if lower.contains("remove") || lower.contains("delete") || lower.contains("deselect") ||
               lower.contains("unselect") || lower.contains("clear") {
                uniqueDates = lastSelectedDates
            } else if timeRange != nil {
                if !lastSelectedDates.isEmpty {
                    uniqueDates = lastSelectedDates
                } else if let hovered = hoveredDate {
                    uniqueDates = [calendar.startOfDay(for: hovered)]
                } else if !sessions.isEmpty {
                    uniqueDates = sessions.map { calendar.startOfDay(for: $0.date) }
                } else {
                    uniqueDates = [calendar.startOfDay(for: Date())]
                }
            } else if lower.contains("select") || lower.contains("add") || lower.contains("mark") ||
                      lower.contains("toggle") || lower.contains("choose") || lower.contains("pick") ||
                      lower.contains("highlight") || lower.contains("tick") || lower.contains("check") {
                if let hovered = hoveredDate {
                    uniqueDates = [calendar.startOfDay(for: hovered)]
                } else {
                    uniqueDates = [calendar.startOfDay(for: Date())]
                }
            }
        }
        
        // Dispatch Intent
        if !uniqueDates.isEmpty {
            if lower.contains("remove") || lower.contains("delete") || lower.contains("deselect") ||
               lower.contains("unselect") || lower.contains("clear") {
                return .removeDate(dates: uniqueDates)
            }
            
            if let times = timeRange {
                return .timeMutation(dates: uniqueDates, startMinutes: times.startMinutes, endMinutes: times.endMinutes)
            }
            
            return .selectDate(dates: uniqueDates)
        }
        
        if let times = timeRange {
            return .timeMutation(dates: [], startMinutes: times.startMinutes, endMinutes: times.endMinutes)
        }
        
        return .unknown(command: command)
    }
    
    // ── Wake Word & Keywords Helpers ──
    
    static func findFuzzyWakeWord(in text: String) -> Range<String.Index>? {
        let lowerText = text.lowercased()
        
        let candidates = [
            "hey vision", "hi vision", "hey visual", "hi visual",
            "hey reason", "hi reason", "high vision", "hay vision",
            "he vision", "heavy vision", "hi-vision", "hey-vision",
            "hey vixen", "hi vixen", "hey vijin", "hi vijin",
            "hey vigen", "hi vigen", "hey vidjin", "hi vidjin",
            "hey virgin", "hi virgin", "hey beacon", "hi beacon",
            "hey vijay", "hi vijay", "high vijay", "hay vijay",
            "hey vjay", "hi vjay", "hey vejay", "hi vejay",
            "hey fidjay", "hi fidjay", "hey widget", "hi widget",
            "hey region", "hi region", "hey pigeon", "hi pigeon"
        ]
        
        let words = lowerText.split(separator: " ").map(String.init)
        if words.isEmpty { return nil }
        
        let cleanedWords = words.map { $0.filter { !$0.isPunctuation } }
        
        for i in 0..<words.count {
            for count in 1...3 {
                guard i + count <= words.count else { continue }
                
                let phrase = cleanedWords[i..<(i + count)].joined(separator: " ")
                let originalPhrase = words[i..<(i + count)].joined(separator: " ")
                
                for candidate in candidates {
                    let cleanPhrase = phrase.filter { !$0.isWhitespace }
                    let cleanCandidate = candidate.filter { !$0.isPunctuation && !$0.isWhitespace }
                    
                    let sim = normalizedSimilarity(a: cleanPhrase, b: cleanCandidate)
                    let threshold: Double = 0.85
                    
                    if sim >= threshold {
                        if let range = lowerText.range(of: originalPhrase) {
                            return range
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    static func containsCommandKeywords(_ lower: String) -> Bool {
        let exactKeywords = [
            "select", "choose", "pick", "highlight", "toggle", "mark", "tick", "check",
            "remove", "delete", "deselect", "unselect", "clear", "add", "set", "go to", "show", "log", "track",
            "navigate", "switch", "open", "copy", "export", "change", "update",
            "today", "tomorrow", "yesterday", "calendar", "timesheet", "table", "grid",
            "weekday", "weekend", "standard shift", "full day",
            "january", "february", "march", "april", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        let words = Set(lower.split(separator: " ").map(String.init))
        for kw in exactKeywords {
            if kw.contains(" ") {
                if lower.contains(kw) { return true }
            } else {
                if words.contains(kw) { return true }
            }
        }
        return false
    }
    
    // ── Levenshtein & Similarity Helpers ──
    
    private static func levenshtein(a: String, b: String) -> Int {
        let aArray = Array(a.lowercased())
        let bArray = Array(b.lowercased())
        
        if aArray.isEmpty { return bArray.count }
        if bArray.isEmpty { return aArray.count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: bArray.count + 1), count: aArray.count + 1)
        
        for i in 0...aArray.count {
            matrix[i][0] = i
        }
        for j in 0...bArray.count {
            matrix[0][j] = j
        }
        
        for i in 1...aArray.count {
            for j in 1...bArray.count {
                if aArray[i - 1] == bArray[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return matrix[aArray.count][bArray.count]
    }
    
    private static func normalizedSimilarity(a: String, b: String) -> Double {
        let dist = levenshtein(a: a, b: b)
        let maxLen = max(a.count, b.count)
        if maxLen == 0 { return 1.0 }
        return 1.0 - (Double(dist) / Double(maxLen))
    }
    
    private static func fuzzyContains(_ text: String, target: String, threshold: Double = 0.80) -> Bool {
        let lowerText = text.lowercased()
        let lowerTarget = target.lowercased()
        
        if lowerText.contains(lowerTarget) { return true }
        
        if lowerTarget.count <= 5 { return false }
        
        let targetWords = lowerTarget.split(separator: " ").map(String.init)
        let textWords = lowerText.split(separator: " ").map(String.init)
        
        if targetWords.isEmpty { return false }
        
        let windowSize = targetWords.count
        if textWords.count < windowSize {
            return normalizedSimilarity(a: lowerText, b: lowerTarget) >= threshold
        }
        
        for i in 0...(textWords.count - windowSize) {
            let windowPhrase = textWords[i..<(i + windowSize)].joined(separator: " ")
            if normalizedSimilarity(a: windowPhrase, b: lowerTarget) >= threshold {
                return true
            }
        }
        return false
    }
    
    // ── Preprocessing & Normalization ──
    
    private static func preprocessTimeWords(_ text: String) -> String {
        var lower = text.lowercased()
        
        lower = lower.replacingOccurrences(of: "nine thirty", with: "9:30")
        lower = lower.replacingOccurrences(of: "eight thirty", with: "8:30")
        lower = lower.replacingOccurrences(of: "seven thirty", with: "7:30")
        lower = lower.replacingOccurrences(of: "half past nine", with: "9:30")
        lower = lower.replacingOccurrences(of: "half past eight", with: "8:30")
        lower = lower.replacingOccurrences(of: "half past seven", with: "7:30")
        lower = lower.replacingOccurrences(of: "noon", with: "12")
        
        let wordNumbers = [
            ("one", "1"), ("two", "2"), ("three", "3"), ("four", "4"),
            ("five", "5"), ("six", "6"), ("seven", "7"), ("eight", "8"),
            ("nine", "9"), ("ten", "10"), ("eleven", "11"), ("twelve", "12")
        ]
        
        for (word, num) in wordNumbers {
            let pattern = "\\b\(word)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                lower = regex.stringByReplacingMatches(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower), withTemplate: num)
            }
        }
        
        let dotPattern = "\\b(\\d{1,2})\\.(\\d{2})\\b"
        if let regex = try? NSRegularExpression(pattern: dotPattern) {
            lower = regex.stringByReplacingMatches(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower), withTemplate: "$1:$2")
        }
        
        return lower
    }
    
    private static func preprocessNumbers(_ text: String) -> String {
        var lower = text.lowercased()
        
        let mappings = [
            ("twenty-first", "21"), ("twenty first", "21"), ("twenty-one", "21"), ("twenty one", "21"),
            ("twenty-second", "22"), ("twenty second", "22"), ("twenty-two", "22"), ("twenty two", "22"),
            ("twenty-third", "23"), ("twenty third", "23"), ("twenty-three", "23"), ("twenty three", "23"),
            ("twenty-fourth", "24"), ("twenty fourth", "24"), ("twenty-four", "24"), ("twenty four", "24"),
            ("twenty-fifth", "25"), ("twenty fifth", "25"), ("twenty-five", "25"), ("twenty five", "25"),
            ("twenty-sixth", "26"), ("twenty sixth", "26"), ("twenty-six", "26"), ("twenty six", "26"),
            ("twenty-seventh", "27"), ("twenty seventh", "27"), ("twenty-seven", "27"), ("twenty seven", "27"),
            ("twenty-eighth", "28"), ("twenty eighth", "28"), ("twenty-eight", "28"), ("twenty eight", "28"),
            ("twenty-ninth", "29"), ("twenty ninth", "29"), ("twenty-nine", "29"), ("twenty nine", "29"),
            ("thirty-first", "31"), ("thirty first", "31"), ("thirty-one", "31"), ("thirty one", "31"),
            ("thirteenth", "13"), ("thirteen", "13"),
            ("fourteenth", "14"), ("fourteen", "14"),
            ("fifteenth", "15"), ("fifteen", "15"),
            ("sixteenth", "16"), ("sixteen", "16"),
            ("seventeenth", "17"), ("seventeen", "17"),
            ("eighteenth", "18"), ("eighteen", "18"),
            ("nineteenth", "19"), ("nineteen", "19"),
            ("twentieth", "20"), ("twenty", "20"),
            ("thirtieth", "30"), ("thirty", "30"),
            ("eleventh", "11"), ("eleven", "11"),
            ("twelfth", "12"), ("twelve", "12"),
            ("fourth", "4"), ("four", "4"),
            ("fifth", "5"), ("five", "5"),
            ("sixth", "6"), ("six", "6"),
            ("seventh", "7"), ("seven", "7"),
            ("eighth", "8"), ("eight", "8"),
            ("ninth", "9"), ("nine", "9"),
            ("tenth", "10"), ("ten", "10"),
            ("first", "1"), ("one", "1"),
            ("second", "2"), ("two", "2"),
            ("third", "3"), ("three", "3")
        ]
        
        for (word, digit) in mappings {
            let pattern = "\\b\(word)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                lower = regex.stringByReplacingMatches(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower), withTemplate: digit)
            }
        }
        
        return lower
    }
    
    private static func stripTimeRangePatterns(from text: String) -> String {
        var result = text
        
        let durationPattern = "\\b(?:for|log|track)?\\s*\\d+(?:\\.\\d+)?\\s*hours?\\s*(?:starting|beginning|at)?\\s*(?:at)?\\s*\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?\\b"
        if let regex = try? NSRegularExpression(pattern: durationPattern, options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        result = result.replacingOccurrences(of: "standard shift", with: "")
        result = result.replacingOccurrences(of: "standard day", with: "")
        result = result.replacingOccurrences(of: "full day", with: "")
        
        let rangePattern = "\\b\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?\\s*(?:to|till|until|-)\\s*\\d{1,2}(?::\\d{2})?\\s*(?:am|pm)?\\b"
        if let regex = try? NSRegularExpression(pattern: rangePattern, options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        let singleTimePattern = "\\b\\d{1,2}:\\d{2}\\b"
        if let regex = try? NSRegularExpression(pattern: singleTimePattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        return result
    }
    
    private static func extractAndRemoveDayRanges(from text: inout String, currentMonth: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentMonth)
        
        // Pattern 1: month name followed by day to day, e.g., "june 5 to 10"
        let monthDayRangePattern = "\\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+(\\d{1,2})\\s*(?:to|through|till|-)\\s*(\\d{1,2})\\b"
        if let regex = try? NSRegularExpression(pattern: monthDayRangePattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            var offset = 0
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                let currentNSString = text as NSString
                let matchedSubstr = currentNSString.substring(with: adjustedRange)
                
                if let subMatch = regex.firstMatch(in: matchedSubstr, options: [], range: NSRange(location: 0, length: matchedSubstr.count)) {
                    let monthStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 1)).lowercased()
                    let startStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 2))
                    let endStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 3))
                    
                    if let monthInt = monthIndex(for: monthStr),
                       let startDay = Int(startStr), let endDay = Int(endStr),
                       startDay >= 1 && startDay <= 31 && endDay >= 1 && endDay <= 31 && startDay < endDay {
                        
                        var comps = DateComponents()
                        comps.year = currentYear
                        comps.month = monthInt
                        
                        for d in startDay...endDay {
                            comps.day = d
                            if let date = calendar.date(from: comps) {
                                dates.append(calendar.startOfDay(for: date))
                            }
                        }
                        
                        let prevLength = text.count
                        text = (text as NSString).replacingCharacters(in: adjustedRange, with: "")
                        offset += text.count - prevLength
                    }
                }
            }
        }
        
        // Pattern 2: day to day of month, e.g., "5 to 10 of june"
        let dayRangeMonthPattern = "\\b(\\d{1,2})\\s*(?:to|through|till|-)\\s*(\\d{1,2})\\s+of\\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\b"
        if let regex = try? NSRegularExpression(pattern: dayRangeMonthPattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            var offset = 0
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                let currentNSString = text as NSString
                let matchedSubstr = currentNSString.substring(with: adjustedRange)
                
                if let subMatch = regex.firstMatch(in: matchedSubstr, options: [], range: NSRange(location: 0, length: matchedSubstr.count)) {
                    let startStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 1))
                    let endStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 2))
                    let monthStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 3)).lowercased()
                    
                    if let monthInt = monthIndex(for: monthStr),
                       let startDay = Int(startStr), let endDay = Int(endStr),
                       startDay >= 1 && startDay <= 31 && endDay >= 1 && endDay <= 31 && startDay < endDay {
                        
                        var comps = DateComponents()
                        comps.year = currentYear
                        comps.month = monthInt
                        
                        for d in startDay...endDay {
                            comps.day = d
                            if let date = calendar.date(from: comps) {
                                dates.append(calendar.startOfDay(for: date))
                            }
                        }
                        
                        let prevLength = text.count
                        text = (text as NSString).replacingCharacters(in: adjustedRange, with: "")
                        offset += text.count - prevLength
                    }
                }
            }
        }
        
        // Pattern 3: plain day range like "select 5 to 10" (no month name, defaults to current month)
        let plainDayRangePattern = "(select|remove|clear|delete|deselect|unselect|add|toggle)\\s+(\\d{1,2})\\s*(?:to|through|till|-)\\s*(\\d{1,2})\\b"
        if let regex = try? NSRegularExpression(pattern: plainDayRangePattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            var offset = 0
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                let currentNSString = text as NSString
                let matchedSubstr = currentNSString.substring(with: adjustedRange)
                
                if let subMatch = regex.firstMatch(in: matchedSubstr, options: [], range: NSRange(location: 0, length: matchedSubstr.count)) {
                    let startStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 2))
                    let endStr = (matchedSubstr as NSString).substring(with: subMatch.range(at: 3))
                    
                    if let startDay = Int(startStr), let endDay = Int(endStr),
                       startDay >= 1 && startDay <= 31 && endDay >= 1 && endDay <= 31 && startDay < endDay {
                        
                        let currentMonthInt = calendar.component(.month, from: currentMonth)
                        var comps = DateComponents()
                        comps.year = currentYear
                        comps.month = currentMonthInt
                        
                        for d in startDay...endDay {
                            comps.day = d
                            if let date = calendar.date(from: comps) {
                                dates.append(calendar.startOfDay(for: date))
                            }
                        }
                        
                        let replacementRange = subMatch.range(at: 2)
                        let fullRangeToReplace = NSRange(location: adjustedRange.location + replacementRange.location,
                                                         length: subMatch.range(at: 3).location + subMatch.range(at: 3).length - replacementRange.location)
                        
                        let prevLength = text.count
                        text = (text as NSString).replacingCharacters(in: fullRangeToReplace, with: "")
                        offset += text.count - prevLength
                    }
                }
            }
        }
        
        return dates
    }
    
    private static func monthIndex(for monthStr: String) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let longMonths = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        if let idx = longMonths.firstIndex(of: monthStr) { return idx + 1 }
        if let idx = months.firstIndex(of: monthStr) { return idx + 1 }
        return nil
    }
    
    private static func parseTimeRange(from text: String) -> ParsedTimeRange? {
        let preprocessed = preprocessTimeWords(text)
        let nsString = preprocessed as NSString
        
        // 1. Duration range pattern
        let durationPattern = "\\b(?:for|log|track)?\\s*(\\d+(?:\\.\\d+)?)\\s*hours?\\s*(?:starting|beginning|at)?\\s*(?:at)?\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\b"
        if let durRegex = try? NSRegularExpression(pattern: durationPattern, options: [.caseInsensitive]) {
            if let match = durRegex.firstMatch(in: preprocessed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let durationStr = nsString.substring(with: match.range(at: 1))
                let startHourStr = nsString.substring(with: match.range(at: 2))
                let startMinStr = match.range(at: 3).location != NSNotFound ? nsString.substring(with: match.range(at: 3)) : nil
                let startAMPM = match.range(at: 4).location != NSNotFound ? nsString.substring(with: match.range(at: 4)) : nil
                
                if let duration = Double(durationStr), var startHour = Int(startHourStr) {
                    let startMin = Int(startMinStr ?? "") ?? 0
                    
                    if let ampm = startAMPM?.lowercased() {
                        if ampm == "pm" && startHour < 12 { startHour += 12 }
                        if ampm == "am" && startHour == 12 { startHour = 0 }
                    } else {
                        if startHour < 7 { startHour += 12 }
                    }
                    
                    let startMinutes = startHour * 60 + startMin
                    let endMinutes = startMinutes + Int(duration * 60)
                    return ParsedTimeRange(startMinutes: startMinutes, endMinutes: min(endMinutes, 1440))
                }
            }
        }
        
        // 2. Standard shift keyword match
        if preprocessed.contains("standard shift") || preprocessed.contains("standard day") || preprocessed.contains("full day") {
            return ParsedTimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60) // 9:00 AM to 5:00 PM
        }
        
        // 3. Range pattern
        let pattern = "\\b(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\s*(?:to|till|until|-)\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            if let match = regex.firstMatch(in: preprocessed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let startHourStr = nsString.substring(with: match.range(at: 1))
                let startMinStr = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : nil
                let startAMPM = match.range(at: 3).location != NSNotFound ? nsString.substring(with: match.range(at: 3)) : nil
                
                let endHourStr = nsString.substring(with: match.range(at: 4))
                let endMinStr = match.range(at: 5).location != NSNotFound ? nsString.substring(with: match.range(at: 5)) : nil
                let endAMPM = match.range(at: 6).location != NSNotFound ? nsString.substring(with: match.range(at: 6)) : nil
                
                var startHour = Int(startHourStr) ?? 7
                let startMin = Int(startMinStr ?? "") ?? 0
                var endHour = Int(endHourStr) ?? 16
                let endMin = Int(endMinStr ?? "") ?? 0
                
                if let ampm = startAMPM?.lowercased() {
                    if ampm == "pm" && startHour < 12 { startHour += 12 }
                    if ampm == "am" && startHour == 12 { startHour = 0 }
                } else {
                    if startHour < 7 { startHour += 12 }
                }
                
                if let ampm = endAMPM?.lowercased() {
                    if ampm == "pm" && endHour < 12 { endHour += 12 }
                    if ampm == "am" && endHour == 12 { endHour = 0 }
                } else {
                    if endHour < startHour && endHour < 12 {
                        endHour += 12
                    } else if endHour < 7 {
                        endHour += 12
                    }
                }
                
                return ParsedTimeRange(startMinutes: startHour * 60 + startMin, endMinutes: endHour * 60 + endMin)
            }
        }
        
        // 4. Single time fallback
        let singleTimePattern = "\\b(\\d{1,2}):(\\d{2})\\b"
        if let singleRegex = try? NSRegularExpression(pattern: singleTimePattern, options: []) {
            let matches = singleRegex.matches(in: preprocessed, options: [], range: NSRange(location: 0, length: nsString.length))
            if matches.count == 1 {
                let m = matches[0]
                if let hour = Int(nsString.substring(with: m.range(at: 1))),
                   let min = Int(nsString.substring(with: m.range(at: 2))) {
                    if preprocessed.contains("till") || preprocessed.contains("to") {
                        return ParsedTimeRange(startMinutes: 7 * 60, endMinutes: hour * 60 + min)
                    } else {
                        return ParsedTimeRange(startMinutes: hour * 60 + min, endMinutes: (hour + 9) * 60 + min)
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func parseRelativeDate(from text: String) -> Date? {
        let lower = text.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if lower.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if lower.contains("today") {
            return today
        }
        if lower.contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: today)
        }
        
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, dayName) in weekdays.enumerated() {
            if lower.contains("next \(dayName)") {
                let targetWeekday = index + 1
                var comps = DateComponents()
                comps.weekday = targetWeekday
                if let nextDate = calendar.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) {
                    return calendar.startOfDay(for: nextDate)
                }
            }
        }
        return nil
    }
    
    private static func parseDates(from text: String, currentMonth: Date) -> [Date] {
        var parsedDates: [Date] = []
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentMonth)
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let date = match.date {
                    parsedDates.append(calendar.startOfDay(for: date))
                }
            }
        }
        
        var normalizedDates: [Date] = []
        for date in parsedDates {
            var comps = calendar.dateComponents([.month, .day], from: date)
            comps.year = currentYear
            if let normalized = calendar.date(from: comps) {
                normalizedDates.append(calendar.startOfDay(for: normalized))
            } else {
                normalizedDates.append(calendar.startOfDay(for: date))
            }
        }
        
        var unique: [Date] = []
        for d in normalizedDates {
            if !unique.contains(d) {
                unique.append(d)
            }
        }
        return unique
    }
    
    private static func parseWeekdayPatterns(from text: String, currentMonth: Date) -> [Date] {
        let lower = text.lowercased()
        let calendar = Calendar.current
        
        guard let monthRange = calendar.range(of: .day, in: .month, for: currentMonth),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        var datesInMonth: [Date] = []
        for day in 1...monthRange.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                datesInMonth.append(calendar.startOfDay(for: date))
            }
        }
        
        if lower.contains("weekday") {
            return datesInMonth.filter { date in
                let wd = calendar.component(.weekday, from: date)
                return wd >= 2 && wd <= 6
            }
        }
        
        if lower.contains("weekend") {
            return datesInMonth.filter { date in
                let wd = calendar.component(.weekday, from: date)
                return wd == 1 || wd == 7
            }
        }
        
        if lower.contains("all days") || lower.contains("entire month") || lower.contains("every day") || lower.contains("all of") {
            return datesInMonth
        }
        
        let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        var selectedWeekdays: [Int] = []
        
        for (index, name) in weekdayNames.enumerated() {
            if lower.contains(name) || lower.contains("\(name)s") {
                selectedWeekdays.append(index + 1)
            }
        }
        
        if !selectedWeekdays.isEmpty {
            return datesInMonth.filter { date in
                let wd = calendar.component(.weekday, from: date)
                return selectedWeekdays.contains(wd)
            }
        }
        
        return []
    }
    
    private static func parseImplicitDaysAndRanges(from text: String) -> [Int] {
        var days: [Int] = []
        let rangePattern = "\\b(\\d{1,2})\\s*(?:to|through|till|-)\\s*(\\d{1,2})\\b"
        
        if let regex = try? NSRegularExpression(pattern: rangePattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let startDay = Int(nsString.substring(with: match.range(at: 1))),
                   let endDay = Int(nsString.substring(with: match.range(at: 2))),
                   startDay >= 1 && startDay <= 31 && endDay >= 1 && endDay <= 31 && startDay < endDay {
                    days.append(contentsOf: Array(startDay...endDay))
                }
            }
        }
        
        if days.isEmpty {
            let singleDayPattern = "\\b(\\d{1,2})(?:st|nd|rd|th)?\\b"
            if let regex = try? NSRegularExpression(pattern: singleDayPattern, options: [.caseInsensitive]) {
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if let day = Int(nsString.substring(with: match.range(at: 1))),
                       day >= 1 && day <= 31 {
                        let range = match.range
                        let startIdx = max(0, range.location - 2)
                        let endIdx = min(nsString.length, range.location + range.length + 4)
                        let context = nsString.substring(with: NSRange(location: startIdx, length: endIdx - startIdx)).lowercased()
                        if !context.contains("2026") && !context.contains("2025") {
                            days.append(day)
                        }
                    }
                }
            }
        }
        
        return days
    }
}

/// Thread-safe container to hold the active speech recognition request.
/// Allows the background audio tap thread to append PCM buffers synchronously
/// without violating actor isolation or causing buffer recycling races.
final class SpeechRequestHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?
    
    var request: SFSpeechAudioBufferRecognitionRequest? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _request
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _request = newValue
        }
    }
}
