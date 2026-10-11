import SwiftUI
import Photos

struct LibraryDashboard: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var selectedColor: PhotoColorCategory?
    @State private var showReanalysisConfirmation = false

    private var activeColor: PhotoColorCategory? {
        if let selectedColor, library.availableColors.contains(selectedColor) {
            return selectedColor
        }
        return library.availableColors.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if library.isScanning {
                    ScanProgressCard()
                        .padding(.horizontal)
                }

                if library.analyses.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Première analyse en cours")
                            .font(.title3.bold())
                        Text("Les premiers groupes apparaîtront ici au fur et à mesure.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.top, 70)
                } else {
                    ColorPickerStrip(selectedColor: $selectedColor)

                    if let color = activeColor {
                        ContentGroups(color: color)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if library.authorizationStatus == .limited {
                        Button {
                            library.presentLimitedLibraryPicker()
                        } label: {
                            Label("Choisir plus de photos", systemImage: "photo.badge.plus")
                        }
                    }

                    Button {
                        Task { await library.reloadLibrary(forceAnalysis: false) }
                    } label: {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        showReanalysisConfirmation = true
                    } label: {
                        Label("Tout réanalyser", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Ré-analyser toute la photothèque ?",
            isPresented: $showReanalysisConfirmation,
            titleVisibility: .visible
        ) {
            Button("Tout réanalyser", role: .destructive) {
                Task { await library.reloadLibrary(forceAnalysis: true) }
            }
        } message: {
            Text("Seul l’index local sera remplacé. Vos photos ne seront pas modifiées.")
        }
    }
}

private struct ScanProgressCard: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Analyse avec Vision", systemImage: "viewfinder")
                    .font(.headline)
                Spacer()
                Text("\(library.scannedCount)/\(library.totalCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: library.scanProgress)
                .tint(.accentColor)

            Text("Vous pouvez déjà parcourir les photos classées.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ColorPickerStrip: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Binding var selectedColor: PhotoColorCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Couleur")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(library.availableColors) { color in
                        let isSelected = (selectedColor ?? library.availableColors.first) == color
                        Button {
                            withAnimation(.snappy) {
                                selectedColor = color
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color.color)
                                    .stroke(.primary.opacity(0.12), lineWidth: 1)
                                    .frame(width: 20, height: 20)
                                Text(color.rawValue)
                                    .fontWeight(.semibold)
                                Text("\(library.analyses(color: color).count)")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.16) : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ContentGroups: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let color: PhotoColorCategory

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Contenu")
                .font(.title2.bold())

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(library.contents(for: color)) { content in
                    NavigationLink {
                        PhotoGridView(color: color, content: content)
                    } label: {
                        ContentGroupCard(
                            content: content,
                            photos: library.analyses(color: color, content: content)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct ContentGroupCard: View {
    let content: PhotoContentCategory
    let photos: [PhotoAnalysis]

    private var visiblePhotos: [PhotoAnalysis] {
        Array(photos.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let spacing: CGFloat = 2
                let gapCount = CGFloat(max(visiblePhotos.count - 1, 0))
                let itemWidth = (geometry.size.width - (spacing * gapCount))
                    / CGFloat(max(visiblePhotos.count, 1))

                HStack(spacing: spacing) {
                    ForEach(visiblePhotos) { photo in
                        PhotoThumbnail(assetIdentifier: photo.assetIdentifier)
                            .frame(width: itemWidth, height: geometry.size.height)
                            .clipped()
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .leading
                )
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .frame(height: 112)

            HStack(spacing: 8) {
                Image(systemName: content.symbol)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.rawValue)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(photos.count) photo\(photos.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
