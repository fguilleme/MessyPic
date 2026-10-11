import SwiftUI

struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let photo: PhotoAnalysis

    @State private var image: UIImage?
    @State private var isSharing = false
    @State private var isPreparingShare = false
    @State private var shareItems: [Any] = []
    @State private var showShareError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(1, contentMode: .fit)

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                            .controlSize(.large)
                    }
                }

                VStack(spacing: 12) {
                    DetailRow(
                        icon: "paintpalette.fill",
                        title: "Couleur",
                        value: photo.color.rawValue,
                        tint: photo.color.color
                    )
                    DetailRow(
                        icon: photo.content.symbol,
                        title: "Contenu",
                        value: photo.content.rawValue,
                        tint: .accentColor
                    )
                    DetailRow(
                        icon: "viewfinder",
                        title: "Reconnu par Vision",
                        value: photo.label,
                        tint: .purple
                    )
                    if let date = photo.creationDate {
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: date.formatted(date: .abbreviated, time: .omitted),
                            tint: .orange
                        )
                    }
                }
                .padding(.horizontal)

                Button {
                    prepareShare()
                } label: {
                    HStack {
                        if isPreparingShare {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isPreparingShare ? "Préparation…" : "Ouvrir avec une autre app")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(image == nil || isPreparingShare)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(photo.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    prepareShare()
                } label: {
                    Label("Ouvrir avec…", systemImage: "square.and.arrow.up")
                }
                .disabled(image == nil || isPreparingShare)
            }
        }
        .sheet(isPresented: $isSharing) {
            ActivityView(activityItems: shareItems)
        }
        .alert("Impossible de préparer la photo", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La photo originale n’est pas disponible pour le moment.")
        }
        .task(id: photo.assetIdentifier) {
            image = await library.originalImage(identifier: photo.assetIdentifier)
        }
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true

        Task {
            if let fileURL = await library.shareableFileURL(identifier: photo.assetIdentifier) {
                shareItems = [fileURL]
                isSharing = true
            } else {
                showShareError = true
            }
            isPreparingShare = false
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(tint)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
