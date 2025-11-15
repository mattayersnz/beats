import Foundation
import Combine

// Global probability presets and settings
struct ProbabilityPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String

    // Global settings
    var globalChaos: Double
    var probabilityBias: Double

    // Default step settings
    var defaultStepProbability: Double
    var defaultPitchVariation: Float
    var defaultVolumeVariation: Float
    var defaultTimingVariation: Double

    // Pattern settings
    var mutationRate: Double
    var fillProbability: Double

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        globalChaos: Double = 0.0,
        probabilityBias: Double = 0.0,
        defaultStepProbability: Double = 1.0,
        defaultPitchVariation: Float = 0.0,
        defaultVolumeVariation: Float = 0.0,
        defaultTimingVariation: Double = 0.0,
        mutationRate: Double = 0.0,
        fillProbability: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.globalChaos = globalChaos
        self.probabilityBias = probabilityBias
        self.defaultStepProbability = defaultStepProbability
        self.defaultPitchVariation = defaultPitchVariation
        self.defaultVolumeVariation = defaultVolumeVariation
        self.defaultTimingVariation = defaultTimingVariation
        self.mutationRate = mutationRate
        self.fillProbability = fillProbability
    }

    // Built-in presets
    static let tight = ProbabilityPreset(
        name: "Tight",
        description: "No randomness, precise timing",
        globalChaos: 0.0,
        probabilityBias: 0.0,
        defaultStepProbability: 1.0,
        defaultPitchVariation: 0.0,
        defaultVolumeVariation: 0.0,
        defaultTimingVariation: 0.0,
        mutationRate: 0.0,
        fillProbability: 0.0
    )

    static let humanFeel = ProbabilityPreset(
        name: "Human Feel",
        description: "Subtle variations like a human player",
        globalChaos: 0.1,
        probabilityBias: 0.0,
        defaultStepProbability: 1.0,
        defaultPitchVariation: 0.05,
        defaultVolumeVariation: 0.1,
        defaultTimingVariation: 5.0, // 5ms
        mutationRate: 0.0,
        fillProbability: 0.0
    )

    static let sparse = ProbabilityPreset(
        name: "Sparse",
        description: "Less dense, more silence",
        globalChaos: 0.2,
        probabilityBias: -0.3,
        defaultStepProbability: 0.7,
        defaultPitchVariation: 0.1,
        defaultVolumeVariation: 0.15,
        defaultTimingVariation: 10.0,
        mutationRate: 0.05,
        fillProbability: 0.0
    )

    static let dense = ProbabilityPreset(
        name: "Dense",
        description: "More notes, fuller sound",
        globalChaos: 0.15,
        probabilityBias: 0.3,
        defaultStepProbability: 0.9,
        defaultPitchVariation: 0.05,
        defaultVolumeVariation: 0.1,
        defaultTimingVariation: 3.0,
        mutationRate: 0.02,
        fillProbability: 0.1
    )

    static let chaos = ProbabilityPreset(
        name: "Chaos",
        description: "High randomness, unpredictable",
        globalChaos: 0.8,
        probabilityBias: 0.0,
        defaultStepProbability: 0.6,
        defaultPitchVariation: 1.0,
        defaultVolumeVariation: 0.3,
        defaultTimingVariation: 20.0,
        mutationRate: 0.2,
        fillProbability: 0.15
    )

    static let evolving = ProbabilityPreset(
        name: "Evolving",
        description: "Pattern slowly changes over time",
        globalChaos: 0.3,
        probabilityBias: 0.0,
        defaultStepProbability: 0.85,
        defaultPitchVariation: 0.2,
        defaultVolumeVariation: 0.15,
        defaultTimingVariation: 8.0,
        mutationRate: 0.1,
        fillProbability: 0.05
    )

    static let glitch = ProbabilityPreset(
        name: "Glitch",
        description: "Stuttery, broken feel",
        globalChaos: 0.5,
        probabilityBias: 0.1,
        defaultStepProbability: 0.75,
        defaultPitchVariation: 2.0,
        defaultVolumeVariation: 0.4,
        defaultTimingVariation: 15.0,
        mutationRate: 0.15,
        fillProbability: 0.2
    )

    static let allPresets: [ProbabilityPreset] = [
        .tight, .humanFeel, .sparse, .dense, .chaos, .evolving, .glitch
    ]
}

// Probability visualization data
struct ProbabilityHistoryEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let stepIndex: Int
    let shouldHaveFired: Bool
    let actuallyFired: Bool
    let probability: Double

    init(stepIndex: Int, shouldHaveFired: Bool, actuallyFired: Bool, probability: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.stepIndex = stepIndex
        self.shouldHaveFired = shouldHaveFired
        self.actuallyFired = actuallyFired
        self.probability = probability
    }
}

// Track probability outcomes for visualization
class ProbabilityTracker: ObservableObject {
    @Published var history: [ProbabilityHistoryEntry] = []
    @Published var totalAttempts: Int = 0
    @Published var successfulTriggers: Int = 0

    let maxHistorySize = 256

    var successRate: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulTriggers) / Double(totalAttempts)
    }

    func record(stepIndex: Int, shouldHaveFired: Bool, actuallyFired: Bool, probability: Double) {
        let entry = ProbabilityHistoryEntry(
            stepIndex: stepIndex,
            shouldHaveFired: shouldHaveFired,
            actuallyFired: actuallyFired,
            probability: probability
        )

        history.append(entry)

        if shouldHaveFired {
            totalAttempts += 1
            if actuallyFired {
                successfulTriggers += 1
            }
        }

        // Trim history to max size
        if history.count > maxHistorySize {
            history.removeFirst(history.count - maxHistorySize)
        }
    }

    func reset() {
        history.removeAll()
        totalAttempts = 0
        successfulTriggers = 0
    }

    // Get heat map data for visualization
    func heatMapData() -> [Int: Double] {
        var stepCounts: [Int: Int] = [:]
        var stepFires: [Int: Int] = [:]

        for entry in history {
            stepCounts[entry.stepIndex, default: 0] += 1
            if entry.actuallyFired {
                stepFires[entry.stepIndex, default: 0] += 1
            }
        }

        var heatMap: [Int: Double] = [:]
        for (step, count) in stepCounts {
            let fires = stepFires[step, default: 0]
            heatMap[step] = Double(fires) / Double(count)
        }

        return heatMap
    }
}
