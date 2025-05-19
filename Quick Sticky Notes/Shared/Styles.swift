import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Button Styles
struct SaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            #if os(iOS)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            #else
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            #endif
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Color Components
struct ColorButton: View {
    let color: NoteColor
    let isSelected: Bool
    let action: () -> Void
    let deleteAction: (() -> Void)?
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color.backgroundColor))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.2), lineWidth: 2)
                )
                .overlay(
                    deleteAction != nil ?
                    Button(action: { deleteAction?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .offset(x: 8, y: -8)
                    : nil
                )
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .frame(width: 44, height: 44) // Larger touch target for iOS
        #else
        .frame(width: 32, height: 32)
        #endif
    }
}

struct AddColorButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        Color.black.opacity(0.6),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: [4]
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .frame(width: 44, height: 44) // Larger touch target for iOS
        #else
        .frame(width: 32, height: 32)
        #endif
    }
}

struct CharacterCountView: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .monospacedDigit()
            .foregroundColor(.white)
            #if os(iOS)
            .font(.footnote)
            #else
            .font(.system(size: 11))
            #endif
            .padding(4)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ColorPickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedColor: NoteColor
    @State private var customColor = Color.white
    @State private var colorName = ""
    
    var body: some View {
        VStack(spacing: 16) {
            ColorPicker("Choose Color", selection: $customColor)
                .labelsHidden()
            
            TextField("Color Name", text: $colorName)
                #if os(iOS)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.default)
                #else
                .textFieldStyle(.plain)
                #endif
            
            Button("Add Color") {
                if !colorName.isEmpty {
                    let newColor = NoteColor(
                        name: colorName.lowercased(),
                        backgroundColor: customColor,
                        isCustom: true
                    )
                    UserDefaults.standard.saveCustomColor(newColor)
                    selectedColor = newColor
                    isPresented = false
                    colorName = ""
                }
            }
            .disabled(colorName.isEmpty)
            .buttonStyle(SaveButtonStyle())
        }
        .padding()
        #if os(iOS)
        .frame(maxWidth: .infinity)
        #else
        .frame(width: 200)
        #endif
    }
}

// MARK: - Note Color Model
struct NoteColor: Equatable, Codable, Identifiable {
    let id = UUID()
    let name: String
    let backgroundColor: Color
    let isCustom: Bool
    
    init(name: String, backgroundColor: Color, isCustom: Bool = false) {
        self.name = name
        self.backgroundColor = backgroundColor
        self.isCustom = isCustom
    }
    
    // Coding keys for Codable
    private enum CodingKeys: String, CodingKey {
        case name, red, green, blue, isCustom
    }
    
    // Encoding implementation
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isCustom, forKey: .isCustom)
        
        // Extract color components
        if let cgColor = backgroundColor.cgColor,
           let components = cgColor.components,
           components.count >= 3 {
            try container.encode(components[0], forKey: .red)
            try container.encode(components[1], forKey: .green)
            try container.encode(components[2], forKey: .blue)
        }
    }
    
    // Decoding implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        
        backgroundColor = Color(red: red, green: green, blue: blue)
    }
    
    // Default colors
    static let defaultColors = [
        citrus,
        sunset,
        emerald,
        ocean,
        magenta,
        violet,
        coral,
        lime,
        turquoise,
        orchid
    ]
    
    // Color definitions
    static let sunset = NoteColor(
        name: "sunset",
        backgroundColor: Color(red: 1.0, green: 0.90, blue: 0.85)
    )
    
    static let emerald = NoteColor(
        name: "emerald",
        backgroundColor: Color(red: 0.82, green: 0.95, blue: 0.85)
    )
    
    static let ocean = NoteColor(
        name: "ocean",
        backgroundColor: Color(red: 0.85, green: 0.95, blue: 1.0)
    )
    
    static let magenta = NoteColor(
        name: "magenta",
        backgroundColor: Color(red: 1.0, green: 0.90, blue: 0.95)
    )
    
    static let citrus = NoteColor(
        name: "citrus",
        backgroundColor: Color(red: 1.0, green: 0.95, blue: 0.75)
    )
    
    static let violet = NoteColor(
        name: "violet",
        backgroundColor: Color(red: 0.95, green: 0.90, blue: 1.0)
    )
    
    static let coral = NoteColor(
        name: "coral",
        backgroundColor: Color(red: 1.0, green: 0.90, blue: 0.88)
    )
    
    static let lime = NoteColor(
        name: "lime",
        backgroundColor: Color(red: 0.88, green: 1.0, blue: 0.82)
    )
    
    static let turquoise = NoteColor(
        name: "turquoise",
        backgroundColor: Color(red: 0.82, green: 0.98, blue: 0.95)
    )
    
    static let orchid = NoteColor(
        name: "orchid",
        backgroundColor: Color(red: 0.98, green: 0.90, blue: 1.0)
    )
}

// MARK: - UserDefaults Extension
extension UserDefaults {
    static let customColorsKey = "customColors"
    
    func saveCustomColor(_ color: NoteColor) {
        var customColors = getCustomColors()
        customColors.append(color)
        saveCustomColors(customColors)
    }
    
    func deleteCustomColor(_ color: NoteColor) {
        var customColors = getCustomColors()
        customColors.removeAll { $0.name == color.name }
        saveCustomColors(customColors)
    }
    
    func getCustomColors() -> [NoteColor] {
        guard let data = data(forKey: Self.customColorsKey) else { return [] }
        return (try? JSONDecoder().decode([NoteColor].self, from: data)) ?? []
    }
    
    private func saveCustomColors(_ colors: [NoteColor]) {
        guard let data = try? JSONEncoder().encode(colors) else { return }
        set(data, forKey: Self.customColorsKey)
    }
}

#if os(macOS)
// MARK: - Window Environment Key (macOS only)
struct WindowKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    var window: NSWindow? {
        get { self[WindowKey.self] }
        set { self[WindowKey.self] = newValue }
    }
}
#endif 
