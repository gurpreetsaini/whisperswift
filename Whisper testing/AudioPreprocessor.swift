//  AudioPreprocessor.swift
//  Whisper testing
//
//  Preprocesses audio for Whisper Core ML models

import Foundation
import AVFoundation
import Accelerate

class AudioPreprocessor {
    static let sampleRate: Double = 16000
    static let melBins = 80
    static let nFFT = 400
    static let hopLength = 160
    static let chunkLength = 30 // seconds
    
    static func convertToWhisperFormat(buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let channelData = floatChannelData[0]
        
        // Convert to array
        var audioData = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        // Resample to 16kHz if needed
        if buffer.format.sampleRate != sampleRate {
            audioData = resample(audioData, from: buffer.format.sampleRate, to: sampleRate)
        }
        
        // Normalize
        let maxVal = audioData.max() ?? 1.0
        if maxVal > 0 {
            audioData = audioData.map { $0 / maxVal }
        }
        
        return audioData
    }
    
    private static func resample(_ input: [Float], from fromRate: Double, to toRate: Double) -> [Float] {
        let ratio = toRate / fromRate
        let outputLength = Int(Double(input.count) * ratio)
        var output = Array<Float>(repeating: 0, count: outputLength)
        
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let leftIndex = Int(srcIndex)
            let rightIndex = min(leftIndex + 1, input.count - 1)
            let fraction = Float(srcIndex - Double(leftIndex))
            
            if leftIndex < input.count {
                output[i] = input[leftIndex] * (1.0 - fraction) + input[rightIndex] * fraction
            }
        }
        
        return output
    }
}
