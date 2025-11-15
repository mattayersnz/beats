import Foundation

struct SampleBank: Codable {
    var samples: [Sample]
    var patterns: [Pattern]
    var currentPatternIndex: Int
    var patternChain: [Int] // Indices of patterns to play in sequence

    var bpm: Double
    var masterVolume: Float

    // Global probability controls
    var globalChaos: Double // 0.0 - 1.0, overall randomness factor
    var probabilityBias: Double // -1.0 to 1.0, lean toward sparse or dense
    var randomSeed: UInt64? // If set, use deterministic randomness

    init(
        samples: [Sample] = [],
        patterns: [Pattern] = [],
        currentPatternIndex: Int = 0,
        patternChain: [Int] = [],
        bpm: Double = 120.0,
        masterVolume: Float = 0.8,
        globalChaos: Double = 0.0,
        probabilityBias: Double = 0.0,
        randomSeed: UInt64? = nil
    ) {
        // Initialize 16 empty samples if none provided
        if samples.isEmpty {
            self.samples = (0..<16).map { index in
                Sample(name: "Pad \(index + 1)", color: SampleBank.defaultColors[index % SampleBank.defaultColors.count])
            }
        } else {
            self.samples = samples
        }

        // Initialize 16 empty patterns if none provided
        if patterns.isEmpty {
            self.patterns = (0..<16).map { index in
                Pattern(name: "Pattern \(index + 1)")
            }
        } else {
            self.patterns = patterns
        }

        self.currentPatternIndex = currentPatternIndex
        self.patternChain = patternChain.isEmpty ? [0] : patternChain
        self.bpm = bpm
        self.masterVolume = masterVolume
        self.globalChaos = globalChaos
        self.probabilityBias = probabilityBias
        self.randomSeed = randomSeed
    }

    var currentPattern: Pattern {
        get {
            guard currentPatternIndex >= 0 && currentPatternIndex < patterns.count else {
                return Pattern()
            }
            return patterns[currentPatternIndex]
        }
        set {
            guard currentPatternIndex >= 0 && currentPatternIndex < patterns.count else {
                return
            }
            patterns[currentPatternIndex] = newValue
        }
    }

    // Calculate step duration in seconds
    var stepDuration: Double {
        let beatsPerSecond = bpm / 60.0
        let stepsPerBeat = 4.0 // 16th notes
        return 1.0 / (beatsPerSecond * stepsPerBeat)
    }

    // Total memory usage estimation (in seconds)
    var estimatedMemoryUsage: Double {
        // PO-33 style: 40 seconds total
        // This is a simplification - real implementation would track actual audio duration
        Double(samples.compactMap { $0.primaryAudioURL }.count) * 2.5
    }

    static let maxMemorySeconds: Double = 40.0

    static let defaultColors: [String] = [
        "#FF6B35", // Orange
        "#F7931E", // Light Orange
        "#FFD23F", // Yellow
        "#06D6A0", // Green
        "#1B9AAA", // Teal
        "#118AB2", // Blue
        "#073B4C", // Dark Blue
        "#EF476F", // Pink
        "#FF006E", // Hot Pink
        "#8338EC", // Purple
        "#3A86FF", // Bright Blue
        "#06FFA5", // Mint
        "#FFBE0B", // Gold
        "#FB5607", // Red Orange
        "#FF9770", // Peach
        "#E9C46A"  // Sand
    ]

    mutating func setSample(at index: Int, sample: Sample) {
        guard index >= 0 && index < samples.count else { return }
        samples[index] = sample
    }

    mutating func clearSample(at index: Int) {
        guard index >= 0 && index < samples.count else { return }
        samples[index] = Sample(
            name: "Pad \(index + 1)",
            color: SampleBank.defaultColors[index % SampleBank.defaultColors.count]
        )
    }

    mutating func setPattern(at index: Int, pattern: Pattern) {
        guard index >= 0 && index < patterns.count else { return }
        patterns[index] = pattern
    }

    mutating func copyPattern(from sourceIndex: Int, to destIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < patterns.count,
              destIndex >= 0 && destIndex < patterns.count else {
            return
        }
        let source = patterns[sourceIndex]
        let copiedPattern = Pattern(
            id: UUID(),
            name: "Pattern \(destIndex + 1)",
            length: source.length,
            swing: source.swing,
            scale: source.scale,
            mutationRate: source.mutationRate,
            fillProbability: source.fillProbability,
            euclideanEnabled: source.euclideanEnabled,
            euclideanHits: source.euclideanHits,
            euclideanRotation: source.euclideanRotation,
            repeatCount: source.repeatCount
        )
        var finalPattern = copiedPattern
        finalPattern.trackSteps = source.trackSteps
        finalPattern.steps = source.steps
        patterns[destIndex] = finalPattern
    }

    mutating func addToChain(patternIndex: Int) {
        guard patternIndex >= 0 && patternIndex < patterns.count else { return }
        patternChain.append(patternIndex)
    }

    mutating func clearChain() {
        patternChain = [currentPatternIndex]
    }

    mutating func removeFromChain(at index: Int) {
        guard index >= 0 && index < patternChain.count else { return }
        patternChain.remove(at: index)
        if patternChain.isEmpty {
            patternChain = [currentPatternIndex]
        }
    }

    // Apply global chaos to all probability calculations
    func applyChaos(to probability: Double) -> Double {
        guard globalChaos > 0 else { return probability }

        let chaosAmount = Double.random(in: -globalChaos...globalChaos)
        var adjusted = probability + chaosAmount + probabilityBias * 0.2

        // Clamp to valid range
        adjusted = max(0.0, min(1.0, adjusted))
        return adjusted
    }
}
