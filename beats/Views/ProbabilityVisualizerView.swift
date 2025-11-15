import SwiftUI

struct ProbabilityVisualizerView: View {
    @ObservedObject var tracker: ProbabilityTracker

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            // Header
            HStack {
                TETypography.label("PROBABILITY TRACKER")

                Spacer()

                Button {
                    tracker.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(TEColors.textSecondary)
                }
            }

            TEDivider()

            // Success rate
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    TETypography.micro("HIT RATE")
                    Text("\(Int(tracker.successRate * 100))")
                        .font(.system(size: 32, weight: .light, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    TETypography.micro("TRIGGERS")
                    Text("\(tracker.successfulTriggers)/\(tracker.totalAttempts)")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.textPrimary)
                }
            }

            // Heat map
            HeatMapView(data: tracker.heatMapData())
                .frame(height: 50)

            // History trail
            HistoryTrailView(history: Array(tracker.history.suffix(32)))
                .frame(height: 30)
        }
        .teCard()
    }
}

struct HeatMapView: View {
    let data: [Int: Double]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<16, id: \.self) { stepIndex in
                let intensity = data[stepIndex] ?? 0

                Rectangle()
                    .fill(heatColor(intensity: intensity))
                    .frame(maxWidth: .infinity)
                    .overlay(
                        VStack(spacing: 1) {
                            Text(String(format: "%02d", stepIndex + 1))
                                .font(.system(size: 7, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.textTertiary)
                            if intensity > 0 {
                                Text("\(Int(intensity * 100))")
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .foregroundColor(TEColors.textPrimary)
                            }
                        }
                    )
            }
        }
        .overlay(
            Rectangle()
                .stroke(TEColors.border, lineWidth: 1)
        )
    }

    private func heatColor(intensity: Double) -> Color {
        if intensity == 0 {
            return TEColors.surface
        } else {
            // Monochrome heat: darker to brighter yellow
            return TEColors.accentDim.opacity(intensity * 0.8 + 0.2)
        }
    }
}

struct HistoryTrailView: View {
    let history: [ProbabilityHistoryEntry]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !history.isEmpty else { return }

                let pointWidth = size.width / CGFloat(max(history.count, 1))

                for (index, entry) in history.enumerated() {
                    let x = CGFloat(index) * pointWidth + pointWidth / 2

                    // Draw probability line (subtle dots)
                    let probY = size.height * (1 - CGFloat(entry.probability))
                    var probPath = Path()
                    probPath.addEllipse(in: CGRect(x: x - 1, y: probY - 1, width: 2, height: 2))
                    context.fill(probPath, with: .color(TEColors.textTertiary))

                    // Draw actual trigger indicator
                    if entry.actuallyFired {
                        var triggerPath = Path()
                        triggerPath.addRect(CGRect(x: x - 2, y: size.height - 8, width: 4, height: 8))
                        context.fill(triggerPath, with: .color(TEColors.accentBright))
                    } else if entry.shouldHaveFired {
                        // Should have fired but didn't (probability blocked it)
                        var missPath = Path()
                        missPath.addRect(CGRect(x: x - 0.5, y: size.height - 8, width: 1, height: 8))
                        context.fill(missPath, with: .color(TEColors.recording))
                    }
                }
            }
        }
        .background(TEColors.surface)
        .overlay(
            Rectangle()
                .stroke(TEColors.border, lineWidth: 1)
        )
    }
}

struct ProbabilityPresetSelector: View {
    @ObservedObject var viewModel: SamplerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TESpacing.sm) {
                    ForEach(ProbabilityPreset.allPresets) { preset in
                        Button {
                            viewModel.applyProbabilityPreset(preset)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: TESpacing.xs) {
                                Text(preset.name.uppercased())
                                    .font(.system(size: 12, weight: .regular))
                                    .tracking(1)
                                    .foregroundColor(TEColors.accentBright)

                                Text(preset.description)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(TEColors.textSecondary)

                                TEDivider()

                                HStack(spacing: TESpacing.md) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        TETypography.micro("CHAOS")
                                        Text("\(Int(preset.globalChaos * 100))")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                            .foregroundColor(TEColors.textPrimary)
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        TETypography.micro("MUTATION")
                                        Text("\(Int(preset.mutationRate * 100))")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                            .foregroundColor(TEColors.textPrimary)
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        TETypography.micro("TIMING")
                                        Text("\(Int(preset.defaultTimingVariation))")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                            .foregroundColor(TEColors.textPrimary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .teCard()
                        }
                    }
                }
                .padding(TESpacing.sm)
            }
            .background(TEColors.background)
            .navigationTitle("PRESETS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        dismiss()
                    }
                    .foregroundColor(TEColors.textSecondary)
                }
            }
        }
    }
}

struct GlobalChaosControl: View {
    @ObservedObject var viewModel: SamplerViewModel
    @State private var showingPresets = false

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            HStack {
                TETypography.label("GLOBAL RANDOMNESS")

                Spacer()

                Button {
                    showingPresets = true
                } label: {
                    Text("PRESETS")
                        .font(.system(size: 9, weight: .regular))
                        .tracking(0.5)
                        .foregroundColor(TEColors.textPrimary)
                        .padding(.horizontal, TESpacing.sm)
                        .padding(.vertical, TESpacing.xs)
                        .background(TEColors.surfaceElevated)
                        .overlay(
                            Rectangle()
                                .stroke(TEColors.borderActive, lineWidth: 1)
                        )
                }
            }

            TEDivider()

            VStack(spacing: TESpacing.sm) {
                HStack {
                    TETypography.micro("CHAOS")
                    Spacer()
                    Text("\(Int(viewModel.sampleBank.globalChaos * 100))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
                Slider(value: Binding(
                    get: { viewModel.sampleBank.globalChaos },
                    set: { viewModel.sampleBank.globalChaos = $0 }
                ), in: 0...1)
                .tint(TEColors.accent)

                HStack {
                    TETypography.micro("BIAS")
                    Spacer()
                    Text(biasLabel.uppercased())
                        .font(.system(size: 10, weight: .regular))
                        .tracking(0.5)
                        .foregroundColor(TEColors.textSecondary)
                }
                Slider(value: Binding(
                    get: { viewModel.sampleBank.probabilityBias },
                    set: { viewModel.sampleBank.probabilityBias = $0 }
                ), in: -1...1)
                .tint(TEColors.accent)
            }

            TEDivider()

            HStack {
                TETypography.micro("MUTATION RATE")
                Spacer()
                Text("\(Int(viewModel.currentPattern.mutationRate * 100))")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(TEColors.accentBright)
            }
            Slider(value: Binding(
                get: { viewModel.currentPattern.mutationRate },
                set: {
                    var pattern = viewModel.currentPattern
                    pattern.mutationRate = $0
                    viewModel.sampleBank.currentPattern = pattern
                }
            ), in: 0...1)
            .tint(TEColors.accent)
        }
        .teCard()
        .sheet(isPresented: $showingPresets) {
            ProbabilityPresetSelector(viewModel: viewModel)
        }
    }

    private var biasLabel: String {
        if viewModel.sampleBank.probabilityBias < -0.3 {
            return "sparse"
        } else if viewModel.sampleBank.probabilityBias > 0.3 {
            return "dense"
        } else {
            return "neutral"
        }
    }
}

#Preview {
    VStack {
        ProbabilityVisualizerView(tracker: ProbabilityTracker())
        GlobalChaosControl(viewModel: SamplerViewModel())
    }
    .padding()
    .background(TEColors.background)
}
