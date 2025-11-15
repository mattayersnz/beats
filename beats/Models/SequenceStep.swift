import Foundation

struct SequenceStep: Identifiable, Codable {
    let id: UUID
    var isActive: Bool
    var sampleIndex: Int // Which pad (0-15) this step triggers
    var velocity: Float // 0.0 - 1.0

    // Probability settings per step
    var probability: Double // 0.0 - 1.0, chance this step fires
    var conditionType: StepCondition

    // Parameter locks (override sample defaults for this step)
    var pitchLock: Float?
    var volumeLock: Float?
    var filterCutoffLock: Float?
    var panLock: Float?

    // Randomization ranges specific to this step
    var pitchVariationRange: Float // Additional randomization on top of sample settings
    var volumeVariationRange: Float
    var timingVariationRange: Double // Microseconds

    // Micro-timing
    var microTiming: Double // -1.0 to 1.0 (fraction of step, negative = early, positive = late)

    init(
        id: UUID = UUID(),
        isActive: Bool = false,
        sampleIndex: Int = 0,
        velocity: Float = 0.8,
        probability: Double = 1.0,
        conditionType: StepCondition = .always,
        pitchLock: Float? = nil,
        volumeLock: Float? = nil,
        filterCutoffLock: Float? = nil,
        panLock: Float? = nil,
        pitchVariationRange: Float = 0.0,
        volumeVariationRange: Float = 0.0,
        timingVariationRange: Double = 0.0,
        microTiming: Double = 0.0
    ) {
        self.id = id
        self.isActive = isActive
        self.sampleIndex = sampleIndex
        self.velocity = velocity
        self.probability = probability
        self.conditionType = conditionType
        self.pitchLock = pitchLock
        self.volumeLock = volumeLock
        self.filterCutoffLock = filterCutoffLock
        self.panLock = panLock
        self.pitchVariationRange = pitchVariationRange
        self.volumeVariationRange = volumeVariationRange
        self.timingVariationRange = timingVariationRange
        self.microTiming = microTiming
    }

    func shouldTrigger(previousStepFired: Bool, loopCount: Int) -> Bool {
        guard isActive else { return false }

        // First check conditional logic
        let conditionMet: Bool
        switch conditionType {
        case .always:
            conditionMet = true
        case .never:
            conditionMet = false
        case .firstLoop:
            conditionMet = loopCount == 0
        case .notFirstLoop:
            conditionMet = loopCount > 0
        case .evenLoops:
            conditionMet = loopCount % 2 == 0
        case .oddLoops:
            conditionMet = loopCount % 2 == 1
        case .afterPreviousFired:
            conditionMet = previousStepFired
        case .afterPreviousSkipped:
            conditionMet = !previousStepFired
        case .everyNthLoop(let n):
            conditionMet = loopCount % n == 0
        }

        guard conditionMet else { return false }

        // Then apply probability
        guard probability < 1.0 else { return true }
        return Double.random(in: 0...1) <= probability
    }

    func randomizedPitch(basePitch: Float) -> Float {
        guard pitchVariationRange > 0 else { return pitchLock ?? basePitch }
        let base = pitchLock ?? basePitch
        let variation = Float.random(in: -pitchVariationRange...pitchVariationRange)
        return base + variation
    }

    func randomizedVolume(baseVolume: Float) -> Float {
        let base = volumeLock ?? baseVolume
        guard volumeVariationRange > 0 else { return base * velocity }
        let variation = Float.random(in: -volumeVariationRange...volumeVariationRange)
        return max(0.0, min(1.0, (base + variation) * velocity))
    }

    func randomizedTimingOffset() -> Double {
        guard timingVariationRange > 0 else { return 0 }
        return Double.random(in: -timingVariationRange...timingVariationRange)
    }
}

enum StepCondition: Codable, Equatable {
    case always
    case never
    case firstLoop
    case notFirstLoop
    case evenLoops
    case oddLoops
    case afterPreviousFired
    case afterPreviousSkipped
    case everyNthLoop(n: Int)

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .never: return "Never"
        case .firstLoop: return "First Loop"
        case .notFirstLoop: return "Not First Loop"
        case .evenLoops: return "Even Loops"
        case .oddLoops: return "Odd Loops"
        case .afterPreviousFired: return "After Previous Fired"
        case .afterPreviousSkipped: return "After Previous Skipped"
        case .everyNthLoop(let n): return "Every \(n)th Loop"
        }
    }

    static var allCases: [StepCondition] {
        [.always, .never, .firstLoop, .notFirstLoop, .evenLoops, .oddLoops,
         .afterPreviousFired, .afterPreviousSkipped, .everyNthLoop(n: 2)]
    }
}

extension StepCondition {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "always": self = .always
        case "never": self = .never
        case "firstLoop": self = .firstLoop
        case "notFirstLoop": self = .notFirstLoop
        case "evenLoops": self = .evenLoops
        case "oddLoops": self = .oddLoops
        case "afterPreviousFired": self = .afterPreviousFired
        case "afterPreviousSkipped": self = .afterPreviousSkipped
        case "everyNthLoop":
            let n = try container.decode(Int.self, forKey: .value)
            self = .everyNthLoop(n: n)
        default:
            self = .always
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .always:
            try container.encode("always", forKey: .type)
        case .never:
            try container.encode("never", forKey: .type)
        case .firstLoop:
            try container.encode("firstLoop", forKey: .type)
        case .notFirstLoop:
            try container.encode("notFirstLoop", forKey: .type)
        case .evenLoops:
            try container.encode("evenLoops", forKey: .type)
        case .oddLoops:
            try container.encode("oddLoops", forKey: .type)
        case .afterPreviousFired:
            try container.encode("afterPreviousFired", forKey: .type)
        case .afterPreviousSkipped:
            try container.encode("afterPreviousSkipped", forKey: .type)
        case .everyNthLoop(let n):
            try container.encode("everyNthLoop", forKey: .type)
            try container.encode(n, forKey: .value)
        }
    }
}
