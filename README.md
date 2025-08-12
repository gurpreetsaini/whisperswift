# WhisperSwift - Live Dictation App

A real-time speech-to-text iOS app using Whisper Core ML models, built for iPhone 13 Pro Max with SwiftUI.

## Features

- 🎤 **Live Audio Recording** with real-time microphone access
- 🧠 **Whisper Core ML Integration** for accurate speech recognition
- 📱 **iOS 18.5+ Support** optimized for iPhone 13 Pro Max
- ⚡ **Real-time Transcription** with start/stop/clear controls
- 🔧 **Complete Audio Pipeline** with preprocessing and format conversion

## Architecture

### Core Components

- **DictationView.swift** - Main SwiftUI interface with recording controls
- **AudioRecorder.swift** - AVFoundation-based live audio capture
- **WhisperTranscriber.swift** - Core ML Whisper model inference engine
- **AudioPreprocessor.swift** - Audio format conversion and preprocessing
- **DictationApp.swift** - Main app entry point

### Technical Implementation

- **Encoder-Decoder Architecture**: Proper Whisper model integration with correct feature mapping
- **Token Sequence Handling**: English transcription with proper prompt tokens
- **Audio Processing**: Log-mel spectrogram conversion for Whisper input
- **Real-time Performance**: Optimized for live dictation with buffering

## Setup Instructions

### Prerequisites

- Xcode 16.0+
- iOS 18.5+
- iPhone 13 Pro Max (or simulator)

### Model Files

**Important**: The Whisper Core ML model files are too large for GitHub (>100MB each). You need to obtain them separately:

1. **Required Model Files**:
   - `coreml-encoder-small.mlpackage/Data/com.apple.CoreML/weights/weight.bin`
   - `coreml-decoder-small.mlpackage/Data/com.apple.CoreML/weights/weight.bin`

2. **How to Get Models**:
   - Download from [Hugging Face Whisper Core ML models](https://huggingface.co/models?other=whisper)
   - Or convert from original Whisper models using Apple's Core ML tools
   - Place the weight files in the respective directories shown above

3. **Verification**:
   ```
   Whisper testing/
   ├── coreml-encoder-small.mlpackage/
   │   └── Data/com.apple.CoreML/weights/weight.bin (~168MB)
   └── coreml-decoder-small.mlpackage/
       └── Data/com.apple.CoreML/weights/weight.bin (~292MB)
   ```

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/gurpreetsaini/whisperswift.git
   cd whisperswift
   ```

2. **Add model weight files** (see Model Files section above)

3. **Open in Xcode**:
   ```bash
   open "Whisper testing.xcodeproj"
   ```

4. **Build and run** on iPhone 13 Pro Max simulator or device

### Permissions

The app automatically requests microphone permissions. Make sure to allow microphone access when prompted.

## Usage

1. **Launch the app** on your iPhone 13 Pro Max
2. **Grant microphone permission** when prompted
3. **Tap "Start Recording"** to begin live dictation
4. **Speak clearly** into the microphone
5. **View real-time transcription** in the text display
6. **Tap "Stop Recording"** to pause transcription
7. **Tap "Clear"** to reset the text

## Technical Details

### Model Configuration

- **Encoder Input**: Log-mel spectrogram (80 mel bands, up to 3000 time steps)
- **Decoder Input**: Audio features + token sequence (1x1 shape)
- **Token Sequence**: Start → English → Transcribe → No Timestamps
- **Output**: English text tokens with proper BPE decoding

### Performance Optimizations

- **Buffered Audio Processing**: 3-second windows with overlap
- **Background Inference**: Core ML runs on background queue
- **Memory Management**: Efficient audio buffer handling
- **Debug Logging**: Comprehensive token-level debugging

### Known Issues

- Model files must be downloaded separately due to GitHub size limits
- Requires iOS 18.5+ for full functionality
- Best performance on iPhone 13 Pro Max or newer

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on device
5. Submit a pull request

## License

This project is open source. Please ensure you comply with Whisper model licensing terms.

## Acknowledgments

- OpenAI for the Whisper model architecture
- Apple for Core ML framework
- Community contributors for model conversion tools
