import SwiftUI

@main struct MyApp: App {
    @StateObject private var photoLibrary = PhotoLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoLibrary)
        }
    }
}
