import Foundation

struct Pattern: Identifiable, Codable {
    let id: UUID
    var name: String
    var steps: [SequenceStep] // 16 steps per track
    var trackSteps: [[SequenceStep]] // 16 tracks (one per pad), each with 16 steps

    var length: Int // Number of active steps (1-64, typically 16)
    var swing: Double // 0.0 - 1.0, amount of swing
    var scale: Double // Pattern speed multiplier (0.5 = half speed, 2.0 = double)

    // Global pattern probability settings
    var mutationRate: Double // 0.0 - 1.0, how much pattern changes over time
    var fillProbability: Double // 0.0 - 1.0, chance of adding random fills

    // Generative settings
    var euclideanEnabled: Bool
    var euclideanHits: Int // Number of hits in euclidean pattern
    var euclideanRotation: Int // Rotation offset

    // Chain info
    var repeatCount: Int // How many times to play before moving to next pattern

    init(
        id: UUID = UUID(),
        name: String = "Pattern",
        length: Int = 16,
        swing: Double = 0.0,
        scale: Double = 1.0,
        mutationRate: Double = 0.0,
        fillProbability: Double = 0.0,
        euclideanEnabled: Bool = false,
        euclideanHits: Int = 4,
        euclideanRotation: Int = 0,
        repeatCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.length = length
        self.swing = swing
        self.scale = scale
        self.mutationRate = mutationRate
        self.fillProbability = fillProbability
        self.euclideanEnabled = euclideanEnabled
        self.euclideanHits = euclideanHits
        self.euclideanRotation = euclideanRotation
        self.repeatCount = repeatCount

        // Initialize with 16 tracks, each with 16 steps
        self.trackSteps = (0..<16).map { trackIndex in
            (0..<16).map { _ in
                SequenceStep(sampleIndex: trackIndex)
            }
        }

        // Legacy single track support (for backward compatibility)
        self.steps = (0..<16).map { _ in SequenceStep() }
    }

    // Get steps for a specific track (pad)
    func stepsForTrack(_ trackIndex: Int) -> [SequenceStep] {
        guard trackIndex >= 0 && trackIndex < trackSteps.count else {
            return []
        }
        return trackSteps[trackIndex]
    }

    // Set step for a specific track and position
    mutating func setStep(track: Int, position: Int, step: SequenceStep) {
        guard track >= 0 && track < trackSteps.count,
              position >= 0 && position < trackSteps[track].count else {
            return
        }
        trackSteps[track][position] = step
    }

    // Toggle step active state
    mutating func toggleStep(track: Int, position: Int) {
        guard track >= 0 && track < trackSteps.count,
              position >= 0 && position < trackSteps[track].count else {
            return
        }
        trackSteps[track][position].isActive.toggle()
    }

    // Clear all steps
    mutating func clearAllSteps() {
        for trackIndex in 0..<trackSteps.count {
            for stepIndex in 0..<trackSteps[trackIndex].count {
                trackSteps[trackIndex][stepIndex].isActive = false
            }
        }
    }

    // Clear steps for specific track
    mutating func clearTrack(_ trackIndex: Int) {
        guard trackIndex >= 0 && trackIndex < trackSteps.count else { return }
        for stepIndex in 0..<trackSteps[trackIndex].count {
            trackSteps[trackIndex][stepIndex].isActive = false
        }
    }

    // Apply Euclidean rhythm to a track
    mutating func applyEuclidean(track: Int, hits: Int, steps: Int, rotation: Int) {
        guard track >= 0 && track < trackSteps.count else { return }

        let pattern = EuclideanRhythm.generate(hits: hits, steps: steps, rotation: rotation)

        for (index, isHit) in pattern.enumerated() {
            if index < trackSteps[track].count {
                trackSteps[track][index].isActive = isHit
            }
        }
    }

    // Mutate pattern based on mutation rate
    mutating func mutate() {
        guard mutationRate > 0 else { return }

        for trackIndex in 0..<trackSteps.count {
            for stepIndex in 0..<trackSteps[trackIndex].count {
                if Double.random(in: 0...1) < mutationRate {
                    // Randomly modify the step
                    let mutationType = Int.random(in: 0..<4)
                    switch mutationType {
                    case 0:
                        // Toggle active state
                        trackSteps[trackIndex][stepIndex].isActive.toggle()
                    case 1:
                        // Modify probability
                        let delta = Double.random(in: -0.2...0.2)
                        trackSteps[trackIndex][stepIndex].probability = max(0, min(1, trackSteps[trackIndex][stepIndex].probability + delta))
                    case 2:
                        // Modify velocity
                        let delta = Float.random(in: -0.2...0.2)
                        trackSteps[trackIndex][stepIndex].velocity = max(0, min(1, trackSteps[trackIndex][stepIndex].velocity + delta))
                    case 3:
                        // Modify micro timing
                        let delta = Double.random(in: -0.1...0.1)
                        trackSteps[trackIndex][stepIndex].microTiming = max(-1, min(1, trackSteps[trackIndex][stepIndex].microTiming + delta))
                    default:
                        break
                    }
                }
            }
        }
    }

    // Randomize pattern with density control
    mutating func randomize(density: Double) {
        for trackIndex in 0..<trackSteps.count {
            for stepIndex in 0..<trackSteps[trackIndex].count {
                trackSteps[trackIndex][stepIndex].isActive = Double.random(in: 0...1) < density
                if trackSteps[trackIndex][stepIndex].isActive {
                    trackSteps[trackIndex][stepIndex].velocity = Float.random(in: 0.5...1.0)
                    trackSteps[trackIndex][stepIndex].probability = Double.random(in: 0.7...1.0)
                }
            }
        }
    }
}

// Euclidean rhythm generator
struct EuclideanRhythm {
    static func generate(hits: Int, steps: Int, rotation: Int = 0) -> [Bool] {
        guard steps > 0 else { return [] }
        guard hits > 0 else { return Array(repeating: false, count: steps) }
        guard hits <= steps else { return Array(repeating: true, count: steps) }

        var pattern = bjorklund(hits: hits, steps: steps)

        // Apply rotation
        if rotation != 0 {
            let normalizedRotation = ((rotation % steps) + steps) % steps
            let rotated = Array(pattern[normalizedRotation...]) + Array(pattern[..<normalizedRotation])
            pattern = rotated
        }

        return pattern
    }

    private static func bjorklund(hits: Int, steps: Int) -> [Bool] {
        var pattern: [[Bool]] = []

        // Initialize with hits and rests
        for _ in 0..<hits {
            pattern.append([true])
        }
        for _ in 0..<(steps - hits) {
            pattern.append([false])
        }

        var divisor = steps - hits

        repeat {
            let moveCount = min(divisor, pattern.count - divisor)

            // Distribute rests among hits
            for i in 0..<moveCount {
                pattern[i].append(contentsOf: pattern[pattern.count - 1])
                pattern.removeLast()
            }

            divisor = pattern.count - moveCount
        } while divisor > 1 && pattern.count > divisor

        // Flatten the pattern
        return pattern.flatMap { $0 }
    }
}
