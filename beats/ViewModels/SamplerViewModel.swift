import SwiftUI
import Combine
import UniformTypeIdentifiers

enum AppMode: String, CaseIterable {
    case play = "Play"
    case sound = "Sound"
    case pattern = "Pattern"
    case write = "Write"
    case fx = "FX"
    case probability = "Chance"
}

enum XYParameterBank: String, CaseIterable {
    case tone = "Tone"
    case filter = "Filter"
    case effects = "Effects"
    case probability = "Probability"
}

@MainActor
final class SamplerViewModel: ObservableObject {
    @Published var sampleBank: SampleBank
    @Published var selectedPadIndex: Int = 0
    @Published var currentMode: AppMode = .play
    @Published var xyParameterBank: XYParameterBank = .tone

    @Published var isRecordingToSlot: Bool = false
    @Published var recordingTargetSlot: Int = -1

    @Published var showingFilePicker: Bool = false
    @Published var showingTrimView: Bool = false
    @Published var showingPatternChainView: Bool = false

    @Published var xyPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)

    // Pattern chain building
    @Published var isChainMode: Bool = false
    @Published var chainedPatterns: [Int] = []

    // Recent pad triggers for visual feedback
    @Published var recentlyTriggeredPads: Set<Int> = []

    private var cancellables = Set<AnyCancellable>()
    private let audioEngine = AudioEngine.shared

    init() {
        self.sampleBank = SampleBank()
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Update XY position when selected pad changes
        $selectedPadIndex
            .sink { [weak self] index in
                self?.updateXYForSelectedPad()
            }
            .store(in: &cancellables)

        // Apply XY changes in real-time
        $xyPosition
            .sink { [weak self] position in
                self?.applyXYPosition(position)
            }
            .store(in: &cancellables)
    }

    var selectedSample: Sample {
        get {
            guard selectedPadIndex >= 0 && selectedPadIndex < sampleBank.samples.count else {
                return Sample()
            }
            return sampleBank.samples[selectedPadIndex]
        }
        set {
            guard selectedPadIndex >= 0 && selectedPadIndex < sampleBank.samples.count else { return }
            sampleBank.samples[selectedPadIndex] = newValue
        }
    }

    var currentPattern: Pattern {
        get { sampleBank.currentPattern }
        set { sampleBank.currentPattern = newValue }
    }

    // MARK: - Pad Actions

    func triggerPad(_ index: Int) {
        guard index >= 0 && index < sampleBank.samples.count else { return }

        let sample = sampleBank.samples[index]

        // Check if sample should trigger based on probability
        guard sample.shouldTrigger() else { return }

        // Get audio URL (with variation support)
        guard let audioURL = sample.selectAudioURL() else { return }

        do {
            // Load and play with randomized parameters
            try audioEngine.loadTrimmedSample(
                at: index,
                from: audioURL,
                trimStart: sample.trimStart,
                trimEnd: sample.trimEnd
            )

            let volume = sample.randomizedVolume() * sampleBank.masterVolume
            let pitch = sample.randomizedPitch()

            audioEngine.playSample(at: index, volume: volume, pitch: pitch, pan: sample.pan)

            // Visual feedback
            recentlyTriggeredPads.insert(index)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                recentlyTriggeredPads.remove(index)
            }
        } catch {
            print("Failed to trigger pad \(index): \(error)")
        }
    }

    func selectPad(_ index: Int) {
        selectedPadIndex = index
    }

    func longPressPad(_ index: Int) {
        selectedPadIndex = index

        switch currentMode {
        case .sound:
            // Show recording/import options
            showingFilePicker = true
        case .write:
            // Toggle step in sequencer
            toggleStepForSelectedPad(at: audioEngine.currentStep)
        case .pattern:
            if isChainMode {
                chainedPatterns.append(index)
            } else {
                selectPattern(index)
            }
        case .probability:
            // Show probability settings for this pad
            break
        default:
            showingFilePicker = true
        }
    }

    // MARK: - Recording

    func startRecording(toSlot index: Int) {
        guard index >= 0 && index < 16 else { return }

        do {
            recordingTargetSlot = index
            let url = try audioEngine.startRecording()
            isRecordingToSlot = true
            print("Recording to slot \(index) at \(url)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecordingToSlot else { return }

        if let url = audioEngine.stopRecording() {
            // Create new sample with recorded audio
            var sample = sampleBank.samples[recordingTargetSlot]
            sample.primaryAudioURL = url
            sample.name = "Rec \(recordingTargetSlot + 1)"
            sample.trimStart = 0.0
            sample.trimEnd = 1.0
            sampleBank.samples[recordingTargetSlot] = sample

            // Load into engine
            do {
                try audioEngine.loadSample(at: recordingTargetSlot, from: url)
            } catch {
                print("Failed to load recorded sample: \(error)")
            }

            // Show trim view
            selectedPadIndex = recordingTargetSlot
            showingTrimView = true
        }

        isRecordingToSlot = false
        recordingTargetSlot = -1
    }

    // MARK: - File Import

    func importFile(_ url: URL, toSlot index: Int) {
        do {
            // Copy file to app's documents directory
            let localURL = try audioEngine.copyAudioFile(from: url)

            var sample = sampleBank.samples[index]
            sample.primaryAudioURL = localURL
            sample.name = url.deletingPathExtension().lastPathComponent
            sample.trimStart = 0.0
            sample.trimEnd = 1.0
            sampleBank.samples[index] = sample

            try audioEngine.loadSample(at: index, from: localURL)

            selectedPadIndex = index
            showingTrimView = true
        } catch {
            print("Failed to import file: \(error)")
        }
    }

    // MARK: - Sequencer Controls

    func togglePlayback() {
        audioEngine.toggleSequencer(bank: sampleBank)
    }

    func toggleStepForSelectedPad(at stepIndex: Int) {
        guard stepIndex >= 0 && stepIndex < 16 else { return }
        sampleBank.currentPattern.toggleStep(track: selectedPadIndex, position: stepIndex)
    }

    func setStepProbability(track: Int, step: Int, probability: Double) {
        var pattern = sampleBank.currentPattern
        pattern.trackSteps[track][step].probability = probability
        sampleBank.currentPattern = pattern
    }

    // MARK: - Pattern Management

    func selectPattern(_ index: Int) {
        guard index >= 0 && index < sampleBank.patterns.count else { return }
        sampleBank.currentPatternIndex = index
    }

    func startChainMode() {
        isChainMode = true
        chainedPatterns = []
    }

    func finishChainMode() {
        if !chainedPatterns.isEmpty {
            sampleBank.patternChain = chainedPatterns
        }
        isChainMode = false
    }

    func cancelChainMode() {
        isChainMode = false
        chainedPatterns = []
    }

    func clearCurrentPattern() {
        sampleBank.currentPattern.clearAllSteps()
    }

    func randomizeCurrentPattern(density: Double) {
        var pattern = sampleBank.currentPattern
        pattern.randomize(density: density)
        sampleBank.currentPattern = pattern
    }

    func applyEuclidean(hits: Int, steps: Int = 16, rotation: Int = 0) {
        var pattern = sampleBank.currentPattern
        pattern.applyEuclidean(track: selectedPadIndex, hits: hits, steps: steps, rotation: rotation)
        sampleBank.currentPattern = pattern
    }

    // MARK: - XY Pad Control

    func updateXYForSelectedPad() {
        let sample = selectedSample

        switch xyParameterBank {
        case .tone:
            // X: Pitch (-24 to +24 semitones) -> 0.0 to 1.0
            let normalizedPitch = (sample.pitch + 24) / 48.0
            // Y: Volume (0.0 to 1.0)
            xyPosition = CGPoint(x: CGFloat(normalizedPitch), y: CGFloat(sample.volume))

        case .filter:
            // X: Filter Cutoff (0.0 to 1.0)
            // Y: Filter Resonance (0.0 to 1.0)
            xyPosition = CGPoint(x: CGFloat(sample.filterCutoff), y: CGFloat(sample.filterResonance))

        case .effects:
            // X: Trigger Probability (0.0 to 1.0)
            // Y: Pitch Variation (0.0 to 1.0, representing 0-12 semitones)
            let normalizedPitchVar = sample.pitchVariation / 12.0
            xyPosition = CGPoint(x: CGFloat(sample.triggerProbability), y: CGFloat(normalizedPitchVar))

        case .probability:
            // X: Trigger Probability
            // Y: Timing Variation (0-50ms normalized to 0.0-1.0)
            let normalizedTiming = sample.timingVariation / 50.0
            xyPosition = CGPoint(x: CGFloat(sample.triggerProbability), y: CGFloat(normalizedTiming))
        }
    }

    func applyXYPosition(_ position: CGPoint) {
        var sample = selectedSample

        switch xyParameterBank {
        case .tone:
            // X: Pitch (-24 to +24)
            sample.pitch = Float(position.x) * 48.0 - 24.0
            // Y: Volume (0.0 to 1.0)
            sample.volume = Float(position.y)

        case .filter:
            sample.filterCutoff = Float(position.x)
            sample.filterResonance = Float(position.y)
            sample.filterEnabled = true

        case .effects:
            sample.triggerProbability = Double(position.x)
            // Pitch variation 0-12 semitones
            sample.pitchVariation = Float(position.y) * 12.0

        case .probability:
            sample.triggerProbability = Double(position.x)
            // Timing variation 0-50ms
            sample.timingVariation = Double(position.y) * 50.0
        }

        selectedSample = sample
    }

    // MARK: - Probability Presets

    func applyProbabilityPreset(_ preset: ProbabilityPreset) {
        sampleBank.globalChaos = preset.globalChaos
        sampleBank.probabilityBias = preset.probabilityBias

        var pattern = sampleBank.currentPattern
        pattern.mutationRate = preset.mutationRate
        pattern.fillProbability = preset.fillProbability
        sampleBank.currentPattern = pattern

        // Apply to all samples
        for i in 0..<sampleBank.samples.count {
            sampleBank.samples[i].pitchVariation = preset.defaultPitchVariation
            sampleBank.samples[i].volumeVariation = preset.defaultVolumeVariation
            sampleBank.samples[i].timingVariation = preset.defaultTimingVariation
        }

        // Apply default step probability to all active steps
        for trackIndex in 0..<pattern.trackSteps.count {
            for stepIndex in 0..<pattern.trackSteps[trackIndex].count {
                pattern.trackSteps[trackIndex][stepIndex].probability = preset.defaultStepProbability
            }
        }
        sampleBank.currentPattern = pattern
    }

    // MARK: - BPM Control

    func setBPM(_ bpm: Double) {
        sampleBank.bpm = max(30, min(300, bpm))

        // Restart sequencer if playing to apply new tempo
        if audioEngine.isPlaying {
            audioEngine.stopSequencer()
            audioEngine.startSequencer(bank: sampleBank)
        }
    }

    func setMasterVolume(_ volume: Float) {
        sampleBank.masterVolume = max(0, min(1, volume))
    }

    // MARK: - Save/Load

    func saveProject(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sampleBank)
        try data.write(to: url)
    }

    func loadProject(from url: URL) throws {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: url)
        sampleBank = try decoder.decode(SampleBank.self, from: data)

        // Reload all samples into audio engine
        for (index, sample) in sampleBank.samples.enumerated() {
            if let audioURL = sample.primaryAudioURL {
                try? audioEngine.loadTrimmedSample(
                    at: index,
                    from: audioURL,
                    trimStart: sample.trimStart,
                    trimEnd: sample.trimEnd
                )
            }
        }
    }
}
