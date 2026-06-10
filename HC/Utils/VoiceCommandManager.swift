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
    
    private var isListening = false
    private var isActiveSession = false
    
    // ── Silence / Timeout Tasks ──
    private var silenceTask: Task<Void, Never>?
    private var activeTimeoutTask: Task<Void, Never>?
    private var greetDelayTask: Task<Void, Never>?
    
    // ── Conversational Context & Memory ──
    private var lastSelectedDates: [Date] = []
    private var lastErrorSpeechTime: Date? = nil
    private let errorCooldownSeconds: TimeInterval = 4.0
    
    // ── Speech Synthesis Pipeline ──
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isSynthesizerSpeaking = false
    private var activeUtterance: AVSpeechUtterance?
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
            AVAudioApplication.requestRecordPermission { micGranted in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
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
            }
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Audio Pipeline & Listening Lifecycle
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func startListening() {
        if let engine = audioEngine, engine.isRunning {
            return
        }
        
        // Dispatch to the main thread runloop to run audio setup synchronously,
        // avoiding unsafeForcedSync warnings inside the cooperative thread pool.
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
            
            // Stop and reset to completely clear any bad CoreAudio connection graphs
            engine.stop()
            engine.reset()
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Guard format to avoid installing a tap with 0 channels
            guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
                self.addLog("[ERR] Audio hardware format has 0 channels.")
                return
            }
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard buffer.frameLength > 0 else { return }
                
                // Target-guard against mBuffers[0].mDataByteSize == 0 warnings in CoreAudio
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
        // 1. Clear and cancel any existing session cleanly
        cancelCurrentRecognitionSession()
        
        // 2. Verify hardware availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            addLog("[ERR] Speech recognition hardware offline.")
            return
        }
        
        // 3. Instantiate a new request object with dictation and bias strings
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.taskHint = .dictation
        newRequest.requiresOnDeviceRecognition = false
        newRequest.contextualStrings = [
            "Vision", "Nik", "Timesheet", "Copy", "Select", "Remove", "Deselect", "Delete", "Add",
            "Set", "Go to", "Show", "Navigate", "Switch", "Open", "Export", "Today", "Tomorrow", "Yesterday",
            "Weekdays", "Weekends", "Calendar", "Grid", "Table", "January", "February", "March",
            "April", "May", "June", "July", "August", "September", "October", "November", "December"
        ]
        self.recognitionRequest = newRequest
        
        // 4. Initialize the speech task
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
                    // Code 301/203 are user/session cancellation codes, safe to ignore
                    if nsError.code != 301 && nsError.code != 203 {
                        self.addLog("[ERR] Speech recognizer error: \(error.localizedDescription)")
                        self.speakFallbackError()
                    }
                }
                
                if isFinal {
                    // Properly nullify and stop audio processing on this request
                    if self.recognitionRequest === newRequest {
                        self.requestHolder.request = nil
                        self.recognitionRequest?.endAudio()
                        self.recognitionRequest = nil
                        self.recognitionTask?.cancel()
                        self.recognitionTask = nil
                        
                        // Attempt to restart session if we're still supposed to be listening
                        if self.isListening && !self.isSynthesizerSpeaking {
                            self.startNewRecognitionSession()
                        }
                    }
                    
                    if let engine = self.audioEngine, !engine.isRunning {
                        self.startListening()
                    }
                }
            }
        }
        
        // 5. Store task and enable the audio tap to write to the request
        self.recognitionTask = task
        self.requestHolder.request = newRequest
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - State Machine & Transcription Handling
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func processTranscript(_ text: String) {
        // Discard microphone captures while synthesized output is active
        guard !isSynthesizerSpeaking else { return }
        
        let lowerText = text.lowercased()
        
        if !isActiveSession {
            // Passive Mode: Look for the wake word
            if let wakeRange = findFuzzyWakeWord(in: lowerText) {
                isActiveSession = true
                systemStatus = "ACTIVE"
                triggerHapticFeedback(.medium)
                
                // Get transcript payload following wake word
                let commandPart = String(text.suffix(from: wakeRange.upperBound)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !commandPart.isEmpty && containsCommandKeywords(commandPart.lowercased()) {
                    // Direct command in the same breath
                    addLog("[SYS] Voice Engine: ACTIVE. Parsing command stream...")
                    liveTranscript = commandPart
                    resetTimers()
                    startSilenceTimer(seconds: 1.5)
                } else {
                    addLog("[SYS] Voice Engine: ACTIVE. Awaiting command...")
                    liveTranscript = ""
                    
                    // Schedule greeting with a 600ms delay to see if more speech is appended
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
            // Active Mode: Read command text, handle timeouts/silences
            
            // Cancel any pending greeting task if the user speaks
            greetDelayTask?.cancel()
            greetDelayTask = nil
            
            if let wakeRange = findFuzzyWakeWord(in: lowerText) {
                let commandPart = String(text.suffix(from: wakeRange.upperBound))
                liveTranscript = commandPart.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                liveTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            resetTimers()
            startSilenceTimer(seconds: 1.2)
        }
    }
    
    private func findFuzzyWakeWord(in text: String) -> Range<String.Index>? {
        let lowerText = text.lowercased()
        
        let candidates = [
            "hey vision", "hi vision", "hey visual", "hi visual",
            "hey reason", "hi reason", "high vixen", "hey switch", "hey system",
            "hay vision", "he vision", "heavy vision", "hi-vision", "hey-vision",
            "hey listen", "hi listen", "hey prison", "hi prison", "open eyes", "open your eyes"
        ]
        
        let words = lowerText.split(separator: " ").map(String.init)
        if words.isEmpty { return nil }
        
        // We try to match prefixes of 1, 2, or 3 words
        for count in (1...min(3, words.count)).reversed() {
            let prefix = words[0..<count].joined(separator: " ")
            for candidate in candidates {
                let sim = normalizedSimilarity(a: prefix, b: candidate)
                if sim >= 0.72 {
                    var wordIdx = 0
                    var currentIdx = text.startIndex
                    while currentIdx < text.endIndex && wordIdx < count {
                        while currentIdx < text.endIndex && (text[currentIdx].isWhitespace || text[currentIdx].isPunctuation) {
                            currentIdx = text.index(after: currentIdx)
                        }
                        if currentIdx >= text.endIndex { break }
                        while currentIdx < text.endIndex && !text[currentIdx].isWhitespace && !text[currentIdx].isPunctuation {
                            currentIdx = text.index(after: currentIdx)
                        }
                        wordIdx += 1
                    }
                    return text.startIndex..<currentIdx
                }
            }
        }
        
        // Fallback: check for single word "vision" or "visual"
        for singleTarget in ["vision", "visual"] {
            if let range = lowerText.range(of: singleTarget) {
                let startIdx = range.lowerBound
                if startIdx == lowerText.startIndex {
                    return range
                } else {
                    let prevCharIdx = lowerText.index(before: startIdx)
                    if lowerText[prevCharIdx].isWhitespace || lowerText[prevCharIdx].isPunctuation {
                        return range
                    }
                }
            }
        }
        
        return nil
    }
    
    private func containsCommandKeywords(_ lower: String) -> Bool {
        let keywords = [
            "select", "remove", "delete", "deselect", "add", "set", "go to", "show",
            "navigate", "switch", "open", "copy", "export", "from", "to", "till", "through",
            "today", "tomorrow", "yesterday", "jan", "feb", "mar", "apr", "may", "jun",
            "jul", "aug", "sep", "oct", "nov", "dec", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        ]
        for kw in keywords {
            if fuzzyContains(lower, target: kw) {
                return true
            }
        }
        return false
    }
    
    // Levenshtein & Fuzzy helpers
    private func levenshtein(a: String, b: String) -> Int {
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
    
    private func normalizedSimilarity(a: String, b: String) -> Double {
        let dist = levenshtein(a: a, b: b)
        let maxLen = max(a.count, b.count)
        if maxLen == 0 { return 1.0 }
        return 1.0 - (Double(dist) / Double(maxLen))
    }
    
    private func fuzzyContains(_ text: String, target: String, threshold: Double = 0.7) -> Bool {
        let lowerText = text.lowercased()
        let lowerTarget = target.lowercased()
        
        if lowerText.contains(lowerTarget) { return true }
        
        let targetWords = lowerTarget.split(separator: " ").map(String.init)
        let textWords = lowerText.split(separator: " ").map(String.init)
        
        if targetWords.isEmpty { return false }
        
        let windowSize = targetWords.count
        if textWords.count < windowSize {
            let sim = normalizedSimilarity(a: lowerText, b: lowerTarget)
            let customThreshold: Double
            if lowerTarget.count <= 3 {
                customThreshold = 0.9
            } else if lowerTarget.count <= 5 {
                customThreshold = 0.75
            } else {
                customThreshold = threshold
            }
            return sim >= customThreshold
        }
        
        for i in 0...(textWords.count - windowSize) {
            let windowPhrase = textWords[i..<(i + windowSize)].joined(separator: " ")
            let sim = normalizedSimilarity(a: windowPhrase, b: lowerTarget)
            let customThreshold: Double
            if lowerTarget.count <= 3 {
                customThreshold = 0.9
            } else if lowerTarget.count <= 5 {
                customThreshold = 0.75
            } else {
                customThreshold = threshold
            }
            if sim >= customThreshold {
                return true
            }
        }
        return false
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
    
    private func startSilenceTimer(seconds: Double = 1.2) {
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
        // Guard against executing commands while the synthesiser is active speaking
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
    // MARK: - NLP Command Parser & Executor
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func parseAndExecute(command: String) -> Bool {
        guard let vm = viewModel else { return false }
        let intent = extractIntent(from: command)
        
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
    // MARK: - NLP Parsing Helper Libraries
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func extractIntent(from command: String) -> CommandIntent {
        let lower = command.lowercased()
        
        // 0. Switch UI views
        if fuzzyContains(lower, target: "timesheet") || fuzzyContains(lower, target: "time sheet") || fuzzyContains(lower, target: "table") {
            if fuzzyContains(lower, target: "switch") || fuzzyContains(lower, target: "show") || fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "view") || fuzzyContains(lower, target: "display") || fuzzyContains(lower, target: "open") {
                return .switchView(showTimesheet: true)
            }
        }
        if fuzzyContains(lower, target: "calendar") || fuzzyContains(lower, target: "calander") || fuzzyContains(lower, target: "grid") {
            if fuzzyContains(lower, target: "switch") || fuzzyContains(lower, target: "show") || fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "view") || fuzzyContains(lower, target: "display") || fuzzyContains(lower, target: "open") {
                return .switchView(showTimesheet: false)
            }
        }
        
        // 1. Camera activation / deactivation
        if fuzzyContains(lower, target: "open your eyes") || fuzzyContains(lower, target: "open eyes") || fuzzyContains(lower, target: "open your vision") || fuzzyContains(lower, target: "open vision") {
            return .activateCamera
        }
        if fuzzyContains(lower, target: "close your eyes") || fuzzyContains(lower, target: "close eyes") || fuzzyContains(lower, target: "close your vision") || fuzzyContains(lower, target: "close vision") {
            return .deactivateCamera
        }
        
        // 2. Clipboard copy
        if fuzzyContains(lower, target: "copy") || fuzzyContains(lower, target: "export") {
            return .copyReport
        }
        
        // 3. Navigate month
        let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
                      "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if fuzzyContains(lower, target: "go to") || fuzzyContains(lower, target: "show") || fuzzyContains(lower, target: "navigate") || fuzzyContains(lower, target: "switch to") {
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
        
        // 4. Resolve dates
        var dates: [Date] = []
        
        if let relative = parseRelativeDate(from: command) {
            dates.append(relative)
        }
        
        let parsedDates = parseDates(from: command)
        dates.append(contentsOf: parsedDates)
        
        let patternDates = parseWeekdayPatterns(from: command)
        dates.append(contentsOf: patternDates)
        
        if dates.isEmpty {
            let baseDate = viewModel?.currentMonth ?? Date()
            let currentYear = Calendar.current.component(.year, from: baseDate)
            let currentMonthInt = Calendar.current.component(.month, from: baseDate)
            
            let implicitDays = parseImplicitDays(from: command)
            for day in implicitDays {
                var comps = DateComponents()
                comps.year = currentYear
                comps.month = currentMonthInt
                comps.day = day
                if let date = Calendar.current.date(from: comps) {
                    dates.append(Calendar.current.startOfDay(for: date))
                }
            }
        }
        
        // Resolve pronouns ("it", "that", "them", "those", "these") to the last active sessions
        let words = lower.split(separator: " ").map(String.init)
        let hasPronoun = words.contains("it") || words.contains("that") || words.contains("them") || words.contains("those") || words.contains("these") || words.contains("this")
        if dates.isEmpty && hasPronoun {
            dates = lastSelectedDates
            if !dates.isEmpty {
                addLog("[NLP] Pronoun resolved to: \(dates.map { formatDateShort($0) }.joined(separator: ", "))")
            }
        }
        
        var uniqueDates: [Date] = []
        for d in dates {
            let start = Calendar.current.startOfDay(for: d)
            if !uniqueDates.contains(start) {
                uniqueDates.append(start)
            }
        }
        
        // Save to conversational memory or predict missing target contexts
        if !uniqueDates.isEmpty {
            lastSelectedDates = uniqueDates
        } else if uniqueDates.isEmpty {
            if fuzzyContains(lower, target: "remove") || fuzzyContains(lower, target: "delete") || fuzzyContains(lower, target: "deselect") || fuzzyContains(lower, target: "clear") {
                uniqueDates = lastSelectedDates
            } else if parseTimeRange(from: command) != nil {
                if !lastSelectedDates.isEmpty {
                    uniqueDates = lastSelectedDates
                } else if let hovered = hoveredDate {
                    uniqueDates = [Calendar.current.startOfDay(for: hovered)]
                } else if let vm = viewModel, !vm.sessions.isEmpty {
                    uniqueDates = vm.sessions.map { Calendar.current.startOfDay(for: $0.date) }
                } else {
                    uniqueDates = [Calendar.current.startOfDay(for: Date())]
                }
            } else if fuzzyContains(lower, target: "select") || fuzzyContains(lower, target: "add") || fuzzyContains(lower, target: "mark") || fuzzyContains(lower, target: "toggle") {
                if let hovered = hoveredDate {
                    uniqueDates = [Calendar.current.startOfDay(for: hovered)]
                } else {
                    uniqueDates = [Calendar.current.startOfDay(for: Date())]
                }
            }
            
            if !uniqueDates.isEmpty {
                lastSelectedDates = uniqueDates
                addLog("[NLP] Predicted target: \(uniqueDates.map { formatDateShort($0) }.joined(separator: ", "))")
            }
        }
        
        if !uniqueDates.isEmpty {
            if fuzzyContains(lower, target: "remove") || fuzzyContains(lower, target: "delete") || fuzzyContains(lower, target: "deselect") || fuzzyContains(lower, target: "clear") {
                return .removeDate(dates: uniqueDates)
            }
            
            let timeRange = parseTimeRange(from: command)
            if let times = timeRange {
                return .timeMutation(dates: uniqueDates, startMinutes: times.start, endMinutes: times.end)
            }
            
            return .selectDate(dates: uniqueDates)
        }
        
        let timeRange = parseTimeRange(from: command)
        if let times = timeRange {
            return .timeMutation(dates: [], startMinutes: times.start, endMinutes: times.end)
        }
        
        return .unknown(command: command)
    }
    
    private func parseDates(from text: String) -> [Date] {
        var parsedDates: [Date] = []
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: viewModel?.currentMonth ?? Date())
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let date = match.date {
                    parsedDates.append(calendar.startOfDay(for: date))
                }
            }
        }
        
        let monthNamePattern = "(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
        let dayOfPattern = "(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+of\\s+\\b\(monthNamePattern)\\b"
        if let regex = try? NSRegularExpression(pattern: dayOfPattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 2 {
                    let dayStr = nsString.substring(with: match.range(at: 1))
                    let monthStr = nsString.substring(with: match.range(at: 2)).lowercased()
                    if let day = Int(dayStr), let monthInt = monthIndex(for: monthStr) {
                        var comps = DateComponents()
                        comps.year = currentYear
                        comps.month = monthInt
                        comps.day = day
                        if let date = calendar.date(from: comps) {
                            parsedDates.append(calendar.startOfDay(for: date))
                        }
                    }
                }
            }
        }
        
        let dayListPattern = "\(monthNamePattern)\\s+(\\d{1,2})(?:\\s*(?:and|to|till|through|,)\\s*(\\d{1,2}))?(?:\\s*(?:and|to|till|through|,)\\s*(\\d{1,2}))?"
        if let regex = try? NSRegularExpression(pattern: dayListPattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let monthStr = nsString.substring(with: match.range(at: 1)).lowercased()
                    guard let monthInt = monthIndex(for: monthStr) else { continue }
                    
                    var days: [Int] = []
                    for i in 2..<match.numberOfRanges {
                        let r = match.range(at: i)
                        if r.location != NSNotFound {
                            if let day = Int(nsString.substring(with: r)) {
                                days.append(day)
                            }
                        }
                    }
                    
                    let matchedSubstr = nsString.substring(with: match.range).lowercased()
                    if matchedSubstr.contains(" to ") || matchedSubstr.contains(" till ") || matchedSubstr.contains(" through ") {
                        if days.count >= 2 {
                            let start = days[0]
                            let end = days[1]
                            if start < end {
                                days = Array(start...end)
                            }
                        }
                    }
                    
                    for day in days {
                        var comps = DateComponents()
                        comps.year = currentYear
                        comps.month = monthInt
                        comps.day = day
                        if let date = calendar.date(from: comps) {
                            parsedDates.append(calendar.startOfDay(for: date))
                        }
                    }
                }
            }
        }
        
        if parsedDates.count == 2 && (text.contains(" to ") || text.contains(" till ") || text.contains(" through ")) {
            let start = parsedDates[0]
            let end = parsedDates[1]
            if start < end {
                var current = start
                var rangeDates: [Date] = []
                while current <= end {
                    rangeDates.append(current)
                    if let next = calendar.date(byAdding: .day, value: 1, to: current) {
                        current = next
                    } else {
                        break
                    }
                }
                parsedDates = rangeDates
            }
        }
        
        // Force the year of all parsed dates to be the displayed calendar year
        let targetYear = calendar.component(.year, from: viewModel?.currentMonth ?? Date())
        var normalizedDates: [Date] = []
        for date in parsedDates {
            var comps = calendar.dateComponents([.month, .day], from: date)
            comps.year = targetYear
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
        return unique.sorted()
    }
    
    private func parseRelativeDate(from text: String) -> Date? {
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
    
    private func parseImplicitDays(from text: String) -> [Int] {
        let implicitPattern = "\\b(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\b"
        guard let regex = try? NSRegularExpression(pattern: implicitPattern, options: [.caseInsensitive]) else { return [] }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var implicitDays: [Int] = []
        for match in matches {
            let dayStr = nsString.substring(with: match.range(at: 1))
            guard let day = Int(dayStr), day >= 1 && day <= 31 else { continue }
            
            let range = match.range
            let startIdx = max(0, range.location - 5)
            let endIdx = min(nsString.length, range.location + range.length + 5)
            let context = nsString.substring(with: NSRange(location: startIdx, length: endIdx - startIdx)).lowercased()
            
            if context.contains("am") || context.contains("pm") || context.contains(":") || context.contains("2026") {
                continue
            }
            implicitDays.append(day)
        }
        return implicitDays
    }
    
    private func parseTimeRange(from text: String) -> (start: Int, end: Int)? {
        let preprocessed = preprocessTimeWords(text)
        let nsString = preprocessed as NSString
        
        // 1. Duration range pattern: e.g. "log 8 hours starting at 9 AM" or "for 6.5 hours starting at 10:30"
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
                    return (startMinutes, min(endMinutes, 1440))
                }
            }
        }
        
        // 2. Standard shift keyword match
        if preprocessed.contains("standard shift") || preprocessed.contains("standard day") || preprocessed.contains("full day") {
            return (9 * 60, 17 * 60) // 9:00 AM to 5:00 PM (8 hours)
        }
        
        // 3. Range pattern: e.g. "9 to 5", "9:30 - 17:00", "9am to 6pm"
        let pattern = "\\b(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\s*(?:to|till|until|-)\\s*(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        
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
            
            return (startHour * 60 + startMin, endHour * 60 + endMin)
        }
        
        // 4. Single time fallback: e.g. "9:30" (defaults to a standard 9-hour offset)
        let singleTimePattern = "\\b(\\d{1,2}):(\\d{2})\\b"
        if let singleRegex = try? NSRegularExpression(pattern: singleTimePattern, options: []) {
            let matches = singleRegex.matches(in: preprocessed, options: [], range: NSRange(location: 0, length: nsString.length))
            if matches.count == 1 {
                let m = matches[0]
                if let hour = Int(nsString.substring(with: m.range(at: 1))),
                   let min = Int(nsString.substring(with: m.range(at: 2))) {
                    if preprocessed.contains("till") || preprocessed.contains("to") {
                        return (7 * 60, hour * 60 + min)
                    } else {
                        return (hour * 60 + min, (hour + 9) * 60 + min)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func monthIndex(for monthStr: String) -> Int? {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let longMonths = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        if let idx = longMonths.firstIndex(of: monthStr) { return idx + 1 }
        if let idx = months.firstIndex(of: monthStr) { return idx + 1 }
        return nil
    }
    
    private func parseWeekdayPatterns(from text: String) -> [Date] {
        let lower = text.lowercased()
        let calendar = Calendar.current
        let baseDate = viewModel?.currentMonth ?? Date()
        
        // Find all days in the currently displayed month
        guard let monthRange = calendar.range(of: .day, in: .month, for: baseDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) else {
            return []
        }
        
        var datesInMonth: [Date] = []
        for day in 1...monthRange.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                datesInMonth.append(calendar.startOfDay(for: date))
            }
        }
        
        // 1. "weekdays" (Mondays through Fridays)
        if lower.contains("weekday") {
            return datesInMonth.filter { date in
                let wd = calendar.component(.weekday, from: date)
                return wd >= 2 && wd <= 6
            }
        }
        
        // 2. "weekends" (Saturdays and Sundays)
        if lower.contains("weekend") {
            return datesInMonth.filter { date in
                let wd = calendar.component(.weekday, from: date)
                return wd == 1 || wd == 7
            }
        }
        
        // 3. "all days" or "entire month" or "every day"
        if lower.contains("all days") || lower.contains("entire month") || lower.contains("every day") || lower.contains("all of") {
            return datesInMonth
        }
        
        // 4. Match specific weekdays (e.g. "Mondays", "Mondays and Wednesdays", "Tuesdays")
        let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        var selectedWeekdays: [Int] = []
        
        for (index, name) in weekdayNames.enumerated() {
            if lower.contains(name) || lower.contains("\(name)s") {
                selectedWeekdays.append(index + 1)
            }
            
            let short = String(name.prefix(3))
            if short != "thu" && short != "sat" {
                let pattern = "\\b\(short)s?\\b"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) != nil {
                    selectedWeekdays.append(index + 1)
                }
            } else {
                let pattern = "\\b\(short)s?\\b|\\bthurs?\\b"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower)) != nil {
                    selectedWeekdays.append(index + 1)
                }
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
    
    private func preprocessTimeWords(_ text: String) -> String {
        var lower = text.lowercased()
        
        // Common phrases
        lower = lower.replacingOccurrences(of: "nine thirty", with: "9:30")
        lower = lower.replacingOccurrences(of: "eight thirty", with: "8:30")
        lower = lower.replacingOccurrences(of: "seven thirty", with: "7:30")
        lower = lower.replacingOccurrences(of: "half past nine", with: "9:30")
        lower = lower.replacingOccurrences(of: "half past eight", with: "8:30")
        lower = lower.replacingOccurrences(of: "half past seven", with: "7:30")
        lower = lower.replacingOccurrences(of: "noon", with: "12")
        
        // Single digits
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
        
        // Convert dot time separator (e.g. 9.30) to colon (9:30)
        let dotPattern = "\\b(\\d{1,2})\\.(\\d{2})\\b"
        if let regex = try? NSRegularExpression(pattern: dotPattern) {
            lower = regex.stringByReplacingMatches(in: lower, options: [], range: NSRange(lower.startIndex..., in: lower), withTemplate: "$1:$2")
        }
        
        return lower
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
            
            // Cleanly cancel the active recognition session to release resources
            // and avoid echo transcribing during speech synthesis.
            self.cancelCurrentRecognitionSession()
            
            let utterance = AVSpeechUtterance(string: text)
            
            let voices = AVSpeechSynthesisVoice.speechVoices()
            
            // Priority 1: Premium Male voice in US/GB English
            var selectedVoice = voices.first(where: {
                $0.gender == .male &&
                ($0.language == "en-US" || $0.language == "en-GB") &&
                $0.quality == .premium
            })
            
            // Priority 2: Enhanced Male voice in US/GB English
            if selectedVoice == nil {
                selectedVoice = voices.first(where: {
                    $0.gender == .male &&
                    ($0.language == "en-US" || $0.language == "en-GB") &&
                    $0.quality == .enhanced
                })
            }
            
            // Priority 3: Any Male English voice
            if selectedVoice == nil {
                selectedVoice = voices.first(where: {
                    $0.gender == .male &&
                    $0.language.hasPrefix("en")
                })
            }
            
            // Fallback: Default US English voice
            if selectedVoice == nil {
                selectedVoice = AVSpeechSynthesisVoice(language: "en-US")
            }
            
            utterance.voice = selectedVoice
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
            self.startNewRecognitionSession()
            self.resetTimers()
            self.startSilenceTimer(seconds: 4.0)
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let active = self.activeUtterance, ObjectIdentifier(active) == utteranceID else { return }
            self.isSynthesizerSpeaking = false
            self.activeUtterance = nil
            self.startNewRecognitionSession()
            self.resetTimers()
            self.startSilenceTimer(seconds: 4.0)
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
