//  WhisperTranscriber.swift
//  Whisper testing
//
//  Handles running Whisper Core ML models for transcription

import Foundation
import CoreML
import AVFoundation

class WhisperTranscriber {
    private let encoder: MLModel
    private let decoder: MLModel
    private var audioBuffer: [Float] = []
    private let bufferSize = Int(AudioPreprocessor.sampleRate * 5) // 5 seconds buffer
    
    // Load vocabulary mappings
    private var tokenToId: [String: Int] = [:]
    private var idToToken: [Int: String] = [:]
    
    init?() {
        // Try to find the compiled models in the app bundle
        guard let encoderURL = Bundle.main.url(forResource: "coreml-encoder-small", withExtension: "mlmodelc"),
              let decoderURL = Bundle.main.url(forResource: "coreml-decoder-small", withExtension: "mlmodelc") else {
            print("Failed to find compiled model files in bundle.")
            print("Available bundle resources:")
            if let bundlePath = Bundle.main.resourcePath {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: bundlePath)
                print(contents?.joined(separator: ", ") ?? "No contents")
            }
            return nil
        }
        
        do {
            print("Loading compiled models from:")
            print("Encoder: \(encoderURL.path)")
            print("Decoder: \(decoderURL.path)")
            
            self.encoder = try MLModel(contentsOf: encoderURL)
            self.decoder = try MLModel(contentsOf: decoderURL)
            
            // Debug: Print model input/output feature names
            print("Encoder input features: \(encoder.modelDescription.inputDescriptionsByName.keys.sorted())")
            print("Encoder output features: \(encoder.modelDescription.outputDescriptionsByName.keys.sorted())")
            print("Decoder input features: \(decoder.modelDescription.inputDescriptionsByName.keys.sorted())")
            print("Decoder output features: \(decoder.modelDescription.outputDescriptionsByName.keys.sorted())")
            
            loadVocabulary()
            print("Models loaded successfully!")
        } catch {
            print("Failed to load models: \(error)")
            return nil
        }
    }
    
    private func loadVocabulary() {
        // Load token_to_id.json
        if let tokenPath = Bundle.main.path(forResource: "token_to_id", ofType: "json"),
           let tokenData = try? Data(contentsOf: URL(fileURLWithPath: tokenPath)),
           let tokenDict = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Int] {
            tokenToId = tokenDict
            
            // Create reverse mapping
            for (token, id) in tokenDict {
                idToToken[id] = token
            }
        }
    }
    
    func transcribe(audioBuffer: AVAudioPCMBuffer, completion: @escaping (String) -> Void) {
        guard let audioData = AudioPreprocessor.convertToWhisperFormat(buffer: audioBuffer) else {
            completion("")
            return
        }
        
        // Accumulate audio data
        self.audioBuffer.append(contentsOf: audioData)
        
        // Process when we have enough data (e.g., 3 seconds)
        let processLength = Int(AudioPreprocessor.sampleRate * 3)
        if self.audioBuffer.count >= processLength {
            let audioToProcess = Array(self.audioBuffer.prefix(processLength))
            self.audioBuffer.removeFirst(min(processLength / 2, self.audioBuffer.count)) // Keep overlap
            
            DispatchQueue.global(qos: .userInitiated).async {
                let text = self.runInference(audioData: audioToProcess)
                DispatchQueue.main.async {
                    completion(text)
                }
            }
        }
    }
    
    private func runInference(audioData: [Float]) -> String {
        do {
            // Convert audio to log-mel spectrogram
            let logMelData = convertToLogMelSpectrogram(audioData: audioData)
            
            // Prepare input for encoder with correct feature name
            let inputShape = [1, 80, logMelData.count / 80] // [batch, n_mels, time_steps]
            let multiArray = try MLMultiArray(shape: inputShape.map { NSNumber(value: $0) }, dataType: .float32)
            
            for (index, value) in logMelData.enumerated() {
                multiArray[index] = NSNumber(value: value)
            }
            
            let encoderInput = try MLDictionaryFeatureProvider(dictionary: ["logmel_data": MLFeatureValue(multiArray: multiArray)])
            let encoderOutput = try encoder.prediction(from: encoderInput)
            
            // Get encoder features for decoder
            guard let encoderFeatures = encoderOutput.featureValue(for: "output")?.multiArrayValue else {
                print("Failed to get encoder output features")
                return "Error: Could not get encoder features"
            }
            
            // Run decoder with encoder features
            let transcription = runDecoder(with: encoderFeatures)
            return transcription.isEmpty ? "Could not transcribe audio" : transcription
            
        } catch {
            print("Inference error: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func runDecoder(with encoderFeatures: MLMultiArray) -> String {
        do {
            // Whisper prompt sequence for English transcription
            let startOfTranscript = 50258  // <|startoftranscript|>
            let englishToken = 50259       // <|en|>
            let transcribeToken = 50359    // <|transcribe|>
            let noTimestamps = 50363       // <|notimestamps|>
            
            // Start with the proper prompt sequence
            var promptTokens = [startOfTranscript, englishToken, transcribeToken, noTimestamps]
            var currentTokenIndex = 0
            let maxTokens = 100
            var transcribedText = ""
            
            print("Starting decoder with prompt sequence: \(promptTokens)")
            
            for iteration in 0..<maxTokens {
                var currentToken: Int
                
                // Use prompt tokens first, then start generating
                if currentTokenIndex < promptTokens.count {
                    currentToken = promptTokens[currentTokenIndex]
                    currentTokenIndex += 1
                } else {
                    // We're past the prompt, use the last generated token
                    currentToken = promptTokens.last!
                }
                
                // Create single token input (1x1 shape as expected by model)
                let tokenArray = try MLMultiArray(shape: [1, 1], dataType: .int32)
                tokenArray[0] = NSNumber(value: currentToken)
                
                // Prepare decoder input
                let decoderInput = try MLDictionaryFeatureProvider(dictionary: [
                    "audio_data": MLFeatureValue(multiArray: encoderFeatures),
                    "token_data": MLFeatureValue(multiArray: tokenArray)
                ])
                
                let decoderOutput = try decoder.prediction(from: decoderInput)
                
                // Get next token prediction
                guard let logits = decoderOutput.featureValue(for: "output")?.multiArrayValue else {
                    print("Failed to get logits from decoder output")
                    break
                }
                
                // Get the token with highest probability
                let nextToken = getNextToken(from: logits)
                print("Iteration \(iteration): current token \(currentToken) -> next token \(nextToken)")
                
                // Check for end token
                if nextToken == 50257 { // <|endoftext|>
                    print("Found end token, stopping")
                    break
                }
                
                // Add the next token to our sequence
                if currentTokenIndex >= promptTokens.count {
                    // Only start collecting text after the prompt sequence
                    if let tokenText = idToToken[nextToken] {
                        print("Token \(nextToken) -> '\(tokenText)'")
                        // Skip special tokens (50000+ range for Whisper) but allow regular vocabulary
                        if nextToken < 50000 {
                            let cleanText = cleanTokenText(tokenText)
                            transcribedText += cleanText
                            print("Added text: '\(cleanText)', total so far: '\(transcribedText)'")
                        } else {
                            print("Skipping special token \(nextToken)")
                        }
                    } else {
                        print("Unknown token ID: \(nextToken)")
                    }
                }
                
                // Update the prompt tokens with the new token
                promptTokens.append(nextToken)
            }
            
            let finalText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Final transcribed text: '\(finalText)'")
            return finalText
            
        } catch {
            print("Decoder error: \(error)")
            return ""
        }
    }
    
    private func getNextToken(from logits: MLMultiArray) -> Int {
        // Simple greedy decoding - take the token with highest probability
        var maxValue: Float = -Float.infinity
        var maxIndex = 0
        
        let count = logits.count
        for i in 0..<count {
            let value = logits[i].floatValue
            if value > maxValue {
                maxValue = value
                maxIndex = i
            }
        }
        
        return maxIndex
    }
    
    private func cleanTokenText(_ token: String) -> String {
        // Remove Whisper-specific token prefixes and clean up
        var cleaned = token
        
        // Handle byte-pair encoding artifacts common in Whisper
        if cleaned.hasPrefix("Ġ") {
            // Ġ represents a space at the beginning of a word
            cleaned = " " + String(cleaned.dropFirst())
        }
        
        // Replace common BPE artifacts
        cleaned = cleaned.replacingOccurrences(of: "Ċ", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "ĉ", with: "\t")
        cleaned = cleaned.replacingOccurrences(of: "Ģ", with: "")
        
        // Handle unicode escape sequences if present
        if cleaned.hasPrefix("<|") && cleaned.hasSuffix("|>") {
            // This is a special token, skip it
            return ""
        }
        
        return cleaned
    }
    
    private func convertToLogMelSpectrogram(audioData: [Float]) -> [Float] {
        // Simplified log-mel conversion for demo purposes
        // In a real implementation, you would use proper FFT and mel-scale conversion
        let melBands = 80
        let timeSteps = min(3000, audioData.count / 160) // Whisper expects 3000 time steps max
        
        var logMelData = [Float]()
        
        for t in 0..<timeSteps {
            for m in 0..<melBands {
                // Simple approximation - in reality this would be proper mel-scale FFT
                let startIdx = t * 160
                let endIdx = min(startIdx + 160, audioData.count)
                let segment = Array(audioData[startIdx..<endIdx])
                
                // Basic energy calculation with mel-scale approximation
                let energy = segment.map { $0 * $0 }.reduce(0, +) / Float(segment.count)
                let logEnergy = log(max(energy, 1e-10))
                logMelData.append(logEnergy)
            }
        }
        
        // Pad or truncate to expected size
        let expectedSize = melBands * 3000
        if logMelData.count < expectedSize {
            logMelData.append(contentsOf: Array(repeating: -11.5129, count: expectedSize - logMelData.count))
        } else if logMelData.count > expectedSize {
            logMelData = Array(logMelData.prefix(expectedSize))
        }
        
        return logMelData
    }
}
