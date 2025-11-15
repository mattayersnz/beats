import SwiftUI

// MARK: - Teenage Engineering Inspired Design System

enum TEColors {
    // Primary Background Colors
    static let background = Color(hex: "#1A1814") ?? Color.black
    static let surface = Color(hex: "#2A2824") ?? Color(white: 0.15)
    static let surfaceElevated = Color(hex: "#3A3834") ?? Color(white: 0.2)

    // Text Colors
    static let textPrimary = Color(hex: "#E8E4D8") ?? Color.white
    static let textSecondary = Color(hex: "#9A958A") ?? Color.gray
    static let textTertiary = Color(hex: "#6A6560") ?? Color.gray.opacity(0.5)

    // Accent Colors (LED-style)
    static let accent = Color(hex: "#F0E68C") ?? Color.yellow // Pale yellow - TE signature
    static let accentBright = Color(hex: "#FFE566") ?? Color.yellow
    static let accentDim = Color(hex: "#8A8460") ?? Color.yellow.opacity(0.4)

    // Functional Colors
    static let recording = Color(hex: "#FF4444") ?? Color.red
    static let success = Color(hex: "#66FF99") ?? Color.green
    static let probability = Color(hex: "#88CCFF") ?? Color.blue
    static let warning = Color(hex: "#FFAA44") ?? Color.orange

    // Border/Line Colors
    static let border = Color(hex: "#4A4844") ?? Color.gray.opacity(0.3)
    static let borderLight = Color(hex: "#3A3834") ?? Color.gray.opacity(0.2)
    static let borderActive = Color(hex: "#8A8460") ?? Color.yellow.opacity(0.5)

    // Pad Colors (Muted, industrial palette)
    static let padColors: [Color] = [
        Color(hex: "#8B7355") ?? .brown,      // Warm brown
        Color(hex: "#A89880") ?? .brown,      // Light tan
        Color(hex: "#C4B090") ?? .orange,     // Sand
        Color(hex: "#7A9B8A") ?? .green,      // Muted green
        Color(hex: "#6B8B9B") ?? .blue,       // Steel blue
        Color(hex: "#5B7B8B") ?? .blue,       // Dark steel
        Color(hex: "#4B6B7B") ?? .blue,       // Navy steel
        Color(hex: "#9B7A8A") ?? .pink,       // Dusty pink
        Color(hex: "#AB6A7A") ?? .red,        // Muted red
        Color(hex: "#8B6A9B") ?? .purple,     // Dusty purple
        Color(hex: "#7B8AAB") ?? .blue,       // Periwinkle
        Color(hex: "#6BAAAB") ?? .cyan,       // Teal
        Color(hex: "#ABAA6B") ?? .yellow,     // Olive
        Color(hex: "#AB8A5B") ?? .orange,     // Rust
        Color(hex: "#9B9A8B") ?? .gray,       // Warm gray
        Color(hex: "#8B8A7B") ?? .gray        // Dark warm gray
    ]
}

enum TETypography {
    // Display - Large titles
    static func display(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .light, design: .monospaced))
            .foregroundColor(TEColors.textPrimary)
    }

    // Title - Section headers (uppercase, spaced)
    static func title(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 14, weight: .light, design: .default))
            .tracking(2)
            .foregroundColor(TEColors.textPrimary)
    }

    // Label - Small labels (uppercase, spaced)
    static func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .regular, design: .default))
            .tracking(1.5)
            .foregroundColor(TEColors.textSecondary)
    }

    // Value - Numeric displays
    static func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(TEColors.textPrimary)
    }

    // Micro - Tiny labels
    static func micro(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundColor(TEColors.textSecondary)
    }

    // Mono - General monospaced text
    static func mono(_ text: String, size: CGFloat = 12) -> some View {
        Text(text)
            .font(.system(size: size, weight: .regular, design: .monospaced))
            .foregroundColor(TEColors.textPrimary)
    }
}

enum TESpacing {
    static let unit: CGFloat = 8
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32

    static let gridGap: CGFloat = 2
    static let padGap: CGFloat = 4
    static let sectionGap: CGFloat = 16
}

// MARK: - View Modifiers

struct TECardModifier: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(TESpacing.sm)
            .background(elevated ? TEColors.surfaceElevated : TEColors.surface)
            .overlay(
                Rectangle()
                    .stroke(TEColors.border, lineWidth: 1)
            )
    }
}

struct TELabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .regular))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(TEColors.textSecondary)
    }
}

extension View {
    func teCard(elevated: Bool = false) -> some View {
        modifier(TECardModifier(elevated: elevated))
    }

    func teLabel() -> some View {
        modifier(TELabelModifier())
    }
}

// MARK: - LED Indicator Component

struct LEDIndicator: View {
    enum State {
        case off
        case on
        case dim
        case blinking
    }

    let state: State
    var color: Color = TEColors.accentBright
    var size: CGFloat = 8

    @SwiftUI.State private var isBlinking = false

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(TEColors.border, lineWidth: 0.5)
            )
            .opacity(isBlinking && state == .blinking ? 0.3 : 1.0)
            .onAppear {
                if state == .blinking {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        isBlinking.toggle()
                    }
                }
            }
    }

    private var fillColor: Color {
        switch state {
        case .off:
            return TEColors.borderLight
        case .on:
            return color
        case .dim:
            return color.opacity(0.4)
        case .blinking:
            return color
        }
    }
}

// MARK: - TE Button Component

struct TEButton: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    var showLED: Bool = true
    var action: () -> Void

    init(_ label: String, icon: String? = nil, isSelected: Bool = false, showLED: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.showLED = showLED
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: TESpacing.xs) {
                if showLED {
                    LEDIndicator(state: isSelected ? .on : .off)
                }

                VStack(spacing: 2) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .light))
                    }

                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .regular))
                        .tracking(1)
                }
                .foregroundColor(isSelected ? TEColors.accentBright : TEColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TESpacing.sm)
            .background(isSelected ? TEColors.surface : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? TEColors.borderActive : TEColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Divider

struct TEDivider: View {
    var body: some View {
        Rectangle()
            .fill(TEColors.border)
            .frame(height: 1)
    }
}

// MARK: - Section Header

struct TESectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            TETypography.label(title)
            Spacer()
            if let trailing = trailing {
                trailing
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TETypography.display("BEATS")
        TETypography.title("Sequencer")
        TETypography.label("Pattern 01")
        TETypography.value("120 BPM")
        TETypography.micro("16 STEPS")

        TEDivider()

        HStack(spacing: 8) {
            LEDIndicator(state: .off)
            LEDIndicator(state: .on)
            LEDIndicator(state: .dim)
            LEDIndicator(state: .blinking)
            LEDIndicator(state: .on, color: TEColors.recording)
            LEDIndicator(state: .on, color: TEColors.success)
        }

        HStack(spacing: 4) {
            TEButton("Play", icon: "play.fill", isSelected: false) {}
            TEButton("Rec", icon: "circle.fill", isSelected: true) {}
            TEButton("FX", isSelected: false) {}
        }
        .padding(.horizontal)

        VStack {
            Text("Card Content")
                .foregroundColor(TEColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .teCard()
        .padding(.horizontal)
    }
    .padding()
    .background(TEColors.background)
}
