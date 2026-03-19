import SwiftUI
import SwiftData

@main
struct BloodPressureTrackerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: BPReading.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DataStore(modelContext: modelContainer.mainContext))
        }
        .modelContainer(modelContainer)
    }
}
