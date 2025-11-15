import Foundation
import AVFoundation

enum PlaybackMode: String, Codable, CaseIterable {
    case oneShot = "One Shot"
    case loop = "Loop"
    case gate = "Gate"
}

enum SampleTriggerBehavior: String, Codable, CaseIterable {
    case retrigger = "Retrigger"
    case choke = "Choke"
    case polyphonic = "Polyphonic"
}

struct SampleVariation: Identifiable, Codable {
    let id: UUID
    var audioURL: URL
    var weight: Double // Probability weight for selection (0.0 - 1.0)
    var name: String

    init(id: UUID = UUID(), audioURL: URL, weight: Double = 1.0, name: String = "") {
        self.id = id
        self.audioURL = audioURL
        self.weight = weight
        self.name = name.isEmpty ? audioURL.lastPathComponent : name
    }
}

struct Sample: Identifiable, Codable {
    let id: UUID
    var name: String
    var primaryAudioURL: URL?
    var variations: [SampleVariation]

    // Trim settings (normalized 0.0 - 1.0)
    var trimStart: Double
    var trimEnd: Double
    var fadeIn: Double // Fade in duration as percentage of sample length
    var fadeOut: Double // Fade out duration as percentage of sample length

    // Playback settings
    var playbackMode: PlaybackMode
    var triggerBehavior: SampleTriggerBehavior
    var volume: Float // 0.0 - 1.0
    var pitch: Float // In semitones, -24 to +24
    var pan: Float // -1.0 (left) to 1.0 (right)

    // Probability settings
    var triggerProbability: Double // 0.0 - 1.0, chance this sample plays when triggered
    var pitchVariation: Float // Random pitch variation in semitones
    var volumeVariation: Float // Random volume variation
    var timingVariation: Double // Random timing offset in ms

    // Filter settings
    var filterCutoff: Float // 0.0 - 1.0 (normalized frequency)
    var filterResonance: Float // 0.0 - 1.0
    var filterEnabled: Bool

    // Visual
    var color: String // Hex color for UI

    init(
        id: UUID = UUID(),
        name: String = "Empty",
        primaryAudioURL: URL? = nil,
        variations: [SampleVariation] = [],
        trimStart: Double = 0.0,
        trimEnd: Double = 1.0,
        fadeIn: Double = 0.0,
        fadeOut: Double = 0.0,
        playbackMode: PlaybackMode = .oneShot,
        triggerBehavior: SampleTriggerBehavior = .retrigger,
        volume: Float = 0.8,
        pitch: Float = 0.0,
        pan: Float = 0.0,
        triggerProbability: Double = 1.0,
        pitchVariation: Float = 0.0,
        volumeVariation: Float = 0.0,
        timingVariation: Double = 0.0,
        filterCutoff: Float = 1.0,
        filterResonance: Float = 0.0,
        filterEnabled: Bool = false,
        color: String = "#FF6B35"
    ) {
        self.id = id
        self.name = name
        self.primaryAudioURL = primaryAudioURL
        self.variations = variations
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.playbackMode = playbackMode
        self.triggerBehavior = triggerBehavior
        self.volume = volume
        self.pitch = pitch
        self.pan = pan
        self.triggerProbability = triggerProbability
        self.pitchVariation = pitchVariation
        self.volumeVariation = volumeVariation
        self.timingVariation = timingVariation
        self.filterCutoff = filterCutoff
        self.filterResonance = filterResonance
        self.filterEnabled = filterEnabled
        self.color = color
    }

    var hasAudio: Bool {
        primaryAudioURL != nil || !variations.isEmpty
    }

    var hasVariations: Bool {
        variations.count > 1 || (variations.count == 1 && primaryAudioURL != nil)
    }

    // Select a sample URL based on weighted probability
    func selectAudioURL() -> URL? {
        guard hasAudio else { return nil }

        if variations.isEmpty {
            return primaryAudioURL
        }

        if variations.count == 1 && primaryAudioURL == nil {
            return variations.first?.audioURL
        }

        // Build weighted selection pool
        var pool: [URL] = []
        var weights: [Double] = []

        if let primary = primaryAudioURL {
            pool.append(primary)
            weights.append(1.0) // Primary has weight 1.0
        }

        for variation in variations {
            pool.append(variation.audioURL)
            weights.append(variation.weight)
        }

        // Normalize weights
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return primaryAudioURL }

        let random = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0

        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if random < cumulative {
                return pool[index]
            }
        }

        return pool.last
    }

    // Apply randomization to get actual playback parameters
    func randomizedVolume() -> Float {
        guard volumeVariation > 0 else { return volume }
        let variation = Float.random(in: -volumeVariation...volumeVariation)
        return max(0.0, min(1.0, volume + variation))
    }

    func randomizedPitch() -> Float {
        guard pitchVariation > 0 else { return pitch }
        let variation = Float.random(in: -pitchVariation...pitchVariation)
        return pitch + variation
    }

    func randomizedTimingOffset() -> Double {
        guard timingVariation > 0 else { return 0 }
        return Double.random(in: -timingVariation...timingVariation)
    }

    func shouldTrigger() -> Bool {
        guard triggerProbability < 1.0 else { return true }
        return Double.random(in: 0...1) <= triggerProbability
    }
}
