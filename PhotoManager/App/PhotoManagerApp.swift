import SwiftUI

@main
struct PhotoManagerApp: App {
    @State private var library = PhotoLibraryService()
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(services)
        }
    }
}
