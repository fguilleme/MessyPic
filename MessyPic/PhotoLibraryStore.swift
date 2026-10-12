import Combine
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum PhotoLibraryState: Equatable {
    case idle
    case loading
    case denied
    case empty
    case ready
    case failed(String)
}

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var state: PhotoLibraryState = .idle
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var analyses: [PhotoAnalysis] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedCount = 0
    @Published private(set) var totalCount = 0

    private let imageManager = PHCachingImageManager()
    private let cache = AnalysisCache()
    private var assetsByIdentifier: [String: PHAsset] = [:]
    private var didPrepare = false

    var scanProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(scannedCount) / Double(totalCount)
    }

    var availableColors: [PhotoColorCategory] {
        let counts = Dictionary(grouping: analyses, by: \.color)
            .mapValues(\.count)

        return PhotoColorCategory.allCases
            .filter { counts[$0, default: 0] > 0 }
            .sorted { lhs, rhs in
                let lhsCount = counts[lhs, default: 0]
                let rhsCount = counts[rhs, default: 0]
                if lhsCount == rhsCount {
                    return PhotoColorCategory.allCases.firstIndex(of: lhs)! <
                        PhotoColorCategory.allCases.firstIndex(of: rhs)!
                }
                return lhsCount > rhsCount
        }
    }

    static let preview: PhotoLibraryStore = {
        let store = PhotoLibraryStore()
        store.state = .ready
        store.authorizationStatus = .authorized
        store.analyses = [
            PhotoAnalysis(assetIdentifier: "preview-1", color: .blue, content: .nature, label: "Lac", confidence: 0.91, creationDate: .now),
            PhotoAnalysis(assetIdentifier: "preview-2", color: .blue, content: .people, label: "Portrait", confidence: 0.86, creationDate: .now),
            PhotoAnalysis(assetIdentifier: "preview-3", color: .green, content: .animals, label: "Chien", confidence: 0.83, creationDate: .now)
        ]
        return store
    }()

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch authorizationStatus {
        case .authorized, .limited:
            await reloadLibrary(forceAnalysis: false)
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            state = .idle
        @unknown default:
            state = .denied
        }
    }

    func requestAccess() async {
        state = .loading
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch authorizationStatus {
        case .authorized, .limited:
            await reloadLibrary(forceAnalysis: false)
        case .denied, .restricted:
            state = .denied
        case .notDetermined:
            state = .idle
        @unknown default:
            state = .denied
        }
    }

    func reloadLibrary(forceAnalysis: Bool) async {
        state = .loading

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var fetched: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            fetched[asset.localIdentifier] = asset
        }
        assetsByIdentifier = fetched

        guard !fetched.isEmpty else {
            analyses = []
            state = .empty
            return
        }

        if forceAnalysis {
            analyses = []
        } else {
            let identifiers = Set(fetched.keys)
            analyses = cache.load()
                .filter { identifiers.contains($0.assetIdentifier) }
                .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }

        state = .ready
        await analyzeMissingPhotos()
    }

    func analyses(color: PhotoColorCategory, content: PhotoContentCategory? = nil) -> [PhotoAnalysis] {
        analyses.filter { analysis in
            analysis.color == color && (content == nil || analysis.content == content)
        }
    }

    func contents(for color: PhotoColorCategory) -> [PhotoContentCategory] {
        PhotoContentCategory.allCases.filter { content in
            analyses.contains { $0.color == color && $0.content == content }
        }
    }

    func image(identifier: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = assetsByIdentifier[identifier] else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func originalImage(identifier: String) async -> UIImage? {
        guard let asset = assetsByIdentifier[identifier] else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isNetworkAccessAllowed = true

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data.flatMap(UIImage.init(data:)))
            }
        }
    }

    func shareableFileURL(identifier: String) async -> URL? {
        guard let asset = assetsByIdentifier[identifier] else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isNetworkAccessAllowed = true

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let fileExtension = dataUTI
                    .flatMap(UTType.init)
                    .flatMap(\.preferredFilenameExtension) ?? "jpg"
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("MessyPicShare", isDirectory: true)

                do {
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                    let url = directory
                        .appendingPathComponent("MessyPic-\(UUID().uuidString)")
                        .appendingPathExtension(fileExtension)
                    try data.write(to: url, options: .atomic)
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let controller = scene.keyWindow?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { [weak self] _ in
            Task { @MainActor in
                await self?.reloadLibrary(forceAnalysis: false)
            }
        }
    }

    private func analyzeMissingPhotos() async {
        guard !isScanning else { return }

        let completed = Set(
            analyses
                .filter {
                    !$0.principalColors.isEmpty &&
                        $0.analysisVersion >= PhotoAnalysis.currentAnalysisVersion
                }
                .map(\.assetIdentifier)
        )
        let missingAssets = assetsByIdentifier.values
            .filter { !completed.contains($0.localIdentifier) }
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        guard !missingAssets.isEmpty else { return }

        isScanning = true
        scannedCount = 0
        totalCount = missingAssets.count
        defer { isScanning = false }

        for asset in missingAssets {
            guard !Task.isCancelled else { break }
            if let image = await analysisImage(for: asset), let cgImage = image.cgImage {
                let result = await Task.detached(priority: .utility) {
                    PhotoAnalyzer.analyze(cgImage)
                }.value
                let analysis = PhotoAnalysis(
                    assetIdentifier: asset.localIdentifier,
                    color: result.color,
                    content: result.content,
                    label: result.label,
                    confidence: result.confidence,
                    creationDate: asset.creationDate,
                    visionResults: result.visionResults,
                    principalColors: result.principalColors
                )
                if let index = analyses.firstIndex(where: { $0.assetIdentifier == asset.localIdentifier }) {
                    analyses[index] = analysis
                } else {
                    analyses.append(analysis)
                }
                analyses.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            }

            scannedCount += 1
            if scannedCount.isMultiple(of: 12) {
                cache.save(analyses)
            }
            await Task.yield()
        }

        cache.save(analyses)
    }

    private func analysisImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 384, height: 384),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow)
    }
}
