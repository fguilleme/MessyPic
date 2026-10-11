import SwiftUI

struct PhotoThumbnail: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let assetIdentifier: String
    var targetSize = CGSize(width: 320, height: 320)

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.tertiarySystemFill))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .transition(.opacity)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: assetIdentifier) {
            image = await library.image(identifier: assetIdentifier, targetSize: targetSize)
        }
    }
}
