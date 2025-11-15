import SwiftUI

struct ControlBarView: View {
    @ObservedObject var viewModel: SamplerViewModel
    @ObservedObject var audioEngine = AudioEngine.shared

    var body: some View {
        VStack(spacing: 0) {
            TEDivider()

            VStack(spacing: TESpacing.sm) {
                // Mode buttons - calculator style
                HStack(spacing: TESpacing.xs) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        TEButton(
                            mode.rawValue,
                            icon: iconFor(mode),
                            isSelected: viewModel.currentMode == mode
                        ) {
                            viewModel.currentMode = mode
                        }
                    }
                }

                TEDivider()

                // Transport and controls
                HStack(spacing: TESpacing.md) {
                    // Record button
                    TransportButton(
                        icon: "circle.fill",
                        label: "REC",
                        isActive: audioEngine.isRecording,
                        activeColor: TEColors.recording
                    ) {
                        if audioEngine.isRecording {
                            viewModel.stopRecording()
                        } else if viewModel.selectedPadIndex >= 0 {
                            viewModel.startRecording(toSlot: viewModel.selectedPadIndex)
                        }
                    }

                    // Play/Stop button
                    TransportButton(
                        icon: audioEngine.isPlaying ? "stop.fill" : "play.fill",
                        label: audioEngine.isPlaying ? "STOP" : "PLAY",
                        isActive: audioEngine.isPlaying,
                        activeColor: TEColors.success
                    ) {
                        viewModel.togglePlayback()
                    }

                    Spacer()

                    // BPM control
                    BPMControl(bpm: Binding(
                        get: { viewModel.sampleBank.bpm },
                        set: { viewModel.setBPM($0) }
                    ))

                    // Master volume
                    VolumeControl(volume: Binding(
                        get: { viewModel.sampleBank.masterVolume },
                        set: { viewModel.setMasterVolume($0) }
                    ))
                }
            }
            .padding(TESpacing.sm)
        }
        .background(TEColors.surface)
    }

    private func iconFor(_ mode: AppMode) -> String {
        switch mode {
        case .play: return "hand.tap"
        case .sound: return "waveform"
        case .pattern: return "square.grid.3x3"
        case .write: return "pencil"
        case .fx: return "sparkle"
        case .probability: return "dice"
        }
    }
}

struct TransportButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: TESpacing.xs) {
                LEDIndicator(
                    state: isActive ? .on : .off,
                    color: activeColor,
                    size: 8
                )

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(isActive ? activeColor : TEColors.textSecondary)

                Text(label)
                    .font(.system(size: 9, weight: .regular))
                    .tracking(1)
                    .foregroundColor(TEColors.textSecondary)
            }
            .frame(width: 50)
            .padding(.vertical, TESpacing.xs)
            .background(TEColors.background)
            .overlay(
                Rectangle()
                    .stroke(isActive ? activeColor.opacity(0.5) : TEColors.border, lineWidth: 1)
            )
        }
    }
}

struct BPMControl: View {
    @Binding var bpm: Double
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 2) {
            TETypography.label("BPM")

            HStack(spacing: TESpacing.xs) {
                Button {
                    bpm = max(30, bpm - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(TEColors.textSecondary)
                }

                Text("\(Int(bpm))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(TEColors.accentBright)
                    .frame(width: 40)
                    .onTapGesture {
                        isEditing = true
                    }

                Button {
                    bpm = min(300, bpm + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(TEColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            BPMEditor(bpm: $bpm)
                .presentationDetents([.fraction(0.3)])
        }
    }
}

struct BPMEditor: View {
    @Binding var bpm: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: TESpacing.lg) {
                Text("\(Int(bpm))")
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundColor(TEColors.accentBright)

                TETypography.label("BEATS PER MINUTE")

                Slider(value: $bpm, in: 30...300, step: 1)
                    .tint(TEColors.accent)
                    .padding(.horizontal)

                HStack(spacing: TESpacing.sm) {
                    ForEach([60, 90, 120, 140, 160], id: \.self) { preset in
                        Button {
                            bpm = Double(preset)
                        } label: {
                            Text("\(preset)")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.textPrimary)
                                .padding(.horizontal, TESpacing.sm)
                                .padding(.vertical, TESpacing.xs)
                                .background(TEColors.surface)
                                .overlay(
                                    Rectangle()
                                        .stroke(TEColors.border, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(TEColors.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        dismiss()
                    }
                    .foregroundColor(TEColors.accentBright)
                }
            }
        }
    }
}

struct VolumeControl: View {
    @Binding var volume: Float

    var body: some View {
        VStack(spacing: 2) {
            TETypography.label("VOL")

            HStack(spacing: TESpacing.xs) {
                // Volume LED indicators
                ForEach(0..<5, id: \.self) { index in
                    LEDIndicator(
                        state: Float(index) / 5.0 < volume ? .on : .off,
                        color: TEColors.accentBright,
                        size: 4
                    )
                }

                Text("\(Int(volume * 100))")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(TEColors.textSecondary)
                    .frame(width: 30)
            }
        }
        .onTapGesture {
            // Cycle through volume levels
            if volume < 0.25 {
                volume = 0.5
            } else if volume < 0.75 {
                volume = 1.0
            } else {
                volume = 0.25
            }
        }
    }
}

#Preview {
    ControlBarView(viewModel: SamplerViewModel())
        .background(TEColors.background)
}
