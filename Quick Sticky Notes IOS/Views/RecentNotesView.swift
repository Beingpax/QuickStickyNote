import SwiftUI

struct RecentNotesView: View {
    var body: some View {
        List {
            ForEach(0..<3) { _ in
                VStack(alignment: .leading) {
                    Text("Recent Note")
                        .font(.headline)
                    Text("Last edited: 2 hours ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("This is a sample recent note that will show recently edited notes.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    RecentNotesView()
} 