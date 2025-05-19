import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let accentColor = Color(hex: "#4ECDC4")
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - App Info
            VStack(alignment: .leading, spacing: 0) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
                
                Spacer()
                
                // App Icon and Info
                VStack(alignment: .leading, spacing: 20) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Sticky Notes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Version \(appVersion)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Support Links
                VStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/xryDy57nYD") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 14))
                            Text("Join Discord")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#4ECDC4"), Color(hex: "#556270")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Link(destination: URL(string: "mailto:prakashjoshipax@gmail.com?subject=Quick%20Sticky%20Notes%20Support")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14))
                            Text("Contact Support")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#2D2D2D"))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
            }
            .frame(width: 320)
            .background(Color(hex: "#1A1A1A"))
            
            // Right Panel - Features
            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#4ECDC4"), Color(hex: "#556270")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        Text("Modern Note-Taking,\nRedefined")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 60)
                    
                    // Key Features
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "rectangle.on.rectangle",
                            title: "Always-On-Top Notes",
                            description: "Keep important information floating above other windows",
                            color: Color(hex: "#FF6B6B")
                        )
                        
                        FeatureRow(
                            icon: "text.alignleft",
                            title: "Markdown Power",
                            description: "Write in Markdown with real-time formatting preview",
                            color: Color(hex: "#4ECDC4")
                        )
                        
                        FeatureRow(
                            icon: "bolt.fill",
                            title: "Lightning Fast",
                            description: "Global shortcuts for instant note creation and access",
                            color: Color(hex: "#556270")
                        )
                        
                        FeatureRow(
                            icon: "folder.fill",
                            title: "Your Files, Your Way",
                            description: "Notes stored as Markdown files, compatible with other apps",
                            color: Color(hex: "#FF6B6B")
                        )
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 60)
            }
            .frame(width: 480)
            .background(Color(hex: "#2D2D2D"))
        }
        .frame(height: 600)
        .preferredColorScheme(.dark)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color.gradient)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(12)
    }
}
