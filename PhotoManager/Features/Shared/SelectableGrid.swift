import SwiftUI

/// 带勾选状态的缩略图网格。
struct SelectableGrid: View {
    let items: [AnalysisRecord]
    @Binding var selection: Set<String>
    /// 缩略图下方的说明文字。
    var caption: (AnalysisRecord) -> String? = { _ in nil }

    private let side: CGFloat = 110
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: side), spacing: 6)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    cell(for: item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private func cell(for item: AnalysisRecord) -> some View {
        let isSelected = selection.contains(item.id)
        return Button {
            if isSelected {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } label: {
            VStack(spacing: 4) {
                AssetThumbnailView(localIdentifier: item.id, side: side)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.white)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
                if let text = caption(item) {
                    Text(text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
