import AVFoundation
import Combine

@MainActor
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var samplePlayers: [Int: AVAudioPlayerNode] = [:]
    private var sampleBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var audioFiles: [Int: AVAudioFile] = [:]

    @Published var isRunning = false
    @Published var isRecording = false
    @Published var currentRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?

    // Sequencer state
    @Published var isPlaying = false
    @Published var currentStep: Int = 0
    private var sequencerTimer: Timer?
    private var loopCount: Int = 0
    private var previousStepFired: Bool = false

    // Probability tracking
    let probabilityTracker = ProbabilityTracker()

    private init() {
        setupAudioSession()
        setupEngine()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
            recordingSession = session
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func setupEngine() {
        // Attach mixer to engine
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        // Create 16 player nodes for samples
        for i in 0..<16 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: nil)
            samplePlayers[i] = player
        }
    }

    func start() {
        guard !isRunning else { return }

        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
        stopSequencer()
    }

    // MARK: - Sample Loading

    func loadSample(at index: Int, from url: URL) throws {
        guard index >= 0 && index < 16 else { return }

        let audioFile = try AVAudioFile(forReading: url)
        audioFiles[index] = audioFile

        // Read the audio file into a buffer
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)
        sampleBuffers[index] = buffer
    }

    func loadTrimmedSample(at index: Int, from url: URL, trimStart: Double, trimEnd: Double) throws {
        guard index >= 0 && index < 16 else { return }

        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let totalFrames = audioFile.length

        let startFrame = AVAudioFramePosition(Double(totalFrames) * trimStart)
        let endFrame = AVAudioFramePosition(Double(totalFrames) * trimEnd)
        let frameCount = AVAudioFrameCount(endFrame - startFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }

        audioFile.framePosition = startFrame
        try audioFile.read(into: buffer, frameCount: frameCount)
        sampleBuffers[index] = buffer
        audioFiles[index] = audioFile
    }

    func unloadSample(at index: Int) {
        sampleBuffers.removeValue(forKey: index)
        audioFiles.removeValue(forKey: index)
    }

    // MARK: - Sample Playback

    func playSample(at index: Int, volume: Float = 1.0, pitch: Float = 0.0, pan: Float = 0.0) {
        guard let player = samplePlayers[index],
              let buffer = sampleBuffers[index] else {
            return
        }

        if !isRunning {
            start()
        }

        // Stop any currently playing audio on this pad
        player.stop()

        // Apply pitch shift using rate change
        // pitch is in semitones, convert to rate
        let rate = pow(2.0, pitch / 12.0)

        // Schedule the buffer with pitch shift
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        // Apply volume and pan
        player.volume = volume
        player.pan = pan

        // Apply pitch through rate change (this affects timing too)
        // For proper pitch shifting without time change, we'd need more sophisticated processing
        // For now, this gives a basic pitch effect
        if pitch != 0 {
            player.rate = Float(rate)
        } else {
            player.rate = 1.0
        }

        player.play()
    }

    func stopSample(at index: Int) {
        samplePlayers[index]?.stop()
    }

    func stopAllSamples() {
        for player in samplePlayers.values {
            player.stop()
        }
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Date().timeIntervalSince1970
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Int(timestamp)).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()

        isRecording = true
        currentRecordingURL = audioFilename

        return audioFilename
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false

        let url = currentRecordingURL
        currentRecordingURL = nil
        audioRecorder = nil

        return url
    }

    // MARK: - Sequencer

    func startSequencer(bank: SampleBank) {
        guard !isPlaying else { return }

        if !isRunning {
            start()
        }

        isPlaying = true
        currentStep = 0
        loopCount = 0
        previousStepFired = false

        let stepDuration = bank.stepDuration

        sequencerTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.advanceSequencer(bank: bank)
            }
        }
    }

    func stopSequencer() {
        sequencerTimer?.invalidate()
        sequencerTimer = nil
        isPlaying = false
        currentStep = 0
        stopAllSamples()
    }

    func toggleSequencer(bank: SampleBank) {
        if isPlaying {
            stopSequencer()
        } else {
            startSequencer(bank: bank)
        }
    }

    private func advanceSequencer(bank: SampleBank) {
        let pattern = bank.currentPattern

        // Process each track at current step
        var anyStepFiredThisStep = false

        for trackIndex in 0..<pattern.trackSteps.count {
            let step = pattern.trackSteps[trackIndex][currentStep]

            guard step.isActive else { continue }

            // Check if step should trigger based on probability and conditions
            let shouldFire = step.shouldTrigger(previousStepFired: previousStepFired, loopCount: loopCount)

            // Apply global chaos
            let adjustedProbability = bank.applyChaos(to: step.probability)
            let actuallyFires = shouldFire && Double.random(in: 0...1) <= adjustedProbability

            // Track for visualization
            probabilityTracker.record(
                stepIndex: currentStep,
                shouldHaveFired: step.isActive,
                actuallyFired: actuallyFires,
                probability: adjustedProbability
            )

            if actuallyFires {
                anyStepFiredThisStep = true

                // Get the sample for this track
                guard trackIndex < bank.samples.count else { continue }
                let sample = bank.samples[trackIndex]

                // Check sample trigger probability
                guard sample.shouldTrigger() else { continue }

                // Get randomized parameters
                let volume = step.randomizedVolume(baseVolume: sample.randomizedVolume())
                let pitch = step.randomizedPitch(basePitch: sample.randomizedPitch())
                let pan = step.panLock ?? sample.pan

                // Apply timing variation (for now just play immediately, timing would need more sophisticated scheduling)
                playSample(at: trackIndex, volume: volume, pitch: pitch, pan: pan)
            }
        }

        previousStepFired = anyStepFiredThisStep

        // Apply pattern mutation if enabled
        if pattern.mutationRate > 0 && Double.random(in: 0...1) < 0.1 {
            // Mutation happens occasionally, not every step
            // This would need to update the actual pattern in the bank
        }

        // Advance step
        currentStep += 1
        if currentStep >= pattern.length {
            currentStep = 0
            loopCount += 1
        }
    }

    // MARK: - Waveform Analysis

    nonisolated func getWaveformData(from url: URL, samples: Int = 100) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            return []
        }

        let totalFrames = Int(buffer.frameLength)
        let samplesPerPoint = totalFrames / samples

        var waveformData: [Float] = []
        for i in 0..<samples {
            let startIndex = i * samplesPerPoint
            let endIndex = min(startIndex + samplesPerPoint, totalFrames)

            var maxAmplitude: Float = 0
            for j in startIndex..<endIndex {
                let amplitude = abs(channelData[j])
                maxAmplitude = max(maxAmplitude, amplitude)
            }
            waveformData.append(maxAmplitude)
        }

        return waveformData
    }

    // MARK: - Audio File Management

    nonisolated func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    nonisolated func deleteAudioFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated func copyAudioFile(from sourceURL: URL) throws -> URL {
        let documentsPath = getDocumentsDirectory()
        let timestamp = Date().timeIntervalSince1970
        let destinationURL = documentsPath.appendingPathComponent("sample_\(Int(timestamp)).\(sourceURL.pathExtension)")

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}

enum AudioEngineError: Error {
    case bufferCreationFailed
    case fileReadFailed
    case recordingFailed
}
