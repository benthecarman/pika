import SwiftUI

struct ChatMediaGalleryView: View {
    let chatId: String
    let items: [MediaGalleryItem]

    @State private var fullscreenAttachment: ChatMediaAttachment?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Media")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Photos and videos shared in this chat will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items, id: \.attachment.originalHashHex) { item in
                            mediaThumbnail(item)
                        }
                    }
                }
            }
        }
        .navigationTitle("Media")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $fullscreenAttachment) { attachment in
            FullscreenImageViewer(attachment: attachment)
        }
    }

    @ViewBuilder
    private func mediaThumbnail(_ item: MediaGalleryItem) -> some View {
        let attachment = item.attachment
        if let localPath = attachment.localPath {
            Button {
                fullscreenAttachment = attachment
            } label: {
                CachedAsyncImage(url: URL(fileURLWithPath: localPath)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay { ProgressView() }
                }
                .frame(minHeight: 120)
                .clipped()
            }
            .buttonStyle(.plain)
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(minHeight: 120)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
