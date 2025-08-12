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
    private static let maxTimeSteps = 3000
    private static let padValue: Float = -11.5129
    
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

    // MARK: - Log-mel Spectrogram

    static func logMelSpectrogram(audio: [Float]) -> [Float] {
        let fftSize = nFFT
        let hop = hopLength
        let fftBins = fftSize / 2

        let window = vDSP.window(ofType: Float.self, usingCoefficientSequence: .hannDenormalized, count: fftSize, isHalfWindow: false)
        guard let dft = vDSP.DFT(count: fftSize, direction: .forward, transformType: .real, ofType: Float.self) else {
            return Array(repeating: padValue, count: melBins * maxTimeSteps)
        }

        let filterBank = melFilterBank

        var logMels = Array(repeating: padValue, count: melBins * maxTimeSteps)

        let frameCount = min(maxTimeSteps, max(0, (audio.count - fftSize) / hop + 1))

        for frame in 0..<frameCount {
            let start = frame * hop
            let end = start + fftSize
            if end <= audio.count {
                var segment = Array(audio[start..<end])
                vDSP.multiply(segment, window, result: &segment)

                var real = [Float](repeating: 0, count: fftBins)
                var imag = [Float](repeating: 0, count: fftBins)

                segment.withUnsafeBufferPointer { inputPtr in
                    real.withUnsafeMutableBufferPointer { realPtr in
                        imag.withUnsafeMutableBufferPointer { imagPtr in
                            dft.transform(inputPtr.baseAddress!, realOutput: realPtr.baseAddress!, imagOutput: imagPtr.baseAddress!)
                        }
                    }
                }

                var power = [Float](repeating: 0, count: fftBins)
                vDSP.squareMagnitudes(realParts: real, imagParts: imag, result: &power)

                for m in 0..<melBins {
                    var energy: Float = 0
                    vDSP_dotpr(power, 1, filterBank[m], 1, &energy, vDSP_Length(fftBins))
                    energy = log(max(energy, 1e-10))
                    logMels[m * maxTimeSteps + frame] = energy
                }
            }
        }

        return logMels
    }

    private static let melFilterBank: [[Float]] = {
        let fftSize = nFFT
        let fftBins = fftSize / 2
        var filterBank = Array(repeating: [Float](repeating: 0, count: fftBins), count: melBins)

        let fMin: Float = 0
        let fMax = Float(sampleRate) / 2
        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        let melPoints = (0..<(melBins + 2)).map { i -> Float in
            let frac = Float(i) / Float(melBins + 1)
            return melMin + frac * (melMax - melMin)
        }

        let hzPoints = melPoints.map { melToHz($0) }
        let binPoints = hzPoints.map { Int((Float(fftSize) * $0) / Float(sampleRate)) }

        for m in 1...melBins {
            let f0 = binPoints[m - 1]
            let f1 = binPoints[m]
            let f2 = binPoints[m + 1]
            if f2 <= f0 { continue }

            if f1 > f0 {
                for k in f0..<f1 {
                    if k < fftBins {
                        filterBank[m - 1][k] = Float(k - f0) / Float(max(f1 - f0, 1))
                    }
                }
            }
            if f2 > f1 {
                for k in f1..<f2 {
                    if k < fftBins {
                        filterBank[m - 1][k] = Float(f2 - k) / Float(max(f2 - f1, 1))
                    }
                }
            }
        }

        return filterBank
    }()

    private static func hzToMel(_ hz: Float) -> Float {
        return 2595 * log10(1 + hz / 700)
    }

    private static func melToHz(_ mel: Float) -> Float {
        return 700 * (pow(10, mel / 2595) - 1)
    }
}
