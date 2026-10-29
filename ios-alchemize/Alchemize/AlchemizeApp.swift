import SwiftUI
import SwiftData

@main
struct AlchemizeApp: App {
    @State private var auth = AuthStore()

    let container: ModelContainer = {
        let schema = Schema(AppSchema.models)
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            // Fall back to in-memory store so the app always launches.
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }()

    init() {
        ImageStore.shared.prefetch(AZImages.all)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .preferredColorScheme(.dark)
                .tint(AZ.violetLight)
        }
        .modelContainer(container)
    }
}
