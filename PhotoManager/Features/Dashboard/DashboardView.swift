import SwiftUI

struct DashboardView: View {
    @Environment(PhotoLibraryService.self) private var library

    var body: some View {
        List {
            if library.authorization == .limited {
                Section {
                    Label("当前仅允许访问部分照片，请在系统设置中选择\"所有照片\"以获得完整结果。", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("相册概览") {
                LabeledContent("照片", value: "\(library.photoCount())")
                LabeledContent("视频", value: "\(library.videoCount())")
            }

            Section("清理") {
                NavigationLink {
                    SimilarPhotosView()
                } label: {
                    Label("相似照片", systemImage: "square.on.square")
                }
                NavigationLink {
                    BlurryPhotosView()
                } label: {
                    Label("模糊照片", systemImage: "camera.metering.unknown")
                }
                NavigationLink {
                    LargeVideosView()
                } label: {
                    Label("大体积视频", systemImage: "video")
                }
            }
        }
        .navigationTitle("Photo Manager")
    }
}
