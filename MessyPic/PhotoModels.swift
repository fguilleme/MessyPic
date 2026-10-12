import SwiftUI

enum PhotoGroupingOrder: String, CaseIterable, Identifiable {
    case colorThenContent
    case contentThenColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colorThenContent: "Couleur → Contenu"
        case .contentThenColor: "Contenu → Couleur"
        }
    }
}

enum PhotoColorCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case red = "Rouge"
    case orange = "Orange"
    case yellow = "Jaune"
    case green = "Vert"
    case turquoise = "Turquoise"
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
        case .turquoise: Color(red: 0.15, green: 0.65, blue: 0.68)
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
    case starrySky = "Ciel étoilé"
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
        case .starrySky: "sparkles"
        case .transport: "car.fill"
        case .documents: "doc.text.fill"
        case .architecture: "building.2.fill"
        case .objects: "shippingbox.fill"
        case .other: "sparkles"
        }
    }
}

struct PhotoAnalysis: Codable, Hashable, Identifiable, Sendable {
    static let currentAnalysisVersion = 5

    let assetIdentifier: String
    let color: PhotoColorCategory
    let content: PhotoContentCategory
    let label: String
    let confidence: Double
    let creationDate: Date?
    let visionResults: [VisionResult]
    let principalColors: [PrincipalColor]
    let subjectColors: [PrincipalColor]
    let analysisVersion: Int

    var id: String { assetIdentifier }

    init(
        assetIdentifier: String,
        color: PhotoColorCategory,
        content: PhotoContentCategory,
        label: String,
        confidence: Double,
        creationDate: Date?,
        visionResults: [VisionResult] = [],
        principalColors: [PrincipalColor] = [],
        subjectColors: [PrincipalColor] = [],
        analysisVersion: Int = PhotoAnalysis.currentAnalysisVersion
    ) {
        self.assetIdentifier = assetIdentifier
        self.color = color
        self.content = content
        self.label = label
        self.confidence = confidence
        self.creationDate = creationDate
        self.visionResults = visionResults
        self.principalColors = principalColors
        self.subjectColors = subjectColors
        self.analysisVersion = analysisVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetIdentifier = try container.decode(String.self, forKey: .assetIdentifier)
        color = try container.decode(PhotoColorCategory.self, forKey: .color)
        content = try container.decode(PhotoContentCategory.self, forKey: .content)
        label = try container.decode(String.self, forKey: .label)
        confidence = try container.decode(Double.self, forKey: .confidence)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        visionResults = try container.decodeIfPresent([VisionResult].self, forKey: .visionResults) ?? []
        principalColors = try container.decodeIfPresent([PrincipalColor].self, forKey: .principalColors) ?? []
        subjectColors = try container.decodeIfPresent([PrincipalColor].self, forKey: .subjectColors) ?? []
        analysisVersion = try container.decodeIfPresent(Int.self, forKey: .analysisVersion) ?? 1
    }
}

struct AnalysisResult: Sendable {
    let color: PhotoColorCategory
    let content: PhotoContentCategory
    let label: String
    let confidence: Double
    let visionResults: [VisionResult]
    let principalColors: [PrincipalColor]
    let subjectColors: [PrincipalColor]
}

struct VisionResult: Codable, Hashable, Identifiable, Sendable {
    let identifier: String
    let confidence: Double

    var id: String { identifier }
}

struct PrincipalColor: Codable, Hashable, Identifiable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let proportion: Double

    var id: String { "\(red)-\(green)-\(blue)-\(proportion)" }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var hex: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
