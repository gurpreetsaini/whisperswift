//  AudioRecorder.swift
//  Whisper testing
//
//  Handles live audio capture for Whisper dictation

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let bus = 0
    private var audioFormat: AVAudioFormat
    private var bufferHandler: ((AVAudioPCMBuffer) -> Void)?
    
    override init() {
        self.inputNode = audioEngine.inputNode
        self.audioFormat = inputNode.inputFormat(forBus: bus)
        super.init()
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording(bufferHandler: @escaping (AVAudioPCMBuffer) -> Void) throws {
        self.bufferHandler = bufferHandler
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        let recordingFormat = inputNode.inputFormat(forBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 2048, format: recordingFormat) { buffer, _ in
            bufferHandler(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stopRecording() {
        inputNode.removeTap(onBus: bus)
        audioEngine.stop()
    }
}
