import SwiftUI

/// 根据相册授权状态决定展示权限引导页还是主界面。
struct RootView: View {
    @Environment(PhotoLibraryService.self) private var library

    var body: some View {
        switch library.authorization {
        case .authorized, .limited:
            NavigationStack {
                DashboardView()
            }
        case .notDetermined, .denied:
            PermissionView()
        }
    }
}

private struct PermissionView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("需要访问你的相册")
                .font(.title2.bold())
            Text("Photo Manager 会在本机分析相册，找出相似照片、模糊照片和大体积视频。不会上传任何内容，删除前一定会让你确认。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if library.authorization == .denied {
                Button("前往设置开启权限") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("允许访问相册") {
                    Task { await library.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }
}
