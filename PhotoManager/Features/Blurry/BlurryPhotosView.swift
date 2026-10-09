import SwiftUI

struct BlurryPhotosView: View {
    @Environment(AppServices.self) private var services
    @State private var viewModel = BlurryPhotosViewModel()
    @State private var confirmDelete = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .failed:
                ScanIdleView(
                    title: "模糊照片",
                    systemImage: "camera.metering.unknown",
                    message: "检测对焦失败、抖动或运动模糊的照片。分析在本机完成，不会上传。",
                    errorMessage: failureMessage,
                    onStart: { viewModel.scan(using: services) }
                )
            case .scanning(let progress):
                ScanProgressView(progress: progress, onCancel: viewModel.cancelScan)
            case .done:
                resultView
            }
        }
        .navigationTitle("模糊照片")
        .navigationBarTitleDisplayMode(.inline)
        .alert("操作失败", isPresented: errorBinding) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            if viewModel.state.isScanning { viewModel.cancelScan() }
        }
    }

    private var failureMessage: String? {
        if case .failed(let message) = viewModel.state { return message }
        return nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            thresholdControl
            Divider()
            if viewModel.blurry.isEmpty {
                ContentUnavailableView(
                    "没有发现模糊照片",
                    systemImage: "checkmark.circle",
                    description: Text("可以调高阈值，把更多照片判定为模糊")
                )
            } else {
                SelectableGrid(
                    items: viewModel.blurry,
                    selection: $viewModel.selection,
                    caption: { record in
                        record.sharpness.map { "清晰度 \(Int($0))" }
                    }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("全选") { viewModel.selectAllVisible() }
                    .disabled(viewModel.blurry.isEmpty)
                Button {
                    viewModel.scan(using: services)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("共 \(viewModel.blurry.count) 张 · 已选 \(viewModel.selection.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("忽略") {
                    Task { await viewModel.ignoreSelected(using: services.store) }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selection.isEmpty)
                Button("删除", role: .destructive) { confirmDelete = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selection.isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .confirmationDialog(
            "删除 \(viewModel.selection.count) 张照片？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("已删除的照片保留在\"最近删除\"中 30 天。")
        }
    }

    private var thresholdControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("模糊阈值 \(Int(viewModel.threshold))")
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Toggle("包含截图", isOn: $viewModel.includeScreenshots)
                    .toggleStyle(.switch)
                    .fixedSize()
                    .font(.footnote)
            }
            Slider(value: $viewModel.threshold, in: BlurryFilter.thresholdRange, step: 5)
            Text("分数越低越模糊；低于阈值的照片会被列出。纯色或低纹理照片（白墙、夜景）可能被误判，可用\"忽略\"排除。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onChange(of: viewModel.threshold) { viewModel.pruneSelection() }
        .onChange(of: viewModel.includeScreenshots) { viewModel.pruneSelection() }
    }
}
