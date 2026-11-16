import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}