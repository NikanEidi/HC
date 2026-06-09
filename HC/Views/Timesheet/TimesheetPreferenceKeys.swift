//
//  TimesheetPreferenceKeys.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  GEOMETRY FRAME REPORTING KEYS                                ║
//  ║                                                               ║
//  ║  SwiftUI PreferenceKeys that bubble geometry frames up the    ║
//  ║  view hierarchy. Consumed by TrackerHomeView to enable the    ║
//  ║  gesture system to hit-test clicks and hover effects against  ║
//  ║  calendar cells, COPY button, time sliders, and any other    ║
//  ║  tappable UI elements.                                        ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import SwiftUI

// MARK: - Calendar Grid Frame

/// Reports the global frame of the calendar day grid so parent views
/// can map air-gesture coordinates to calendar cells.
struct CalendarGridFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Copy Button Frame

/// Reports the global frame of the COPY button so parent views
/// can detect hover gestures over it.
struct CopyButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Slider Frames

/// Metadata pairing a session's slider with its on-screen frame.
struct SliderFrameInfo: Equatable {
    let sessionID: UUID
    let isStartSlider: Bool
    let frame: CGRect
}

/// Collects global frames for every visible time slider so parent
/// views can map drag gestures to the correct slider.
struct SliderFramesKey: PreferenceKey {
    static var defaultValue: [SliderFrameInfo] = []
    static func reduce(value: inout [SliderFrameInfo], nextValue: () -> [SliderFrameInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Universal Tappable Element Tracking

/// A generic tappable UI element identified by a string ID and its global frame.
/// Used by the gesture system to hit-test clicks against any interactive element.
struct TappableElement: Equatable {
    let id: String
    let frame: CGRect
}

/// Collects global frames for all tappable elements across the view hierarchy.
struct TappableFramesKey: PreferenceKey {
    static var defaultValue: [TappableElement] = []
    static func reduce(value: inout [TappableElement], nextValue: () -> [TappableElement]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - View Modifier

extension View {
    /// Reports this view's global frame as a tappable gesture target.
    /// The `id` string is used by `TrackerHomeView` to dispatch the correct
    /// action when the gesture system detects a click inside this frame.
    func reportTappableFrame(id: String) -> some View {
        self.background(GeometryReader { geo in
            Color.clear.preference(
                key: TappableFramesKey.self,
                value: [TappableElement(id: id, frame: geo.frame(in: .global))]
            )
        })
    }
}
