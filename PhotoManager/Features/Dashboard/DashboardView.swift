import SwiftUI

struct DashboardView: View {
    @Environment(PhotoLibraryService.self) private var library
    @Environment(AppServices.self) private var services
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        List {
            if library.authorization == .limited {
                Section {
                    Label("当前仅允许访问部分照片，请在系统设置中选择\"所有照片\"以获得完整结果。", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            overviewSection
            suggestionsSection
            cleanupSection
            compositionSection
        }
        .navigationTitle("Photo Manager")
        .refreshable { await viewModel.refresh(store: services.store) }
        .task { await viewModel.refresh(store: services.store) }
    }

    // MARK: 区块

    private var overviewSection: some View {
        Section("相册概览") {
            LabeledContent("照片", value: "\(viewModel.report.photoCount)")
            LabeledContent("视频", value: "\(viewModel.report.videoCount)")
            if viewModel.report.photoCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: viewModel.report.analyzedFraction)
                    Text("已分析 \(viewModel.report.analyzedPhotoCount) / \(viewModel.report.photoCount) 张，进入清理页扫描可提高检测覆盖率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        Section("健康检查") {
            if viewModel.isLoading && !viewModel.hasLoaded {
                HStack {
                    ProgressView()
                    Text("正在检查相册…").foregroundStyle(.secondary)
                }
            } else if viewModel.report.suggestions.isEmpty {
                Label("相册很整洁，暂时没有清理建议", systemImage: "checkmark.seal")
                    .foregroundStyle(.green)
            } else {
                ForEach(Array(viewModel.report.suggestions.enumerated()), id: \.offset) { _, suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: HealthSuggestion) -> some View {
        switch suggestion {
        case .largeVideos:
            NavigationLink { LargeVideosView() } label: {
                Label(suggestion.title, systemImage: suggestion.systemImage)
            }
        case .blurry:
            NavigationLink { BlurryPhotosView() } label: {
                Label(suggestion.title, systemImage: suggestion.systemImage)
            }
        case .emptyAlbums:
            NavigationLink { EmptyAlbumsView(albums: viewModel.report.emptyAlbums) } label: {
                Label(suggestion.title, systemImage: suggestion.systemImage)
            }
        case .screenshots, .screenRecordings, .bursts:
            Label(suggestion.title, systemImage: suggestion.systemImage)
                .foregroundStyle(.secondary)
        }
    }

    private var cleanupSection: some View {
        Section("清理") {
            NavigationLink {
                DuplicatePhotosView()
            } label: {
                Label("重复照片", systemImage: "doc.on.doc")
            }
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

    private var compositionSection: some View {
        Section("相册构成") {
            LabeledContent("截图", value: "\(viewModel.report.screenshotCount)")
            LabeledContent("屏幕录制", value: "\(viewModel.report.screenRecordingCount)")
            LabeledContent("连拍", value: "\(viewModel.report.burstCount)")
            LabeledContent("实况照片", value: "\(viewModel.report.livePhotoCount)")
            LabeledContent("全景照片", value: "\(viewModel.report.panoramaCount)")
        }
    }
}
