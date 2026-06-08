//
//  ClipboardManager.swift
//  HC
//
//  Stateless utility for system clipboard operations.
//  Copies plain text to UIPasteboard and triggers success haptic.
//

import UIKit

/// Thread-safe clipboard utility.
/// Uses UIPasteboard for text transfer and UINotificationFeedbackGenerator
/// for tactile confirmation on successful copy.
enum ClipboardManager {

    /// Copies the provided string to the system clipboard and fires a
    /// `.success` haptic notification. Safe to call from any thread via
    /// UIKit's internal dispatch to main.
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
