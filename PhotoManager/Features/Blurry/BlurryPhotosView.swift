import SwiftUI

/// TODO(M2): 拉普拉斯方差清晰度检测，按模糊程度排序。
struct BlurryPhotosView: View {
    var body: some View {
        ContentUnavailableView(
            "模糊照片",
            systemImage: "camera.metering.unknown",
            description: Text("功能开发中")
        )
        .navigationTitle("模糊照片")
    }
}
