import SwiftUI

struct LargeVideosView: View {
    @State private var viewModel = LargeVideosViewModel()
    @State private var confirmDelete = false
    @State private var showFilter = false

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
            if viewModel.isLoading && viewModel.allVideos.isEmpty {
                ProgressView("正在扫描视频…")
            } else if !viewModel.isLoading && viewModel.videos.isEmpty {
                ContentUnavailableView(
                    viewModel.allVideos.isEmpty ? "没有视频" : "没有符合条件的视频",
                    systemImage: "video.slash",
                    description: viewModel.allVideos.isEmpty ? nil : Text("试试放宽筛选条件")
                )
            }
        }
        .navigationTitle("大体积视频")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("全选") { viewModel.selectAllVisible() }
                    .disabled(viewModel.videos.isEmpty)
                Button {
                    showFilter = true
                } label: {
                    Image(systemName: viewModel.filter.isDefault
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showFilter) {
            VideoFilterSheet(filter: $viewModel.filter)
                .presentationDetents([.medium])
        }
        .onChange(of: viewModel.filter) {
            viewModel.pruneSelectionToVisible()
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

private struct VideoFilterSheet: View {
    @Binding var filter: VideoFilter
    @Environment(\.dismiss) private var dismiss
    @State private var useDateLimit = false
    @State private var dateLimit = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Picker("最小体积", selection: $filter.minSize) {
                    ForEach(VideoSizePreset.allCases) { Text($0.title).tag($0) }
                }
                Picker("最短时长", selection: $filter.minDuration) {
                    ForEach(VideoDurationPreset.allCases) { Text($0.title).tag($0) }
                }
                Picker("排序", selection: $filter.sortKey) {
                    ForEach(VideoSortKey.allCases) { Text($0.title).tag($0) }
                }
                Section {
                    Toggle("仅显示早于某日期的视频", isOn: $useDateLimit)
                    if useDateLimit {
                        DatePicker("早于", selection: $dateLimit, displayedComponents: .date)
                    }
                }
                Section {
                    Button("恢复默认", role: .destructive) {
                        filter = VideoFilter()
                        useDateLimit = false
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                if let date = filter.shotBefore {
                    dateLimit = date
                    useDateLimit = true
                }
            }
            .onChange(of: useDateLimit) { updateDateLimit() }
            .onChange(of: dateLimit) { updateDateLimit() }
        }
    }

    private func updateDateLimit() {
        filter.shotBefore = useDateLimit ? dateLimit : nil
    }
}
