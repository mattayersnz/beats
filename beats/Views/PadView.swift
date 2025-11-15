import SwiftUI

struct PadView: View {
    let index: Int
    let sample: Sample
    let isSelected: Bool
    let isTriggered: Bool
    let isStepActive: Bool // For sequencer visualization

    var onTap: () -> Void
    var onLongPress: () -> Void

    @State private var isPressed = false

    private var padColor: Color {
        TEColors.padColors[index % TEColors.padColors.count]
    }

    private var backgroundColor: Color {
        if sample.hasAudio {
            if isPressed || isTriggered {
                return padColor
            } else {
                return padColor.opacity(0.6)
            }
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return TEColors.accentBright
        } else if isStepActive {
            return TEColors.accentBright.opacity(0.7)
        } else {
            return TEColors.border
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background - sharp corners, industrial look
            Rectangle()
                .fill(backgroundColor)
                .overlay(
                    Rectangle()
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Top row: Number and LED
                HStack {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.textSecondary)

                    Spacer()

                    // Status LED
                    LEDIndicator(
                        state: ledState,
                        color: ledColor,
                        size: 6
                    )
                }

                Spacer()

                // Bottom: Sample info
                if sample.hasAudio {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sample.name.uppercased())
                            .font(.system(size: 8, weight: .regular))
                            .tracking(0.5)
                            .foregroundColor(TEColors.textPrimary)
                            .lineLimit(1)

                        // Probability indicator
                        if sample.triggerProbability < 1.0 {
                            Text("\(Int(sample.triggerProbability * 100))%")
                                .font(.system(size: 7, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.textSecondary)
                        }
                    }
                } else {
                    Text("EMPTY")
                        .font(.system(size: 7, weight: .regular))
                        .tracking(1)
                        .foregroundColor(TEColors.textTertiary)
                }
            }
            .padding(TESpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .opacity(isPressed ? 0.8 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            isPressed = true
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isPressed = false
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
    }

    private var ledState: LEDIndicator.State {
        if isTriggered {
            return .on
        } else if sample.hasAudio {
            return .dim
        } else {
            return .off
        }
    }

    private var ledColor: Color {
        if isStepActive {
            return TEColors.accentBright
        } else {
            return padColor
        }
    }
}

struct PadGridView: View {
    @ObservedObject var viewModel: SamplerViewModel
    let columns = Array(repeating: GridItem(.flexible(), spacing: TESpacing.padGap), count: 4)

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            // Grid header
            HStack {
                TETypography.label("PADS")
                Spacer()
                TETypography.micro("SEL: \(String(format: "%02d", viewModel.selectedPadIndex + 1))")
            }

            // Pad grid with border
            LazyVGrid(columns: columns, spacing: TESpacing.padGap) {
                ForEach(0..<16, id: \.self) { index in
                    PadView(
                        index: index,
                        sample: viewModel.sampleBank.samples[index],
                        isSelected: viewModel.selectedPadIndex == index,
                        isTriggered: viewModel.recentlyTriggeredPads.contains(index),
                        isStepActive: checkStepActive(for: index),
                        onTap: {
                            if viewModel.currentMode == .write {
                                viewModel.toggleStepForSelectedPad(at: index)
                            } else {
                                viewModel.triggerPad(index)
                                viewModel.selectPad(index)
                            }
                        },
                        onLongPress: {
                            viewModel.longPressPad(index)
                        }
                    )
                }
            }
            .padding(TESpacing.xs)
            .background(TEColors.surface)
            .overlay(
                Rectangle()
                    .stroke(TEColors.border, lineWidth: 1)
            )
        }
    }

    private func checkStepActive(for padIndex: Int) -> Bool {
        guard AudioEngine.shared.isPlaying else { return false }
        let currentStep = AudioEngine.shared.currentStep
        let pattern = viewModel.sampleBank.currentPattern
        guard padIndex < pattern.trackSteps.count,
              currentStep < pattern.trackSteps[padIndex].count else {
            return false
        }
        return pattern.trackSteps[padIndex][currentStep].isActive
    }
}

// Helper extension for hex colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    PadGridView(viewModel: SamplerViewModel())
        .frame(maxWidth: 400, maxHeight: 400)
        .background(TEColors.background)
        .padding()
}
