import SwiftUI

struct ScanProgressView: View {
    let progress: ScanProgressSnapshot
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .frame(maxWidth: 240)
            } else {
                ProgressView()
            }
            Text(progress.title)
                .font(.headline)
            if progress.total > 0 {
                Text("\(progress.completed) / \(progress.total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("首次扫描大相册可能需要几分钟，之后只会处理新增的照片。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("取消", role: .cancel, action: onCancel)
        }
        .padding(32)
    }
}

/// 扫描未开始 / 失败时的占位页。
struct ScanIdleView: View {
    let title: String
    let systemImage: String
    let message: String
    var errorMessage: String?
    var onStart: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            VStack(spacing: 8) {
                Text(message)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        } actions: {
            Button("开始扫描", action: onStart)
                .buttonStyle(.borderedProminent)
        }
    }
}
