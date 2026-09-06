//
// FrameChange.swift
// Vision-Hermes - Scene-Gating & Thumbnail Difference Detection
// Adapted from OpenVision for Vision-Hermes
//

import Foundation
import UIKit
import CoreGraphics

enum FrameChange {
    /// 16x16 thumbnail dimension (256 bytes total)
    static let thumbnailSide = 16
    static let thumbnailByteCount = thumbnailSide * thumbnailSide

    /// Downscale to a 16×16 grayscale thumbnail for the scene-change gate.
    /// Extremely cheap (<0.1ms) to run on video frames.
    static func grayThumbnail(_ image: UIImage) -> [UInt8] {
        let side = thumbnailSide
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let cg = image.cgImage else { return pixels }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.interpolationQuality = .low
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return pixels
    }

    /// Mean absolute difference between two equal-length grayscale thumbnails, normalized to 0…1.
    static func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 1.0 }
        var total = 0
        for i in 0..<a.count {
            total += abs(Int(a[i]) - Int(b[i]))
        }
        return Double(total) / (255.0 * Double(a.count))
    }

    /// Scene-change threshold on `difference`.
    /// 0.12 accounts for normal worn glasses head micro-jitter (~0.04-0.08) while reliably
    /// detecting a head turn or change of subject (>0.15).
    static let sceneChangeThreshold = 0.12

    /// Returns true if the two thumbnails represent distinct scenes.
    static func isNewScene(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        difference(a, b) > sceneChangeThreshold
    }

    /// Word-overlap similarity between two descriptions, 0…1 (Jaccard over lowercased words).
    static func similarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
        let wordsB = Set(b.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
        guard !wordsA.isEmpty || !wordsB.isEmpty else { return 1.0 }
        let union = wordsA.union(wordsB)
        guard !union.isEmpty else { return 1.0 }
        return Double(wordsA.intersection(wordsB).count) / Double(union.count)
    }

    /// Decides if a new description adds meaningful information beyond the last spoken one.
    static let spokenSimilarityThreshold = 0.5

    static func isWorthSpeaking(_ new: String, lastSpoken: String?) -> Bool {
        guard let lastSpoken, !lastSpoken.isEmpty else { return true }
        return similarity(new, lastSpoken) < spokenSimilarityThreshold
    }
}
