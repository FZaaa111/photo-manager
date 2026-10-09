import SwiftUI

/// 相似 / 重复照片的分组列表页。
struct GroupCleanupView: View {
    @Environment(AppServices.self) private var services
    @State private var viewModel: GroupCleanupViewModel
    @State private var confirmMergeAll = false

    init(kind: GroupKind) {
        _viewModel = State(initialValue: GroupCleanupViewModel(kind: kind))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .failed:
                ScanIdleView(
                    title: viewModel.kind.navigationTitle,
                    systemImage: viewModel.kind == .similar ? "square.on.square" : "doc.on.doc",
                    message: idleMessage,
                    errorMessage: failureMessage,
                    onStart: { viewModel.scan(using: services.pipeline) }
                )
            case .scanning(let progress):
                ScanProgressView(progress: progress, onCancel: viewModel.cancelScan)
            case .done:
                resultList
            }
        }
        .navigationTitle(viewModel.kind.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.state == .done {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.kind == .similar {
                            Picker("相似度", selection: $viewModel.level) {
                                ForEach(SimilarityLevel.allCases) { Text($0.title).tag($0) }
                            }
                        }
                        Button("重新扫描") { viewModel.scan(using: services.pipeline) }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .onChange(of: viewModel.level) {
            if viewModel.state == .done { viewModel.scan(using: services.pipeline) }
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            if viewModel.state.isScanning { viewModel.cancelScan() }
        }
    }

    private var idleMessage: String {
        switch viewModel.kind {
        case .similar: "找出连拍和同一场景的多张照片，推荐保留最好的一张。"
        case .duplicate: "找出内容完全相同的重复照片，只保留一份。"
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

    @ViewBuilder
    private var resultList: some View {
        if viewModel.groups.isEmpty {
            ContentUnavailableView(
                "没有发现\(viewModel.kind == .similar ? "相似" : "重复")照片",
                systemImage: "checkmark.circle",
                description: viewModel.kind == .similar ? Text("可以在右上角调高相似度宽松程度再试一次") : nil
            )
        } else {
            List(viewModel.groups) { group in
                NavigationLink {
                    GroupDetailView(groupID: group.id, viewModel: viewModel)
                } label: {
                    GroupRow(group: group)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(viewModel.groups.count) 组 · 可删除 \(viewModel.totalRemovable) 张")
                        if viewModel.totalReclaimable > 0 {
                            Text("约释放 \(Formatters.fileSize(viewModel.totalReclaimable))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                    Spacer()
                    Button("全部合并", role: .destructive) { confirmMergeAll = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.bar)
            }
            .confirmationDialog(
                "合并全部 \(viewModel.groups.count) 组？",
                isPresented: $confirmMergeAll,
                titleVisibility: .visible
            ) {
                Button("按推荐保留并删除其余", role: .destructive) {
                    Task { await viewModel.mergeAll() }
                }
            } message: {
                Text("每组保留标星的一张，其余 \(viewModel.totalRemovable) 张移入\"最近删除\"，30 天内可恢复。")
            }
        }
    }
}

private struct GroupRow: View {
    let group: PhotoGroup

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                AssetThumbnailView(localIdentifier: group.keepID, side: 72)
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.members.count) 张")
                    .font(.headline)
                if group.reclaimableBytes > 0 {
                    Text("可释放 \(Formatters.fileSize(group.reclaimableBytes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let date = group.members.first?.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 单组详情：点按缩略图可更换保留项。
struct GroupDetailView: View {
    let groupID: String
    let viewModel: GroupCleanupViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false

    private var group: PhotoGroup? {
        viewModel.groups.first { $0.id == groupID }
    }

    var body: some View {
        Group {
            if let group {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 10) {
                        ForEach(group.members) { member in
                            memberCell(member, in: group)
                        }
                    }
                    .padding(8)
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Text("点按缩略图更换保留项")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("保留标星并删除其余", role: .destructive) { confirm = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.bar)
                }
                .confirmationDialog(
                    "删除其余 \(group.removable.count) 张？",
                    isPresented: $confirm,
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) {
                        Task {
                            await viewModel.merge(group)
                            dismiss()
                        }
                    }
                } message: {
                    Text("被删照片的收藏状态和所属相册会并入保留的那张。已删除的照片保留在\"最近删除\"中 30 天。")
                }
            } else {
                ContentUnavailableView("该组已处理", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("\(group?.members.count ?? 0) 张")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memberCell(_ member: AnalysisRecord, in group: PhotoGroup) -> some View {
        let isKeep = member.id == group.keepID
        return Button {
            viewModel.setKeep(member.id, in: group.id)
        } label: {
            VStack(spacing: 4) {
                AssetThumbnailView(localIdentifier: member.id, side: 110)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: isKeep ? "star.circle.fill" : "trash.circle")
                            .font(.title3)
                            .foregroundStyle(isKeep ? Color.yellow : Color.white)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                    .overlay {
                        if isKeep {
                            RoundedRectangle(cornerRadius: 6).stroke(Color.yellow, lineWidth: 3)
                        }
                    }
                Text(detail(for: member))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func detail(for member: AnalysisRecord) -> String {
        var parts: [String] = []
        if member.fileSize > 0 { parts.append(Formatters.fileSize(member.fileSize)) }
        if viewModel.kind == .similar, let sharpness = member.sharpness {
            parts.append("清晰度 \(Int(sharpness))")
        }
        return parts.joined(separator: " · ")
    }
}
