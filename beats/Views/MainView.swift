import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel = SamplerViewModel()
    @StateObject private var audioEngine = AudioEngine.shared

    @State private var showingFileImporter = false
    @State private var showingProjectSaver = false
    @State private var showingProjectLoader = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - warm black TE style
                TEColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        viewModel: viewModel,
                        onSave: { showingProjectSaver = true },
                        onLoad: { showingProjectLoader = true }
                    )

                    TEDivider()

                    ScrollView {
                        VStack(spacing: TESpacing.sectionGap) {
                            // Main content based on mode
                            switch viewModel.currentMode {
                            case .play:
                                playModeContent

                            case .sound:
                                soundModeContent

                            case .pattern:
                                patternModeContent

                            case .write:
                                writeModeContent

                            case .fx:
                                fxModeContent

                            case .probability:
                                probabilityModeContent
                            }
                        }
                        .padding(.horizontal, TESpacing.sm)
                        .padding(.top, TESpacing.sm)
                        .padding(.bottom, 160) // Space for control bar
                    }

                    Spacer()
                }

                // Bottom control bar
                VStack {
                    Spacer()
                    ControlBarView(viewModel: viewModel)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingFilePicker) {
            DocumentPicker(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingTrimView) {
            TrimEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingProjectSaver) {
            ProjectSaverView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingProjectLoader) {
            ProjectLoaderView(viewModel: viewModel)
        }
        .onAppear {
            audioEngine.start()
        }
    }

    // MARK: - Mode Content Views

    private var playModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            // 16-pad grid
            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)

            // XY Pad with bank selector
            VStack(spacing: TESpacing.sm) {
                XYBankSelector(selectedBank: $viewModel.xyParameterBank)
                XYPadView(position: $viewModel.xyPosition, bank: viewModel.xyParameterBank)
                    .frame(maxWidth: 300, maxHeight: 300)
            }

            // Selected sample info
            SelectedSampleInfoView(sample: viewModel.selectedSample)
        }
    }

    private var soundModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            // Selected sample header
            SampleEditorHeaderView(viewModel: viewModel)

            // Waveform display with trim (or empty state)
            if viewModel.selectedSample.hasAudio {
                WaveformDisplayView(viewModel: viewModel)
            } else {
                EmptySampleView(viewModel: viewModel)
            }

            // Sample parameters
            SampleParametersView(viewModel: viewModel)

            // Pad grid for selection
            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)
        }
    }

    private var patternModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            PatternSelectorView(viewModel: viewModel)

            SequencerView(viewModel: viewModel)

            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)
        }
    }

    private var writeModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            SequencerView(viewModel: viewModel)

            // Pad grid for track selection
            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)

            // Euclidean rhythm generator
            EuclideanGeneratorView(viewModel: viewModel)
        }
    }

    private var fxModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)

            XYPadView(position: $viewModel.xyPosition, bank: .effects)
                .frame(maxWidth: 300, maxHeight: 300)

            EffectsInfoView()
        }
    }

    private var probabilityModeContent: some View {
        VStack(spacing: TESpacing.sectionGap) {
            ProbabilityVisualizerView(tracker: audioEngine.probabilityTracker)

            GlobalChaosControl(viewModel: viewModel)

            XYPadView(position: $viewModel.xyPosition, bank: .probability)
                .frame(maxWidth: 300, maxHeight: 300)

            PadGridView(viewModel: viewModel)
                .frame(maxWidth: 400)
        }
    }
}

// MARK: - Supporting Views

struct HeaderView: View {
    @ObservedObject var viewModel: SamplerViewModel
    var onSave: () -> Void
    var onLoad: () -> Void

    var body: some View {
        HStack {
            Text("BEATS")
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .tracking(4)
                .foregroundColor(TEColors.textPrimary)

            Spacer()

            HStack(spacing: TESpacing.sm) {
                Button {
                    onLoad()
                } label: {
                    Text("LOAD")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(0.5)
                        .foregroundColor(TEColors.textSecondary)
                }

                Button {
                    onSave()
                } label: {
                    Text("SAVE")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(0.5)
                        .foregroundColor(TEColors.textSecondary)
                }
            }
        }
        .padding(TESpacing.sm)
        .background(TEColors.surface)
    }
}

struct SelectedSampleInfoView: View {
    let sample: Sample

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            HStack {
                TETypography.label("SELECTED")
                Spacer()
                LEDIndicator(
                    state: sample.hasAudio ? .on : .off,
                    color: sample.hasAudio ? TEColors.success : TEColors.recording,
                    size: 6
                )
            }

            HStack {
                TETypography.value(sample.name.uppercased())
                Spacer()
            }

            if sample.hasAudio {
                TEDivider()

                HStack(spacing: TESpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        TETypography.micro("VOL")
                        TETypography.value("\(Int(sample.volume * 100))")
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        TETypography.micro("PITCH")
                        TETypography.value(String(format: "%.1f", sample.pitch))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        TETypography.micro("PROB")
                        TETypography.value("\(Int(sample.triggerProbability * 100))%")
                    }

                    if sample.hasVariations {
                        VStack(alignment: .leading, spacing: 2) {
                            TETypography.micro("VAR")
                            TETypography.value("\(sample.variations.count + 1)")
                        }
                    }

                    Spacer()
                }
            }
        }
        .teCard()
    }
}

struct EuclideanGeneratorView: View {
    @ObservedObject var viewModel: SamplerViewModel

    @State private var hits: Double = 4
    @State private var steps: Double = 16
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            TETypography.label("EUCLIDEAN GENERATOR")

            VStack(spacing: TESpacing.sm) {
                HStack {
                    TETypography.micro("HITS")
                    Spacer()
                    TETypography.value("\(Int(hits))")
                }
                Slider(value: $hits, in: 1...16, step: 1)
                    .tint(TEColors.accent)

                HStack {
                    TETypography.micro("STEPS")
                    Spacer()
                    TETypography.value("\(Int(steps))")
                }
                Slider(value: $steps, in: 2...16, step: 1)
                    .tint(TEColors.accent)

                HStack {
                    TETypography.micro("ROTATION")
                    Spacer()
                    TETypography.value("\(Int(rotation))")
                }
                Slider(value: $rotation, in: 0...15, step: 1)
                    .tint(TEColors.accent)
            }

            Button {
                viewModel.applyEuclidean(hits: Int(hits), steps: Int(steps), rotation: Int(rotation))
            } label: {
                Text("APPLY TO TRACK \(String(format: "%02d", viewModel.selectedPadIndex + 1))")
                    .font(.system(size: 11, weight: .regular))
                    .tracking(1)
                    .foregroundColor(TEColors.textPrimary)
                    .padding(.horizontal, TESpacing.md)
                    .padding(.vertical, TESpacing.sm)
                    .background(TEColors.surfaceElevated)
                    .overlay(
                        Rectangle()
                            .stroke(TEColors.borderActive, lineWidth: 1)
                    )
            }
        }
        .teCard()
    }
}

struct EffectsInfoView: View {
    var body: some View {
        VStack(spacing: TESpacing.sm) {
            TETypography.label("EFFECTS CONTROL")

            TETypography.micro("X-AXIS: TRIGGER PROBABILITY")
            TETypography.micro("Y-AXIS: PITCH VARIATION")
        }
        .teCard()
    }
}

struct SampleEditorHeaderView: View {
    @ObservedObject var viewModel: SamplerViewModel

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            HStack {
                TETypography.label("SOUND EDITOR")
                Spacer()
                TETypography.value("PAD \(String(format: "%02d", viewModel.selectedPadIndex + 1))")
            }

            TEDivider()

            HStack {
                Text(viewModel.selectedSample.name.uppercased())
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(TEColors.accentBright)

                Spacer()

                HStack(spacing: TESpacing.sm) {
                    Button {
                        viewModel.showingFilePicker = true
                    } label: {
                        HStack(spacing: 2) {
                            LEDIndicator(state: .dim, color: TEColors.accentBright, size: 4)
                            Text("LOAD")
                                .font(.system(size: 9, weight: .regular))
                                .tracking(0.5)
                        }
                        .foregroundColor(TEColors.accentBright)
                        .padding(.horizontal, TESpacing.sm)
                        .padding(.vertical, TESpacing.xs)
                        .background(TEColors.surfaceElevated)
                        .overlay(
                            Rectangle()
                                .stroke(TEColors.borderActive, lineWidth: 1)
                        )
                    }

                    if viewModel.selectedSample.hasAudio {
                        Button {
                            viewModel.showingTrimView = true
                        } label: {
                            Text("TRIM")
                                .font(.system(size: 9, weight: .regular))
                                .tracking(0.5)
                                .foregroundColor(TEColors.textSecondary)
                        }
                    }
                }
            }
        }
        .teCard()
    }
}

struct EmptySampleView: View {
    @ObservedObject var viewModel: SamplerViewModel

    var body: some View {
        VStack(spacing: TESpacing.md) {
            TETypography.label("NO SAMPLE LOADED")

            Button {
                viewModel.showingFilePicker = true
            } label: {
                HStack(spacing: TESpacing.xs) {
                    LEDIndicator(state: .blinking, color: TEColors.accentBright, size: 6)
                    Text("TAP TO LOAD AUDIO FILE")
                        .font(.system(size: 11, weight: .regular))
                        .tracking(1)
                }
                .foregroundColor(TEColors.textPrimary)
                .padding(.horizontal, TESpacing.lg)
                .padding(.vertical, TESpacing.md)
                .background(TEColors.surfaceElevated)
                .overlay(
                    Rectangle()
                        .stroke(TEColors.borderActive, lineWidth: 1)
                )
            }

            TETypography.micro("OR LONG PRESS PAD TO RECORD")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TESpacing.lg)
        .teCard()
    }
}

struct WaveformDisplayView: View {
    @ObservedObject var viewModel: SamplerViewModel

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            TETypography.label("WAVEFORM")

            WaveformView(
                audioURL: viewModel.selectedSample.primaryAudioURL,
                trimStart: Binding(
                    get: { viewModel.selectedSample.trimStart },
                    set: { newValue in
                        var sample = viewModel.selectedSample
                        sample.trimStart = newValue
                        viewModel.selectedSample = sample
                    }
                ),
                trimEnd: Binding(
                    get: { viewModel.selectedSample.trimEnd },
                    set: { newValue in
                        var sample = viewModel.selectedSample
                        sample.trimEnd = newValue
                        viewModel.selectedSample = sample
                    }
                )
            )
            .frame(height: 80)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    TETypography.micro("IN")
                    Text("\(Int(viewModel.selectedSample.trimStart * 100))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.success)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    TETypography.micro("OUT")
                    Text("\(Int(viewModel.selectedSample.trimEnd * 100))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.recording)
                }
            }

            TEDivider()

            // Fade controls
            HStack(spacing: TESpacing.md) {
                VStack(spacing: TESpacing.xs) {
                    HStack {
                        TETypography.micro("FADE IN")
                        Spacer()
                        Text("\(Int(viewModel.selectedSample.fadeIn * 100))")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(TEColors.accentBright)
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.selectedSample.fadeIn },
                            set: { newValue in
                                var sample = viewModel.selectedSample
                                sample.fadeIn = newValue
                                viewModel.selectedSample = sample
                            }
                        ),
                        in: 0...0.5
                    )
                    .tint(TEColors.accent)
                }

                VStack(spacing: TESpacing.xs) {
                    HStack {
                        TETypography.micro("FADE OUT")
                        Spacer()
                        Text("\(Int(viewModel.selectedSample.fadeOut * 100))")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(TEColors.accentBright)
                    }
                    Slider(
                        value: Binding(
                            get: { viewModel.selectedSample.fadeOut },
                            set: { newValue in
                                var sample = viewModel.selectedSample
                                sample.fadeOut = newValue
                                viewModel.selectedSample = sample
                            }
                        ),
                        in: 0...0.5
                    )
                    .tint(TEColors.accent)
                }
            }
        }
        .teCard()
    }
}

struct SampleParametersView: View {
    @ObservedObject var viewModel: SamplerViewModel

    var body: some View {
        VStack(spacing: TESpacing.sm) {
            TETypography.label("PARAMETERS")

            TEDivider()

            // Volume
            VStack(spacing: TESpacing.xs) {
                HStack {
                    TETypography.micro("VOLUME")
                    Spacer()
                    Text("\(Int(viewModel.selectedSample.volume * 100))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.selectedSample.volume) },
                        set: { newValue in
                            var sample = viewModel.selectedSample
                            sample.volume = Float(newValue)
                            viewModel.selectedSample = sample
                        }
                    ),
                    in: 0...1
                )
                .tint(TEColors.accent)
            }

            // Pitch
            VStack(spacing: TESpacing.xs) {
                HStack {
                    TETypography.micro("PITCH")
                    Spacer()
                    Text(String(format: "%+.1f", viewModel.selectedSample.pitch))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.selectedSample.pitch) },
                        set: { newValue in
                            var sample = viewModel.selectedSample
                            sample.pitch = Float(newValue)
                            viewModel.selectedSample = sample
                        }
                    ),
                    in: -12...12
                )
                .tint(TEColors.accent)
            }

            // Pan
            VStack(spacing: TESpacing.xs) {
                HStack {
                    TETypography.micro("PAN")
                    Spacer()
                    Text(panLabel)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.selectedSample.pan) },
                        set: { newValue in
                            var sample = viewModel.selectedSample
                            sample.pan = Float(newValue)
                            viewModel.selectedSample = sample
                        }
                    ),
                    in: -1...1
                )
                .tint(TEColors.accent)
            }

            TEDivider()

            // Trigger Probability
            VStack(spacing: TESpacing.xs) {
                HStack {
                    TETypography.micro("TRIGGER PROB")
                    Spacer()
                    Text("\(Int(viewModel.selectedSample.triggerProbability * 100))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.accentBright)
                }
                Slider(
                    value: Binding(
                        get: { viewModel.selectedSample.triggerProbability },
                        set: { newValue in
                            var sample = viewModel.selectedSample
                            sample.triggerProbability = newValue
                            viewModel.selectedSample = sample
                        }
                    ),
                    in: 0...1
                )
                .tint(TEColors.accent)
            }

            // Playback mode
            HStack {
                TETypography.micro("MODE")
                Spacer()
                Text(viewModel.selectedSample.playbackMode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.5)
                    .foregroundColor(TEColors.textSecondary)
            }
        }
        .teCard()
    }

    private var panLabel: String {
        let pan = viewModel.selectedSample.pan
        if pan < -0.1 {
            return "L\(Int(abs(pan) * 100))"
        } else if pan > 0.1 {
            return "R\(Int(pan * 100))"
        } else {
            return "C"
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: SamplerViewModel

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.audio,
            UTType.wav,
            UTType.aiff,
            UTType.mp3
        ])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            parent.viewModel.importFile(url, toSlot: parent.viewModel.selectedPadIndex)
        }
    }
}

struct ProjectSaverView: View {
    @ObservedObject var viewModel: SamplerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = "MY PROJECT"

    var body: some View {
        NavigationStack {
            VStack(spacing: TESpacing.lg) {
                VStack(spacing: TESpacing.sm) {
                    TETypography.label("PROJECT NAME")

                    TextField("", text: $projectName)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(TEColors.textPrimary)
                        .padding(TESpacing.sm)
                        .background(TEColors.surface)
                        .overlay(
                            Rectangle()
                                .stroke(TEColors.borderActive, lineWidth: 1)
                        )
                }

                Button {
                    saveProject()
                } label: {
                    HStack(spacing: TESpacing.xs) {
                        LEDIndicator(state: .dim, color: TEColors.success, size: 6)
                        Text("SAVE PROJECT")
                            .font(.system(size: 11, weight: .regular))
                            .tracking(1)
                    }
                    .foregroundColor(TEColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TESpacing.sm)
                    .background(TEColors.surfaceElevated)
                    .overlay(
                        Rectangle()
                            .stroke(TEColors.borderActive, lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding(TESpacing.md)
            .background(TEColors.background)
            .navigationTitle("SAVE")
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

    private func saveProject() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectURL = documentsPath.appendingPathComponent("\(projectName).beats")

        do {
            try viewModel.saveProject(to: projectURL)
            dismiss()
        } catch {
            print("Failed to save project: \(error)")
        }
    }
}

struct ProjectLoaderView: View {
    @ObservedObject var viewModel: SamplerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectFiles: [URL] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TESpacing.xs) {
                    if projectFiles.isEmpty {
                        VStack(spacing: TESpacing.sm) {
                            TETypography.label("NO PROJECTS")
                            TETypography.micro("SAVE A PROJECT FIRST")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TESpacing.xl)
                    } else {
                        ForEach(projectFiles, id: \.self) { url in
                            Button {
                                loadProject(from: url)
                            } label: {
                                HStack {
                                    LEDIndicator(state: .dim, color: TEColors.accentBright, size: 6)

                                    Text(url.deletingPathExtension().lastPathComponent.uppercased())
                                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                                        .foregroundColor(TEColors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .light))
                                        .foregroundColor(TEColors.textTertiary)
                                }
                                .padding(TESpacing.sm)
                                .background(TEColors.surface)
                                .overlay(
                                    Rectangle()
                                        .stroke(TEColors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(TESpacing.sm)
            }
            .background(TEColors.background)
            .navigationTitle("LOAD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        dismiss()
                    }
                    .foregroundColor(TEColors.textSecondary)
                }
            }
            .onAppear {
                loadProjectList()
            }
        }
    }

    private func loadProjectList() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            projectFiles = files.filter { $0.pathExtension == "beats" }
        } catch {
            print("Failed to load project list: \(error)")
        }
    }

    private func loadProject(from url: URL) {
        do {
            try viewModel.loadProject(from: url)
            dismiss()
        } catch {
            print("Failed to load project: \(error)")
        }
    }
}
