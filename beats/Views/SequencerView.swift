import SwiftUI

struct StepView: View {
    let stepIndex: Int
    let step: SequenceStep
    let isCurrent: Bool
    var onTap: () -> Void
    var onProbabilityChange: (Double) -> Void

    @State private var showingProbabilitySlider = false

    var body: some View {
        VStack(spacing: 2) {
            // LED indicator
            LEDIndicator(
                state: step.isActive ? (isCurrent ? .on : .dim) : .off,
                color: TEColors.accentBright,
                size: 10
            )

            // Step number
            Text("\(stepIndex + 1)")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(step.isActive ? TEColors.textPrimary : TEColors.textTertiary)

            // Probability indicator (small bar)
            if step.isActive && step.probability < 1.0 {
                Rectangle()
                    .fill(TEColors.accentDim)
                    .frame(width: CGFloat(step.probability) * 16, height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TESpacing.xs)
        .background(isCurrent ? TEColors.surfaceElevated : Color.clear)
        .overlay(
            Rectangle()
                .stroke(isCurrent ? TEColors.borderActive : TEColors.borderLight, lineWidth: isCurrent ? 2 : 1)
        )
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            if step.isActive {
                showingProbabilitySlider = true
            }
        }
        .sheet(isPresented: $showingProbabilitySlider) {
            StepProbabilityEditor(
                step: step,
                onProbabilityChange: onProbabilityChange
            )
            .presentationDetents([.fraction(0.3)])
        }
    }
}

struct StepProbabilityEditor: View {
    let step: SequenceStep
    var onProbabilityChange: (Double) -> Void

    @State private var probability: Double
    @Environment(\.dismiss) private var dismiss

    init(step: SequenceStep, onProbabilityChange: @escaping (Double) -> Void) {
        self.step = step
        self.onProbabilityChange = onProbabilityChange
        _probability = State(initialValue: step.probability)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: TESpacing.lg) {
                TETypography.label("STEP PROBABILITY")

                Text("\(Int(probability * 100))")
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(TEColors.accentBright)

                TETypography.micro("PERCENT CHANCE TO TRIGGER")

                VStack(spacing: TESpacing.sm) {
                    Slider(value: $probability, in: 0...1, step: 0.05)
                        .tint(TEColors.accent)

                    HStack {
                        TETypography.micro("0%")
                        Spacer()
                        TETypography.micro("100%")
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(TEColors.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        onProbabilityChange(probability)
                        dismiss()
                    }
                    .foregroundColor(TEColors.accentBright)
                }
            }
        }
    }
}

struct SequencerView: View {
    @ObservedObject var viewModel: SamplerViewModel
    @ObservedObject var audioEngine = AudioEngine.shared

    let columns = Array(repeating: GridItem(.flexible(), spacing: TESpacing.gridGap), count: 16)

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            // Track selector header
            HStack {
                TETypography.label("SEQUENCER")
                Spacer()
                TETypography.value("TRACK \(String(format: "%02d", viewModel.selectedPadIndex + 1))")
            }

            // Action buttons
            HStack(spacing: TESpacing.sm) {
                Button {
                    viewModel.clearCurrentPattern()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .light))
                        Text("CLR")
                            .font(.system(size: 9, weight: .regular))
                            .tracking(0.5)
                    }
                    .foregroundColor(TEColors.textSecondary)
                }

                Button {
                    viewModel.randomizeCurrentPattern(density: 0.3)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "dice")
                            .font(.system(size: 10, weight: .light))
                        Text("RND")
                            .font(.system(size: 9, weight: .regular))
                            .tracking(0.5)
                    }
                    .foregroundColor(TEColors.textSecondary)
                }

                Spacer()

                // Pattern info
                TETypography.micro("PAT \(String(format: "%02d", viewModel.sampleBank.currentPatternIndex + 1))")

                if audioEngine.isPlaying {
                    HStack(spacing: 2) {
                        LEDIndicator(state: .blinking, color: TEColors.accentBright, size: 4)
                        TETypography.micro("STEP \(String(format: "%02d", audioEngine.currentStep + 1))")
                    }
                }
            }

            // Step grid - LED style
            LazyVGrid(columns: columns, spacing: TESpacing.gridGap) {
                ForEach(0..<16, id: \.self) { stepIndex in
                    let step = viewModel.sampleBank.currentPattern.trackSteps[viewModel.selectedPadIndex][stepIndex]
                    StepView(
                        stepIndex: stepIndex,
                        step: step,
                        isCurrent: audioEngine.isPlaying && audioEngine.currentStep == stepIndex,
                        onTap: {
                            viewModel.toggleStepForSelectedPad(at: stepIndex)
                        },
                        onProbabilityChange: { newProb in
                            viewModel.setStepProbability(
                                track: viewModel.selectedPadIndex,
                                step: stepIndex,
                                probability: newProb
                            )
                        }
                    )
                }
            }
        }
        .teCard()
    }
}

struct PatternSelectorView: View {
    @ObservedObject var viewModel: SamplerViewModel

    let columns = Array(repeating: GridItem(.flexible(), spacing: TESpacing.xs), count: 4)

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            HStack {
                TETypography.label("PATTERNS")

                Spacer()

                if viewModel.isChainMode {
                    HStack(spacing: TESpacing.xs) {
                        Button {
                            viewModel.finishChainMode()
                        } label: {
                            Text("DONE")
                                .font(.system(size: 9, weight: .regular))
                                .tracking(0.5)
                                .foregroundColor(TEColors.success)
                        }

                        Button {
                            viewModel.cancelChainMode()
                        } label: {
                            Text("CLR")
                                .font(.system(size: 9, weight: .regular))
                                .tracking(0.5)
                                .foregroundColor(TEColors.recording)
                        }
                    }
                } else {
                    Button {
                        viewModel.startChainMode()
                    } label: {
                        Text("CHAIN")
                            .font(.system(size: 9, weight: .regular))
                            .tracking(0.5)
                            .foregroundColor(TEColors.accentBright)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: TESpacing.xs) {
                ForEach(0..<16, id: \.self) { index in
                    Button {
                        if viewModel.isChainMode {
                            viewModel.chainedPatterns.append(index)
                        } else {
                            viewModel.selectPattern(index)
                        }
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(
                                    viewModel.sampleBank.currentPatternIndex == index
                                        ? TEColors.surfaceElevated
                                        : TEColors.surface
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            viewModel.sampleBank.currentPatternIndex == index
                                                ? TEColors.borderActive
                                                : TEColors.border,
                                            lineWidth: 1
                                        )
                                )

                            VStack(spacing: 2) {
                                LEDIndicator(
                                    state: viewModel.sampleBank.currentPatternIndex == index ? .on : .off,
                                    color: TEColors.accentBright,
                                    size: 4
                                )

                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundColor(
                                        viewModel.sampleBank.currentPatternIndex == index
                                            ? TEColors.textPrimary
                                            : TEColors.textSecondary
                                    )

                                if viewModel.isChainMode {
                                    let count = viewModel.chainedPatterns.filter { $0 == index }.count
                                    if count > 0 {
                                        Text("×\(count)")
                                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                                            .foregroundColor(TEColors.accentBright)
                                    }
                                }
                            }
                        }
                        .frame(height: 44)
                    }
                }
            }

            if viewModel.isChainMode && !viewModel.chainedPatterns.isEmpty {
                HStack {
                    TETypography.micro("CHAIN:")
                    Text(viewModel.chainedPatterns.map { String(format: "%02d", $0 + 1) }.joined(separator: " → "))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
            }
        }
        .teCard()
    }
}

#Preview {
    VStack {
        SequencerView(viewModel: SamplerViewModel())
        PatternSelectorView(viewModel: SamplerViewModel())
    }
    .background(TEColors.background)
}
