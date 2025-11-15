import SwiftUI

struct XYPadView: View {
    @Binding var position: CGPoint
    let bank: XYParameterBank

    @State private var isDragging = false

    private var xLabel: String {
        switch bank {
        case .tone: return "PITCH"
        case .filter: return "CUTOFF"
        case .effects: return "PROB"
        case .probability: return "PROB"
        }
    }

    private var yLabel: String {
        switch bank {
        case .tone: return "VOL"
        case .filter: return "RES"
        case .effects: return "PITCH VAR"
        case .probability: return "TIME VAR"
        }
    }

    private var xValue: String {
        switch bank {
        case .tone:
            let pitch = Float(position.x) * 48.0 - 24.0
            return String(format: "%+.1f", pitch)
        case .filter:
            return String(format: "%.0f", position.x * 100)
        case .effects, .probability:
            return String(format: "%.0f", position.x * 100)
        }
    }

    private var yValue: String {
        switch bank {
        case .tone:
            return String(format: "%.0f", position.y * 100)
        case .filter:
            return String(format: "%.0f", position.y * 100)
        case .effects:
            let semitones = Float(position.y) * 12.0
            return String(format: "%+.1f", semitones)
        case .probability:
            let ms = Double(position.y) * 50.0
            return String(format: "%.1f", ms)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - pure black
                Rectangle()
                    .fill(TEColors.background)

                // Fine grid lines
                Canvas { context, size in
                    let fineGridSpacing: CGFloat = 15
                    let majorGridSpacing: CGFloat = 60

                    // Fine grid
                    var x: CGFloat = fineGridSpacing
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(TEColors.border.opacity(0.3)), lineWidth: 0.5)
                        x += fineGridSpacing
                    }

                    var y: CGFloat = fineGridSpacing
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(TEColors.border.opacity(0.3)), lineWidth: 0.5)
                        y += fineGridSpacing
                    }

                    // Major grid (quarter divisions)
                    x = majorGridSpacing
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(TEColors.border.opacity(0.6)), lineWidth: 0.5)
                        x += majorGridSpacing
                    }

                    y = majorGridSpacing
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(TEColors.border.opacity(0.6)), lineWidth: 0.5)
                        y += majorGridSpacing
                    }

                    // Center crosshair (subtle)
                    var centerPath = Path()
                    centerPath.move(to: CGPoint(x: size.width / 2, y: 0))
                    centerPath.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    centerPath.move(to: CGPoint(x: 0, y: size.height / 2))
                    centerPath.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    context.stroke(centerPath, with: .color(TEColors.textTertiary), lineWidth: 1)
                }

                // Position crosshair indicator (thin lines, not circular blob)
                Group {
                    // Vertical line
                    Rectangle()
                        .fill(TEColors.accentBright)
                        .frame(width: 1, height: geometry.size.height)
                        .position(x: position.x * geometry.size.width, y: geometry.size.height / 2)

                    // Horizontal line
                    Rectangle()
                        .fill(TEColors.accentBright)
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width / 2, y: (1 - position.y) * geometry.size.height)

                    // Small center dot at intersection
                    Circle()
                        .fill(TEColors.accentBright)
                        .frame(width: isDragging ? 8 : 6, height: isDragging ? 8 : 6)
                        .position(
                            x: position.x * geometry.size.width,
                            y: (1 - position.y) * geometry.size.height
                        )
                }

                // Corner numeric readouts
                VStack {
                    HStack {
                        // Top-left: Y value
                        VStack(alignment: .leading, spacing: 1) {
                            Text(yLabel)
                                .font(.system(size: 8, weight: .regular))
                                .tracking(0.5)
                                .foregroundColor(TEColors.textTertiary)
                            Text(yValue)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.accentBright)
                        }
                        .padding(TESpacing.xs)

                        Spacer()

                        // Top-right: Bank indicator
                        Text(bank.rawValue.uppercased())
                            .font(.system(size: 9, weight: .regular))
                            .tracking(1)
                            .foregroundColor(TEColors.textPrimary)
                            .padding(.horizontal, TESpacing.sm)
                            .padding(.vertical, TESpacing.xs)
                            .background(TEColors.surfaceElevated)
                            .overlay(
                                Rectangle()
                                    .stroke(TEColors.borderActive, lineWidth: 1)
                            )
                            .padding(TESpacing.xs)
                    }

                    Spacer()

                    HStack {
                        Spacer()

                        // Bottom-right: X value
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(xLabel)
                                .font(.system(size: 8, weight: .regular))
                                .tracking(0.5)
                                .foregroundColor(TEColors.textTertiary)
                            Text(xValue)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(TEColors.accentBright)
                        }
                        .padding(TESpacing.xs)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(TEColors.border, lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let x = max(0, min(1, value.location.x / geometry.size.width))
                        let y = max(0, min(1, 1 - (value.location.y / geometry.size.height)))
                        position = CGPoint(x: x, y: y)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct XYBankSelector: View {
    @Binding var selectedBank: XYParameterBank

    var body: some View {
        HStack(spacing: TESpacing.xs) {
            ForEach(XYParameterBank.allCases, id: \.self) { bank in
                Button {
                    selectedBank = bank
                } label: {
                    VStack(spacing: 2) {
                        LEDIndicator(
                            state: selectedBank == bank ? .on : .off,
                            color: TEColors.accentBright,
                            size: 4
                        )
                        Text(bank.rawValue.uppercased())
                            .font(.system(size: 9, weight: .regular))
                            .tracking(0.5)
                            .foregroundColor(selectedBank == bank ? TEColors.textPrimary : TEColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TESpacing.xs)
                    .background(selectedBank == bank ? TEColors.surfaceElevated : Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(selectedBank == bank ? TEColors.borderActive : TEColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: TESpacing.sm) {
        XYBankSelector(selectedBank: .constant(.tone))
        XYPadView(position: .constant(CGPoint(x: 0.5, y: 0.5)), bank: .tone)
            .frame(width: 300, height: 300)
    }
    .padding()
    .background(TEColors.background)
}
