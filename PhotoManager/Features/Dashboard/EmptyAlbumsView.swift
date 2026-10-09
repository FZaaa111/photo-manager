import SwiftUI

/// 列出空相册，支持删除相册本身（不影响任何照片）。
struct EmptyAlbumsView: View {
    @State private var albums: [AlbumSummary]
    @State private var selection = Set<String>()
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    init(albums: [AlbumSummary]) {
        _albums = State(initialValue: albums)
    }

    var body: some View {
        List(albums, selection: $selection) { album in
            Label(album.title, systemImage: "rectangle.stack")
        }
        .environment(\.editMode, .constant(.active))
        .overlay {
            if albums.isEmpty {
                ContentUnavailableView("没有空相册", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("空相册")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("全选") { selection = Set(albums.map(\.id)) }
                    .disabled(albums.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("删除所选相册", role: .destructive) { confirmDelete = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .confirmationDialog(
            "删除 \(selection.count) 个空相册？",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { Task { await deleteSelected() } }
        } message: {
            Text("只会删除相册本身，不会影响任何照片。")
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteSelected() async {
        let ids = Array(selection)
        do {
            try await AlbumHealthService.deleteAlbums(localIdentifiers: ids)
            albums.removeAll { selection.contains($0.id) }
            selection.removeAll()
        } catch {
            if !PhotoDeletionService.isUserCancelled(error) {
                errorMessage = error.localizedDescription
            }
        }
    }
}
