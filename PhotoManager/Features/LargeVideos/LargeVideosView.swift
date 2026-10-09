import SwiftUI

struct LargeVideosView: View {
    @State private var viewModel = LargeVideosViewModel()
    @State private var confirmDelete = false

    var body: some View {
        List(viewModel.videos, selection: $viewModel.selection) { video in
            HStack(spacing: 12) {
                AssetThumbnailView(localIdentifier: video.id)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.fileSize(video.fileSize))
                        .font(.headline)
                    Text(Formatters.duration(video.duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let date = video.creationDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .overlay {
            if viewModel.isLoading && viewModel.videos.isEmpty {
                ProgressView("正在扫描视频…")
            } else if !viewModel.isLoading && viewModel.videos.isEmpty {
                ContentUnavailableView("没有视频", systemImage: "video.slash")
            }
        }
        .navigationTitle("大体积视频")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .task { await viewModel.load() }
        .confirmationDialog(
            "删除 \(viewModel.selection.count) 个视频？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("将释放约 \(Formatters.fileSize(viewModel.selectedSize))。已删除的视频会保留在\"最近删除\"中 30 天。")
        }
    }

    private var bottomBar: some View {
        HStack {
            Text("共 \(viewModel.videos.count) 个 · \(Formatters.fileSize(viewModel.totalSize))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("删除所选", role: .destructive) {
                confirmDelete = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selection.isEmpty)
        }
        .padding()
        .background(.bar)
    }
}
