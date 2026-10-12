import SwiftUI

struct PhotoGridView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let color: PhotoColorCategory
    let content: PhotoContentCategory
    var groupingOrder: PhotoGroupingOrder = .colorThenContent

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var photos: [PhotoAnalysis] {
        library.analyses(color: color, content: content)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    NavigationLink {
                        PhotoDetailView(photo: photo)
                    } label: {
                        PhotoThumbnail(assetIdentifier: photo.assetIdentifier)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(groupingOrder == .colorThenContent ? content.rawValue : color.rawValue)
        .navigationSubtitle("\(groupingOrder == .colorThenContent ? color.rawValue : content.rawValue) · \(photos.count) photo\(photos.count > 1 ? "s" : "")")
        .background(Color(.systemBackground))
    }
}
