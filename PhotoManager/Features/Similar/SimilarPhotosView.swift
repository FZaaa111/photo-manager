import SwiftUI

/// TODO(M3): 感知哈希粗分组 + Vision 特征向量聚类，推荐最佳照片。
struct SimilarPhotosView: View {
    var body: some View {
        ContentUnavailableView(
            "相似照片",
            systemImage: "square.on.square",
            description: Text("功能开发中")
        )
        .navigationTitle("相似照片")
    }
}
