import SwiftUI

struct WaveformView: View {
    let audioURL: URL?
    @Binding var trimStart: Double
    @Binding var trimEnd: Double

    @State private var waveformData: [Float] = []
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(TEColors.surface)

                if isLoading {
                    ProgressView()
                        .tint(TEColors.accent)
                } else {
                    // Waveform
                    Canvas { context, size in
                        let barWidth = size.width / CGFloat(waveformData.count)
                        let midY = size.height / 2

                        for (index, amplitude) in waveformData.enumerated() {
                            let barHeight = CGFloat(amplitude) * size.height * 0.8
                            let x = CGFloat(index) * barWidth

                            // Check if this bar is within trim range
                            let normalizedPosition = CGFloat(index) / CGFloat(waveformData.count)
                            let isInRange = normalizedPosition >= CGFloat(trimStart) && normalizedPosition <= CGFloat(trimEnd)

                            let color = isInRange ? TEColors.accentBright : TEColors.textTertiary

                            var path = Path()
                            path.move(to: CGPoint(x: x + barWidth / 2, y: midY - barHeight / 2))
                            path.addLine(to: CGPoint(x: x + barWidth / 2, y: midY + barHeight / 2))
                            context.stroke(path, with: .color(color), lineWidth: max(1, barWidth - 1))
                        }
                    }

                    // Trim handles
                    HStack(spacing: 0) {
                        // Start handle
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: CGFloat(trimStart) * geometry.size.width)

                        // Start marker
                        Rectangle()
                            .fill(TEColors.success)
                            .frame(width: 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newPosition = value.location.x / geometry.size.width
                                        trimStart = max(0, min(trimEnd - 0.01, newPosition))
                                    }
                            )

                        Spacer()

                        // End marker
                        Rectangle()
                            .fill(TEColors.recording)
                            .frame(width: 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newPosition = value.location.x / geometry.size.width
                                        trimEnd = max(trimStart + 0.01, min(1, newPosition))
                                    }
                            )

                        // End spacer
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: (1 - CGFloat(trimEnd)) * geometry.size.width)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(TEColors.border, lineWidth: 1)
            )
        }
        .onAppear {
            loadWaveform()
        }
        .onChange(of: audioURL) { _, _ in
            loadWaveform()
        }
    }

    private func loadWaveform() {
        guard let url = audioURL else {
            isLoading = false
            return
        }

        isLoading = true

        Task {
            do {
                let data = try AudioEngine.shared.getWaveformData(from: url, samples: 100)
                await MainActor.run {
                    waveformData = data
                    isLoading = false
                }
            } catch {
                print("Failed to load waveform: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct TrimEditorView: View {
    @ObservedObject var viewModel: SamplerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var trimStart: Double
    @State private var trimEnd: Double

    init(viewModel: SamplerViewModel) {
        self.viewModel = viewModel
        let sample = viewModel.selectedSample
        _trimStart = State(initialValue: sample.trimStart)
        _trimEnd = State(initialValue: sample.trimEnd)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: TESpacing.lg) {
                VStack(spacing: TESpacing.sm) {
                    TETypography.label("TRIM EDITOR")

                    Text(viewModel.selectedSample.name.uppercased())
                        .font(.system(size: 16, weight: .light, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }

                WaveformView(
                    audioURL: viewModel.selectedSample.primaryAudioURL,
                    trimStart: $trimStart,
                    trimEnd: $trimEnd
                )
                .frame(height: 120)

                VStack(spacing: TESpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            TETypography.micro("START")
                            Text("\(Int(trimStart * 100))")
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.success)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            TETypography.micro("END")
                            Text("\(Int(trimEnd * 100))")
                                .font(.system(size: 18, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.recording)
                        }
                    }

                    TEDivider()

                    // Fine-tune sliders
                    VStack(spacing: TESpacing.sm) {
                        HStack {
                            TETypography.micro("IN")
                            Slider(value: $trimStart, in: 0...max(0, trimEnd - 0.01))
                                .tint(TEColors.success)
                        }

                        HStack {
                            TETypography.micro("OUT")
                            Slider(value: $trimEnd, in: min(1, trimStart + 0.01)...1)
                                .tint(TEColors.recording)
                        }
                    }
                }
                .teCard()

                // Preview button
                Button {
                    previewTrimmedSample()
                } label: {
                    HStack(spacing: TESpacing.xs) {
                        LEDIndicator(state: .dim, color: TEColors.success, size: 6)
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .light))
                        Text("PREVIEW")
                            .font(.system(size: 11, weight: .regular))
                            .tracking(1)
                    }
                    .foregroundColor(TEColors.textPrimary)
                    .padding(.horizontal, TESpacing.lg)
                    .padding(.vertical, TESpacing.sm)
                    .background(TEColors.surfaceElevated)
                    .overlay(
                        Rectangle()
                            .stroke(TEColors.borderActive, lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding(TESpacing.sm)
            .background(TEColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        dismiss()
                    }
                    .foregroundColor(TEColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SAVE") {
                        saveTrim()
                        dismiss()
                    }
                    .foregroundColor(TEColors.accentBright)
                }
            }
        }
    }

    private func previewTrimmedSample() {
        guard let url = viewModel.selectedSample.primaryAudioURL else { return }

        do {
            try AudioEngine.shared.loadTrimmedSample(
                at: viewModel.selectedPadIndex,
                from: url,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
            AudioEngine.shared.playSample(at: viewModel.selectedPadIndex)
        } catch {
            print("Failed to preview: \(error)")
        }
    }

    private func saveTrim() {
        viewModel.selectedSample.trimStart = trimStart
        viewModel.selectedSample.trimEnd = trimEnd

        // Reload sample with new trim
        if let url = viewModel.selectedSample.primaryAudioURL {
            try? AudioEngine.shared.loadTrimmedSample(
                at: viewModel.selectedPadIndex,
                from: url,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
        }
    }
}

#Preview {
    TrimEditorView(viewModel: SamplerViewModel())
        .background(TEColors.background)
}
