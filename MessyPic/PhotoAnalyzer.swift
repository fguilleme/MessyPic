import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum PhotoAnalyzer {
    nonisolated static func analyze(_ cgImage: CGImage) -> AnalysisResult {
        let color = dominantColor(in: cgImage)
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])

        let observations = (request.results ?? [])
            .filter { $0.confidence >= 0.08 }

        let category = contentCategory(from: observations)
        let best = observations.first
        let label = best?
            .identifier
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized ?? category.rawValue

        return AnalysisResult(
            color: color,
            content: category,
            label: label,
            confidence: Double(best?.confidence ?? 0)
        )
    }

    nonisolated private static func dominantColor(in image: CGImage) -> PhotoColorCategory {
        let input = CIImage(cgImage: image)
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent

        guard let output = filter.outputImage else { return .gray }

        var rgba = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let red = CGFloat(rgba[0]) / 255
        let green = CGFloat(rgba[1]) / 255
        let blue = CGFloat(rgba[2]) / 255
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum

        if maximum < 0.2 { return .black }
        if saturation < 0.12, maximum > 0.82 { return .white }
        if saturation < 0.18 { return .gray }

        var hue: CGFloat
        if delta == 0 {
            hue = 0
        } else if maximum == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            hue = 60 * (((blue - red) / delta) + 2)
        } else {
            hue = 60 * (((red - green) / delta) + 4)
        }
        if hue < 0 { hue += 360 }

        if hue >= 15, hue < 50, maximum < 0.62 { return .brown }
        switch hue {
        case 0..<15, 345..<360: return .red
        case 15..<45: return .orange
        case 45..<70: return .yellow
        case 70..<165: return .green
        case 165..<255: return .blue
        case 255..<295: return .purple
        default: return .pink
        }
    }

    nonisolated private static func contentCategory(
        from observations: [VNClassificationObservation]
    ) -> PhotoContentCategory {
        let rules: [(PhotoContentCategory, [String])] = [
            (.people, ["person", "people", "human", "face", "portrait", "selfie", "baby", "child", "boy", "girl", "man", "woman", "bride", "groom"]),
            (.animals, ["animal", "dog", "cat", "bird", "horse", "fish", "insect", "wildlife", "mammal", "pet"]),
            (.food, ["food", "dish", "meal", "fruit", "vegetable", "dessert", "cake", "bread", "drink", "restaurant", "plate"]),
            (.nature, ["landscape", "nature", "mountain", "forest", "tree", "flower", "plant", "beach", "ocean", "sea", "lake", "river", "sky", "sunset", "garden"]),
            (.transport, ["vehicle", "car", "truck", "bus", "train", "aircraft", "airplane", "boat", "ship", "bicycle", "motorcycle"]),
            (.documents, ["document", "text", "screen", "monitor", "book", "newspaper", "menu", "receipt", "sign", "envelope"]),
            (.architecture, ["building", "architecture", "house", "home", "room", "church", "castle", "bridge", "street", "city"])
        ]

        for observation in observations.prefix(12) {
            let identifier = observation.identifier.lowercased()
            for (category, keywords) in rules where keywords.contains(where: identifier.contains) {
                return category
            }
        }

        guard let top = observations.first else { return .other }
        return top.confidence >= 0.2 ? .objects : .other
    }
}
