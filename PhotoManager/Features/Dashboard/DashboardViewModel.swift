import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var report = AlbumHealthReport()
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    func refresh(store: RecordStore) async {
        isLoading = true
        defer { isLoading = false }
        let result = await Task.detached(priority: .userInitiated) {
            await AlbumHealthService.load(store: store)
        }.value
        report = result
        hasLoaded = true
    }
}
