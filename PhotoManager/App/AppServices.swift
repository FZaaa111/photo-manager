import Observation
import SwiftData

/// 应用级依赖：SwiftData 容器、缓存访问器与扫描流水线。
@MainActor
@Observable
final class AppServices {
    let container: ModelContainer
    let store: RecordStore
    let pipeline: ScanPipeline

    init(inMemory: Bool = false) {
        let schema = Schema([AssetRecord.self, IgnoredAsset.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            )
        } catch {
            // 缓存可随时重建：磁盘库不可用时退回内存库，而不是让应用崩溃。
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
        self.container = container
        self.store = RecordStore(modelContainer: container)
        self.pipeline = ScanPipeline(store: store)
    }
}
