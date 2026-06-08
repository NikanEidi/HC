//
//  HCApp.swift
//  HC
//
//  Created by Nikan Eidi on 5/29/26.
//

import SwiftUI

@main
struct HCApp: App {
    var body: some Scene {
        WindowGroup {
            TrackerHomeView()
                .preferredColorScheme(.dark)
        }
    }
}
