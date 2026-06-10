//
//  HCApp.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  APPLICATION ENTRY POINT                                      ║
//  ║                                                               ║
//  ║  Bootstraps the HC (Hour Counter) app with a single           ║
//  ║  WindowGroup scene. Enforces dark color scheme globally       ║
//  ║  to maintain the Midnight Forge aesthetic across all views.   ║
//  ╚═══════════════════════════════════════════════════════════════╝
//
//  Created by Nikan Eidi on 5/29/26.
//

import SwiftUI

/// The root application entry point for HC (Hour Counter).
///
/// Configures a single `WindowGroup` scene containing `TrackerHomeView`
/// and locks the entire app to `.dark` color scheme to preserve the
/// Midnight Forge cyberpunk aesthetic.
@main
struct HCApp: App {
    var body: some Scene {
        WindowGroup {
            TrackerHomeView()
                .preferredColorScheme(.dark)
        }
    }
}
