import SwiftUI
import KeyboardShortcuts

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var notesManager: NotesManager
    @State private var currentStep = 0
    @State private var selectedDirectory: URL?
    @State private var showDirectoryPicker = false
    @State private var isCustomizingShortcuts = false
    @State private var animationAmount: CGFloat = 1
    @State private var backgroundGradient = 0.0
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to Quick Sticky Notes",
            subtitle: "Your go-to app for quick thoughts and references",
            icon: "note.text",
            description: "Let's get you set up in just a few steps",
            accentColor: Color(hex: "#FF6B6B"),
            gradientColors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")]
        ),
        OnboardingStep(
            title: "Choose Where to Store Notes",
            subtitle: "Your notes are saved as markdown files",
            icon: "folder.fill",
            description: "Select a directory where you want to store your notes. They'll be saved as .md files that you can use with other apps like Obsidian.",
            accentColor: Color(hex: "#4ECDC4"),
            gradientColors: [Color(hex: "#4ECDC4"), Color(hex: "#556270")]
        ),
        OnboardingStep(
            title: "Set Up Quick Access",
            subtitle: "Access from anywhere with shortcuts",
            icon: "keyboard.fill",
            description: "Customize your keyboard shortcuts to quickly create notes or view all notes from anywhere.",
            accentColor: Color(hex: "#556270"),
            gradientColors: [Color(hex: "#556270"), Color(hex: "#FF6B6B")]
        ),
        OnboardingStep(
            title: "Support Quick Sticky Notes",
            subtitle: "Choose how you want to use the app",
            icon: "heart.fill",
            description: "Get lifetime access to all features and updates with a one-time purchase.",
            accentColor: Color(hex: "#FF6B6B"),
            gradientColors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")]
        ),
        OnboardingStep(
            title: "Ready to Go!",
            subtitle: "Here's what you can do with Quick Sticky Notes",
            icon: "star.fill",
            description: "Start creating notes that float above other windows, format with markdown, and access them instantly.",
            accentColor: Color(hex: "#4ECDC4"),
            gradientColors: [Color(hex: "#4ECDC4"), Color(hex: "#556270")]
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated Background
                LinearGradient(
                    colors: steps[currentStep].gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.15)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentStep)
                
                // Content
                HStack(spacing: 0) {
                    // Left Panel - Progress
                    VStack(alignment: .leading, spacing: 32) {
                        // App Icon and Title
                        VStack(alignment: .leading, spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(steps[currentStep].accentColor.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "note.text")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(steps[currentStep].accentColor)
                            }
                            
                            Text("Quick Sticky Notes")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(steps[currentStep].accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        
                        // Progress Steps
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(0..<steps.count, id: \.self) { index in
                                ProgressStep(
                                    step: index + 1,
                                    title: steps[index].title,
                                    isActive: currentStep == index,
                                    isCompleted: currentStep > index,
                                    accentColor: steps[index].accentColor
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        Spacer()
                        
                        // Progress Text with custom styling
                        Text("Step \(currentStep + 1) of \(steps.count)")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(steps[currentStep].accentColor.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .padding(40)
                    .frame(width: min(320, geometry.size.width * 0.25))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    
                    // Right Panel - Content
                    VStack(spacing: 0) {
                        // Header with Icon
                        VStack(spacing: 24) {
                            ZStack {
                                ForEach(0..<steps.count, id: \.self) { index in
                                    if index == currentStep {
                                        IconView(
                                            icon: steps[index].icon,
                                            color: steps[index].accentColor
                                        )
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                    }
                                }
                            }
                            .frame(height: 120)
                            
                            VStack(spacing: 12) {
                                Text(steps[currentStep].title)
                                    .font(.system(size: 32, weight: .bold))
                                    .multilineTextAlignment(.center)
                                
                                Text(steps[currentStep].subtitle)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(steps[currentStep].accentColor)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 60)
                        
                        // Step Content
                        VStack(spacing: 40) {
                            Text(steps[currentStep].description)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 60)
                                .padding(.top, 20)
                            
                            // Step-specific content
                            Group {
                                switch currentStep {
                                case 0:
                                    FeaturesGrid(accentColor: steps[currentStep].accentColor)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                case 1:
                                    DirectorySelectionView(
                                        selectedDirectory: $selectedDirectory,
                                        showDirectoryPicker: $showDirectoryPicker,
                                        accentColor: steps[currentStep].accentColor
                                    )
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                case 2:
                                    ShortcutsSetupView(
                                        isCustomizing: $isCustomizingShortcuts,
                                        accentColor: steps[currentStep].accentColor
                                    )
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                case 3:
                                    FinalStepView(accentColor: steps[currentStep].accentColor)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                default:
                                    EmptyView()
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        .padding(.top, 40)
                        
                        Spacer()
                        
                        // Navigation Buttons
                        HStack(spacing: 20) {
                            if currentStep > 0 {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentStep -= 1
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                }
                                .buttonStyle(SecondaryButtonStyle(color: steps[currentStep].accentColor))
                            }
                            
                            Button(action: {
                                if currentStep == steps.count - 1 {
                                    hasCompletedOnboarding = true
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentStep += 1
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(currentStep == steps.count - 1 ? "Get Started" : "Continue")
                                    if currentStep < steps.count - 1 {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .font(.system(size: 16, weight: .semibold))
                            }
                            .buttonStyle(PrimaryButtonStyle(color: steps[currentStep].accentColor))
                            .disabled(currentStep == 1 && selectedDirectory == nil)
                        }
                        .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#1E1E1E"))
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Progress Step
private struct ProgressStep: View {
    let step: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isActive ? accentColor : isCompleted ? accentColor.opacity(0.2) : Color(.separatorColor))
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isActive ? .white : isCompleted ? .white : .secondary)
                }
            }
            
            Text(title)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? accentColor : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Icon View
private struct IconView: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(color.gradient)
                .symbolEffect(.bounce, value: icon)
        }
    }
}

// MARK: - Features Grid
private struct FeaturesGrid: View {
    let accentColor: Color
    
    private let features = [
        OnboardingFeature(
            icon: "note.text",
            title: "Floating Notes",
            description: "Notes that stay on top of other windows",
            color: Color(hex: "#FF6B6B")
        ),
        OnboardingFeature(
            icon: "doc.text",
            title: "Markdown Support",
            description: "Write in Markdown, preview instantly",
            color: Color(hex: "#4ECDC4")
        ),
        OnboardingFeature(
            icon: "folder",
            title: "Local Storage",
            description: "Plain text files, compatible with other apps",
            color: Color(hex: "#556270")
        ),
        OnboardingFeature(
            icon: "keyboard",
            title: "Global Access",
            description: "Quick access with keyboard shortcuts",
            color: Color(hex: "#FF6B6B")
        )
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 24) {
                ForEach(features) { feature in
                    FeatureCard(feature: feature)
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Feature Card
private struct FeatureCard: View {
    let feature: OnboardingFeature
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(feature.color.gradient)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(feature.title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(feature.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
        )
    }
}

// MARK: - Directory Selection
private struct DirectorySelectionView: View {
    @Binding var selectedDirectory: URL?
    @Binding var showDirectoryPicker: Bool
    @EnvironmentObject private var notesManager: NotesManager
    let accentColor: Color
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                if let directory = selectedDirectory {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Selected Directory", systemImage: "folder.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                        
                        Text(directory.path)
                            .font(.system(.body, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.windowBackgroundColor))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                            )
                    }
                }
                
                Button(action: { showDirectoryPicker = true }) {
                    Label(
                        selectedDirectory == nil ? "Choose Directory" : "Change Directory",
                        systemImage: selectedDirectory == nil ? "folder.badge.plus" : "folder.badge.gear"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(color: accentColor))
                .fileImporter(
                    isPresented: $showDirectoryPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        selectedDirectory = url
                        notesManager.setNotesDirectory(url)
                    }
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Shortcuts Setup
private struct ShortcutsSetupView: View {
    @Binding var isCustomizing: Bool
    let accentColor: Color
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pro Feature Message
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(accentColor)
                    Text("Pro Feature")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .padding(.vertical, 8)
                
                Text("Keyboard shortcuts are available with the Pro version. You can use the menu bar options for free instead.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                
                ShortcutRow(
                    title: "New Quick Note",
                    description: "Create a new floating note instantly",
                    shortcutName: .newQuickNote,
                    color: accentColor
                )
                
                ShortcutRow(
                    title: "View All Notes",
                    description: "Open the notes list window",
                    shortcutName: .openNotesList,
                    color: accentColor
                )
                
                ShortcutRow(
                    title: "Recent Notes",
                    description: "Access your recently created notes",
                    shortcutName: .openRecentNotes,
                    color: accentColor
                )
                
                ShortcutRow(
                    title: "Toggle Preview",
                    description: "Switch between edit and preview modes",
                    shortcutName: .togglePreviewMode,
                    color: accentColor
                )
            }
            .padding(32)
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let description: String
    let shortcutName: KeyboardShortcuts.Name
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            KeyboardShortcuts.Recorder(for: shortcutName)
                .controlSize(.large)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Final Step
private struct FinalStepView: View {
    let accentColor: Color
    
    private let tips = [
        "Create notes quickly with your keyboard shortcut",
        "Access all features from the menu bar icon",
        "Format your notes with Markdown",
        "Find your notes in the directory you chose",
        "Customize colors to organize your notes"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(tips, id: \.self) { tip in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accentColor)
                        }
                        
                        Text(tip)
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: 400, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(32)
        }
    }
}

// MARK: - Models
private struct OnboardingStep {
    let title: String
    let subtitle: String
    let icon: String
    let description: String
    let accentColor: Color
    let gradientColors: [Color]
}

private struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Button Styles
private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(width: 160, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.gradient)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .frame(width: 160, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.1))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 
