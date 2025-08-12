//  DictationApp.swift
//  Whisper testing
//
//  Entry point for the Dictation app target

import SwiftUI

// This is an alternate app entry point for a separate dictation target
// Currently using the main app with conditional compilation
struct DictationApp: App {
    var body: some Scene {
        WindowGroup {
            DictationView()
        }
    }
}
