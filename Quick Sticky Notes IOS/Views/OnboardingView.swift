import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notesManager = NotesManager.shared
    @State private var isShowingDirectoryPicker = false
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Quick Sticky Notes",
            subtitle: "Simple, Fast, Reliable",
            icon: "note.text",
            points: [
                InfoPoint(icon: "star.fill", text: "Fast and lightweight note-taking"),
                InfoPoint(icon: "arrow.triangle.branch", text: "Cross-platform support"),
                InfoPoint(icon: "lock.fill", text: "Privacy-focused design")
            ]
        ),
        OnboardingPage(
            title: "Markdown Power",
            subtitle: "Write and preview your notes",
            icon: "doc.text.magnifyingglass",
            points: [
                InfoPoint(icon: "text.badge.checkmark", text: "Full Markdown support"),
                InfoPoint(icon: "eye.fill", text: "Preview Markdown with a single tap"),
                InfoPoint(icon: "folder.badge.plus", text: "Work with existing Markdown files")
            ]
        ),
        OnboardingPage(
            title: "No Data Lock-In",
            subtitle: "Your notes are stored locally as plain text Markdown files",
            icon: "folder.fill",
            points: [
                InfoPoint(icon: "folder", text: "Choose where to store your notes"),
                InfoPoint(icon: "doc.text", text: "Plain text Markdown files"),
                InfoPoint(icon: "person.fill.checkmark", text: "You own your data, always")
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top)
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Action buttons
                VStack(spacing: 12) {
                    if currentPage == pages.count - 1 {
                        Button(action: {
                            isShowingDirectoryPicker = true
                        }) {
                            Text("Choose Storage Location")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                    }
                    
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            isShowingDirectoryPicker = true
                        }) {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                if let error = notesManager.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingDirectoryPicker) {
            NavigationStack {
                DirectoryPickerView { url in
                    notesManager.setNotesDirectory(url)
                    if notesManager.isDirectoryConfigured {
                        dismiss()
                    }
                }
                .navigationTitle("Select Directory")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingDirectoryPicker = false
                        }
                    }
                }
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let points: [InfoPoint]
}

struct InfoPoint {
    let icon: String
    let text: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Image(systemName: page.icon)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            // Main content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2)
                    .bold()
                
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(page.points, id: \.text) { point in
                        HStack(spacing: 15) {
                            Image(systemName: point.icon)
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                                .frame(width: 30)
                            
                            Text(point.text)
                                .font(.body)
                        }
                    }
                }
                .padding(.top)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
} 