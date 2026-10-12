import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum PhotoAnalyzer {
    nonisolated static func analyze(_ cgImage: CGImage) -> AnalysisResult {
        let principalColors = principalColors(in: cgImage)
        let color = dominantColor(in: cgImage, principalColors: principalColors)
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
        let visionResults = observations.prefix(8).map {
            VisionResult(
                identifier: $0.identifier,
                confidence: Double($0.confidence)
            )
        }

        return AnalysisResult(
            color: color,
            content: category,
            label: label,
            confidence: Double(best?.confidence ?? 0),
            visionResults: visionResults,
            principalColors: principalColors
        )
    }

    nonisolated private static func principalColors(
        in image: CGImage,
        maximumCount: Int = 5
    ) -> [PrincipalColor] {
        let width = 28
        let height = 28
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let samples: [(Double, Double, Double)] = stride(from: 0, to: pixels.count, by: 4).compactMap { index in
            guard pixels[index + 3] > 127 else { return nil }
            return (
                Double(pixels[index]) / 255,
                Double(pixels[index + 1]) / 255,
                Double(pixels[index + 2]) / 255
            )
        }
        guard !samples.isEmpty else { return [] }

        var buckets: [Int: (red: Double, green: Double, blue: Double, count: Int)] = [:]
        for sample in samples {
            let redBin = min(Int(sample.0 * 5), 4)
            let greenBin = min(Int(sample.1 * 5), 4)
            let blueBin = min(Int(sample.2 * 5), 4)
            let key = redBin * 25 + greenBin * 5 + blueBin
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.red += sample.0
            bucket.green += sample.1
            bucket.blue += sample.2
            bucket.count += 1
            buckets[key] = bucket
        }

        let candidates = buckets.values.map { bucket in
            (
                red: bucket.red / Double(bucket.count),
                green: bucket.green / Double(bucket.count),
                blue: bucket.blue / Double(bucket.count),
                count: bucket.count
            )
        }
        guard let first = candidates.max(by: { $0.count < $1.count }) else { return [] }

        var centers = [(first.red, first.green, first.blue)]
        while centers.count < min(maximumCount, candidates.count) {
            guard let next = candidates.max(by: { lhs, rhs in
                weightedDistance(of: lhs, from: centers) < weightedDistance(of: rhs, from: centers)
            }) else { break }
            centers.append((next.red, next.green, next.blue))
        }

        var clusterCounts = [Int](repeating: 0, count: centers.count)
        for _ in 0..<7 {
            var totals = [(red: Double, green: Double, blue: Double, count: Int)](
                repeating: (0, 0, 0, 0),
                count: centers.count
            )
            for sample in samples {
                let index = closestCenter(to: sample, centers: centers)
                totals[index].red += sample.0
                totals[index].green += sample.1
                totals[index].blue += sample.2
                totals[index].count += 1
            }
            clusterCounts = totals.map(\.count)
            for index in centers.indices where totals[index].count > 0 {
                centers[index] = (
                    totals[index].red / Double(totals[index].count),
                    totals[index].green / Double(totals[index].count),
                    totals[index].blue / Double(totals[index].count)
                )
            }
        }

        return centers.indices
            .filter { clusterCounts[$0] > 0 }
            .map { index in
                PrincipalColor(
                    red: centers[index].0,
                    green: centers[index].1,
                    blue: centers[index].2,
                    proportion: Double(clusterCounts[index]) / Double(samples.count)
                )
            }
            .sorted { $0.proportion > $1.proportion }
    }

    nonisolated private static func weightedDistance(
        of candidate: (red: Double, green: Double, blue: Double, count: Int),
        from centers: [(Double, Double, Double)]
    ) -> Double {
        centers.map { center in
            squaredDistance(
                (candidate.red, candidate.green, candidate.blue),
                center
            )
        }.min()! * Double(candidate.count)
    }

    nonisolated private static func closestCenter(
        to sample: (Double, Double, Double),
        centers: [(Double, Double, Double)]
    ) -> Int {
        centers.indices.min {
            squaredDistance(sample, centers[$0]) < squaredDistance(sample, centers[$1])
        } ?? 0
    }

    nonisolated private static func squaredDistance(
        _ lhs: (Double, Double, Double),
        _ rhs: (Double, Double, Double)
    ) -> Double {
        let red = lhs.0 - rhs.0
        let green = lhs.1 - rhs.1
        let blue = lhs.2 - rhs.2
        return red * red + green * green + blue * blue
    }

    nonisolated private static func dominantColor(
        in image: CGImage,
        principalColors: [PrincipalColor]
    ) -> PhotoColorCategory {
        if !principalColors.isEmpty {
            var scores: [PhotoColorCategory: Double] = [:]
            for sample in principalColors {
                let category = colorCategory(
                    red: sample.red,
                    green: sample.green,
                    blue: sample.blue
                )
                scores[category, default: 0] += sample.proportion
            }

            if let strongest = PhotoColorCategory.allCases.max(by: {
                scores[$0, default: 0] < scores[$1, default: 0]
            }), scores[strongest, default: 0] > 0 {
                return strongest
            }
        }

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

        let red = Double(rgba[0]) / 255
        let green = Double(rgba[1]) / 255
        let blue = Double(rgba[2]) / 255
        return colorCategory(red: red, green: green, blue: blue)
    }

    nonisolated private static func colorCategory(
        red: Double,
        green: Double,
        blue: Double
    ) -> PhotoColorCategory {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        if luminance < 0.16 { return .black }
        if saturation < 0.2, luminance > 0.72 { return .white }

        var hue: Double
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

        let isDarkOrangeBrown = hue >= 15 && hue < 50 && maximum < 0.72
        let isMutedRedBrown = (hue < 15 || hue >= 345) && maximum < 0.72 && saturation < 0.55
        if isDarkOrangeBrown || isMutedRedBrown { return .brown }
        if saturation < 0.18 { return .gray }

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
