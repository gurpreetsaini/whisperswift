//  DictationView.swift
//  Whisper testing
//
//  Created for live dictation using Whisper model

import SwiftUI
import AVFoundation

struct DictationView: View {
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var errorMessage = ""
    @StateObject private var audioRecorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Live Dictation")
                .font(.largeTitle)
                .bold()
            
            ScrollView {
                Text(transcribedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            .frame(height: 300)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button(action: {
                isRecording.toggle()
                if isRecording {
                    startRecording()
                } else {
                    stopRecording()
                }
            }) {
                Text(isRecording ? "Stop Dictation" : "Start Dictation")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                transcribedText = ""
                errorMessage = ""
            }) {
                Text("Clear Text")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - Audio Recording & Whisper Integration
    func startRecording() {
        errorMessage = ""
        guard let transcriber = transcriber else {
            errorMessage = "Whisper model not loaded. Check that the Core ML models are included in the app bundle."
            isRecording = false
            return
        }
        
        audioRecorder.requestMicrophonePermission { granted in
            if granted {
                do {
                    try self.audioRecorder.startRecording { buffer in
                        transcriber.transcribe(audioBuffer: buffer) { text in
                            DispatchQueue.main.async {
                                if !text.isEmpty {
                                    self.transcribedText += text + " "
                                }
                            }
                        }
                    }
                } catch {
                    self.errorMessage = "Failed to start audio: \(error.localizedDescription)"
                    self.isRecording = false
                }
            } else {
                self.errorMessage = "Microphone permission denied."
                self.isRecording = false
            }
        }
    }

    func stopRecording() {
        audioRecorder.stopRecording()
    }
}

#Preview {
    DictationView()
}
