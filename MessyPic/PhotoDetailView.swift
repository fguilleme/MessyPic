import SwiftUI

struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let photo: PhotoAnalysis

    @State private var image: UIImage?
    @State private var isSharing = false
    @State private var isPreparingShare = false
    @State private var shareItems: [Any] = []
    @State private var showShareError = false

    private var currentPhoto: PhotoAnalysis {
        library.analyses.first { $0.assetIdentifier == photo.assetIdentifier } ?? photo
    }

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
                        title: currentPhoto.subjectColors.isEmpty ? "Couleur" : "Couleur du sujet",
                        value: currentPhoto.color.rawValue,
                        tint: currentPhoto.color.color
                    )
                    DetailRow(
                        icon: currentPhoto.content.symbol,
                        title: "Contenu",
                        value: currentPhoto.content.rawValue,
                        tint: .accentColor
                    )
                    if let date = photo.creationDate {
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: date.formatted(date: .abbreviated, time: .omitted),
                            tint: .orange
                        )
                    }

                    PrincipalColorsCard(photo: currentPhoto)
                    VisionDetails(photo: currentPhoto)
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
        .navigationTitle(currentPhoto.label)
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

private struct PrincipalColorsCard: View {
    let photo: PhotoAnalysis

    @State private var isGlobalExpanded = false

    private var colors: [PrincipalColor] {
        photo.subjectColors.isEmpty ? photo.principalColors : photo.subjectColors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                photo.subjectColors.isEmpty ? "Couleurs principales" : "Couleurs du sujet",
                systemImage: "paintpalette"
            )
                .font(.subheadline.weight(.semibold))

            if colors.isEmpty {
                HStack(spacing: 9) {
                    ColorSwatch(color: photo.color.color, size: 28)
                    Text(photo.color.rawValue)
                        .font(.caption)
                }
            } else {
                PaletteSwatches(colors: colors)
            }

            if !photo.subjectColors.isEmpty {
                Text("Proportions dans le sujet détecté")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                DisclosureGroup(isExpanded: $isGlobalExpanded) {
                    PaletteSwatches(colors: photo.principalColors)
                        .padding(.top, 10)
                } label: {
                    Text("Couleurs de toute la photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PaletteSwatches: View {
    let colors: [PrincipalColor]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(colors) { sample in
                    VStack(spacing: 5) {
                        ColorSwatch(color: sample.color, size: 30)
                        Text(sample.proportion, format: .percent.precision(.fractionLength(0)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Couleur \(sample.hex), \(sample.proportion.formatted(.percent.precision(.fractionLength(0))))")
                }
            }
        }
    }
}

private struct VisionDetails: View {
    let photo: PhotoAnalysis

    @State private var isExpanded = false

    private var visionResults: [VisionResult] {
        if photo.visionResults.isEmpty {
            return [VisionResult(identifier: photo.label, confidence: photo.confidence)]
        }
        return photo.visionResults
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(visionResults) { result in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(result.identifier)
                            .lineLimit(2)
                        Spacer(minLength: 12)
                        Text(result.confidence, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .font(.caption2)
            .padding(.top, 12)
        } label: {
            Label("Résultats de Vision", systemImage: "viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .tint(.purple)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHint(isExpanded ? "Masque les résultats" : "Affiche les résultats détaillés de Vision")
    }
}

private struct ColorSwatch: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(.primary.opacity(0.16), lineWidth: 1)
            }
            .accessibilityHidden(true)
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
