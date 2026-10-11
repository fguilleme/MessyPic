import SwiftUI
import Photos

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        NavigationStack {
            Group {
                switch library.state {
                case .idle:
                    PhotoAccessView()
                case .loading:
                    LoadingLibraryView()
                case .denied:
                    PhotoAccessDeniedView()
                case .empty:
                    EmptyLibraryView()
                case .ready:
                    LibraryDashboard()
                case .failed(let message):
                    ErrorView(message: message)
                }
            }
            .navigationTitle("MessyPic")
        }
        .task {
            await library.prepare()
        }
    }
}

private struct PhotoAccessView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.9), .orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text("Retrouvez vos photos")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("MessyPic classe votre photothèque par couleur, puis par contenu, directement sur votre iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                PrivacyRow(icon: "lock.shield.fill", text: "Analyse privée, entièrement sur l’appareil")
                PrivacyRow(icon: "photo.stack.fill", text: "Vos originaux ne sont jamais déplacés")
                PrivacyRow(icon: "square.and.arrow.up.fill", text: "Ouvrez une image dans une autre app")
            }
            .padding(.vertical, 8)

            Button {
                Task { await library.requestAccess() }
            } label: {
                Label("Autoriser l’accès aux photos", systemImage: "photo.badge.plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(28)
    }
}

private struct PrivacyRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

private struct LoadingLibraryView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Chargement de la photothèque…")
                .font(.headline)
            Text("Aucune photo ne quitte cet appareil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PhotoAccessDeniedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Accès aux photos refusé", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Autorisez MessyPic dans Réglages pour classer votre photothèque.")
        } actions: {
            Button("Ouvrir Réglages") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct EmptyLibraryView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        ContentUnavailableView {
            Label("Aucune photo", systemImage: "photo.stack")
        } description: {
            Text("Ajoutez des photos ou élargissez la sélection autorisée à MessyPic.")
        } actions: {
            if library.authorizationStatus == .limited {
                Button("Choisir plus de photos") {
                    library.presentLimitedLibraryPicker()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ErrorView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Impossible de charger les photos", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer") {
                Task { await library.reloadLibrary(forceAnalysis: false) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoLibraryStore.preview)
}
