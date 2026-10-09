import Foundation
import Observation

@MainActor
@Observable
final class LargeVideosViewModel {
    private(set) var videos: [VideoItem] = []
    private(set) var isLoading = false
    var selection = Set<String>()
    var errorMessage: String?

    var totalSize: Int64 {
        videos.reduce(0) { $0 + $1.fileSize }
    }

    var selectedSize: Int64 {
        videos.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        videos = await Task.detached(priority: .userInitiated) {
            VideoScanner.scan()
        }.value
        selection.formIntersection(videos.map(\.id))
    }

    func deleteSelected() async {
        let ids = Array(selection)
        do {
            try await PhotoDeletionService.delete(localIdentifiers: ids)
        } catch {
            // 用户在系统确认框中点"取消"也会走到这里，重新加载以反映真实状态即可。
            errorMessage = error.localizedDescription
        }
        await load()
    }
}
