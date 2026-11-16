import SwiftUI
import SwiftData

@main
struct AIDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: DiaryEntry.self)
    }
}