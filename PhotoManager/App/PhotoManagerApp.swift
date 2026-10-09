import SwiftUI

@main
struct PhotoManagerApp: App {
    @State private var library = PhotoLibraryService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
        }
    }
}
