//
//  Whisper_testingApp.swift
//  Whisper testing
//
//  Created by Gurjit on 12/8/2025.
//

import SwiftUI

@main
struct Whisper_testingApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DictationView()
        }
    }
}
