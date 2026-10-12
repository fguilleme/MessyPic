import SwiftUI
import Photos

struct LibraryDashboard: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @AppStorage("photoGroupingOrder") private var groupingOrder: PhotoGroupingOrder = .colorThenContent
    @State private var selectedColor: PhotoColorCategory?
    @State private var selectedContent: PhotoContentCategory?
    @State private var showReanalysisConfirmation = false

    private var activeColor: PhotoColorCategory? {
        if let selectedColor, library.availableColors.contains(selectedColor) {
            return selectedColor
        }
        return library.availableColors.first
    }

    private var activeContent: PhotoContentCategory? {
        if let selectedContent, library.availableContents.contains(selectedContent) {
            return selectedContent
        }
        return library.availableContents.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Classement")
                        .font(.subheadline.weight(.semibold))
                    Picker("Ordre de classement", selection: $groupingOrder) {
                        ForEach(PhotoGroupingOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("groupingOrderPicker")
                }
                .padding(.horizontal)

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
                    switch groupingOrder {
                    case .colorThenContent:
                        CategoryPickerStrip(
                            title: "1. Couleur",
                            categories: library.availableColors,
                            selectedCategory: activeColor,
                            onSelect: { selectedColor = $0 },
                            categoryTitle: { $0.rawValue },
                            count: { library.analyses(color: $0).count }
                        ) { color in
                            Circle()
                                .fill(color.color)
                                .stroke(.primary.opacity(0.12), lineWidth: 1)
                                .frame(width: 20, height: 20)
                        }

                        if let color = activeColor {
                            ContentGroups(color: color)
                        }
                    case .contentThenColor:
                        CategoryPickerStrip(
                            title: "1. Contenu",
                            categories: library.availableContents,
                            selectedCategory: activeContent,
                            onSelect: { selectedContent = $0 },
                            categoryTitle: { $0.rawValue },
                            count: { library.analyses(content: $0).count }
                        ) { content in
                            Image(systemName: content.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: 20, height: 20)
                        }

                        if let content = activeContent {
                            ColorGroups(content: content)
                        }
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

private struct CategoryPickerStrip<Category: Identifiable & Equatable, Icon: View>: View {
    let title: String
    let categories: [Category]
    let selectedCategory: Category?
    let onSelect: (Category) -> Void
    let categoryTitle: (Category) -> String
    let count: (Category) -> Int
    let icon: (Category) -> Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        let isSelected = selectedCategory == category
                        Button {
                            withAnimation(.snappy) {
                                onSelect(category)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                icon(category)
                                Text(categoryTitle(category))
                                    .fontWeight(.semibold)
                                Text("\(count(category))")
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
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                        PhotoGroupCard(
                            title: content.rawValue,
                            symbol: content.symbol,
                            tint: .accentColor,
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

private struct ColorGroups: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let content: PhotoContentCategory

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Couleur")
                .font(.title2.bold())

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(library.colors(for: content)) { color in
                    NavigationLink {
                        PhotoGridView(color: color, content: content, groupingOrder: .contentThenColor)
                    } label: {
                        PhotoGroupCard(
                            title: color.rawValue,
                            symbol: "paintpalette.fill",
                            tint: color.color,
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

private struct PhotoGroupCard: View {
    let title: String
    let symbol: String
    let tint: Color
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
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
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
