import SwiftUI

enum PhotoColorCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case red = "Rouge"
    case orange = "Orange"
    case yellow = "Jaune"
    case green = "Vert"
    case blue = "Bleu"
    case purple = "Violet"
    case pink = "Rose"
    case brown = "Brun"
    case white = "Clair"
    case gray = "Gris"
    case black = "Sombre"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .brown: Color(red: 0.48, green: 0.29, blue: 0.17)
        case .white: Color(white: 0.9)
        case .gray: .gray
        case .black: Color(white: 0.12)
        }
    }
}

enum PhotoContentCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case people = "Personnes"
    case animals = "Animaux"
    case food = "Nourriture"
    case nature = "Nature"
    case transport = "Transport"
    case documents = "Documents"
    case architecture = "Architecture"
    case objects = "Objets"
    case other = "Autres"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .people: "person.2.fill"
        case .animals: "pawprint.fill"
        case .food: "fork.knife"
        case .nature: "leaf.fill"
        case .transport: "car.fill"
        case .documents: "doc.text.fill"
        case .architecture: "building.2.fill"
        case .objects: "shippingbox.fill"
        case .other: "sparkles"
        }
    }
}

struct PhotoAnalysis: Codable, Hashable, Identifiable, Sendable {
    let assetIdentifier: String
    let color: PhotoColorCategory
    let content: PhotoContentCategory
    let label: String
    let confidence: Double
    let creationDate: Date?

    var id: String { assetIdentifier }
}

struct AnalysisResult: Sendable {
    let color: PhotoColorCategory
    let content: PhotoContentCategory
    let label: String
    let confidence: Double
}
