import CoreGraphics
import Foundation
import ImageIO

// Run with swiftc alongside PhotoModels.swift and PhotoAnalyzer.swift on macOS.
@main
@MainActor
struct PhotoAnalyzerChecks {
    static func image(width: Int = 160, height: Int = 240, mask: Bool = false) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        )!
        context.setFillColor(mask ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(mask ? CGColor(gray: 1, alpha: 1) : CGColor(red: 0.2, green: 0.65, blue: 0.68, alpha: 1))
        context.fill(CGRect(x: width / 8, y: height / 12, width: width / 3, height: height * 3 / 4))
        return context.makeImage()!
    }

    static func checkMask(width: Int, height: Int) {
        let photo = image(width: width, height: height)
        let global = PhotoAnalyzer.principalColors(in: photo)
        let subject = PhotoAnalyzer.principalColors(in: photo, subjectMask: image(width: width, height: height, mask: true))
        precondition(PhotoAnalyzer.dominantColor(in: photo, principalColors: global) == .gray)
        precondition(!subject.isEmpty)
        precondition(PhotoAnalyzer.dominantColor(in: photo, principalColors: subject) == .turquoise)
        precondition(abs(subject.reduce(0) { $0 + $1.proportion } - 1) < 0.000001)
        precondition(subject.allSatisfy { $0.green > 0.6 && $0.blue > 0.6 })

        let emptyMask = CGImage(
            width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: 1, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
            provider: CGDataProvider(data: Data([0]) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )!
        precondition(PhotoAnalyzer.principalColors(in: photo, subjectMask: emptyMask).isEmpty)
        let fullMask = CGImage(
            width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: 1, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
            provider: CGDataProvider(data: Data([255]) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )!
        precondition(PhotoAnalyzer.principalColors(in: photo, subjectMask: fullMask).isEmpty)
    }

    static func main() throws {
        checkMask(width: 160, height: 240)
        checkMask(width: 240, height: 160)
        let night = [
            VisionResult(identifier: "outdoor", confidence: 0.63),
            VisionResult(identifier: "sky", confidence: 0.63),
            VisionResult(identifier: "night_sky", confidence: 0.63),
            VisionResult(identifier: "document", confidence: 0.29),
            VisionResult(identifier: "screenshot", confidence: 0.29),
            VisionResult(identifier: "celestial_body", confidence: 0.11)
        ]
        precondition(PhotoAnalyzer.contentCategory(from: night) == .starrySky)
        precondition(PhotoAnalyzer.contentCategory(from: [VisionResult(identifier: "blue_sky", confidence: 0.9)]) == .nature)
        precondition(PhotoAnalyzer.contentCategory(from: [VisionResult(identifier: "starfish", confidence: 0.9)]) == .animals)
        precondition(PhotoAnalyzer.contentCategory(from: [VisionResult(identifier: "sky", confidence: 0.9), VisionResult(identifier: "night_sky", confidence: 0.1)]) == .nature)

        let oldCache = Data(#"{"assetIdentifier":"old","color":"Gris","content":"Personnes","label":"People","confidence":0.8,"principalColors":[],"analysisVersion":3}"#.utf8)
        let old = try JSONDecoder().decode(PhotoAnalysis.self, from: oldCache)
        precondition(old.subjectColors.isEmpty && old.analysisVersion < PhotoAnalysis.currentAnalysisVersion)
        let updated = PhotoAnalysis(
            assetIdentifier: "new", color: .turquoise, content: .starrySky,
            label: "Night Sky", confidence: 0.9, creationDate: nil,
            principalColors: PhotoAnalyzer.principalColors(in: image()),
            subjectColors: PhotoAnalyzer.principalColors(in: image(), subjectMask: image(mask: true))
        )
        let restored = try JSONDecoder().decode(PhotoAnalysis.self, from: JSONEncoder().encode(updated))
        precondition(restored == updated)
        print("PASS: subject masks in both orientations, global fallback, turquoise, sky classification, cache migration and round trip")

        if let path = CommandLine.arguments.dropFirst().first {
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
            let screenshot = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            let photo = screenshot.cropping(to: CGRect(x: 0, y: 170, width: screenshot.width, height: 1070))!
            let result = PhotoAnalyzer.analyze(photo)
            print("Real photo: \(result.color.rawValue), \(result.content.rawValue), subject clusters: \(result.subjectColors.count)")
            print("Global: \(result.principalColors.map { "\($0.hex) \(Int($0.proportion * 100))%" })")
            print("Subject: \(result.subjectColors.map { "\($0.hex) \(Int($0.proportion * 100))%" })")
            precondition(result.color == .turquoise && !result.subjectColors.isEmpty)
        }
    }
}
