//
// TemporalVisualMemory.swift
// Vision-Hermes - Buffer de memoria visual temporal reciente
//
// Almacena un historial circular de fotogramas clave con timestamp y geolocalización
// para responder a preguntas de memoria visual como "¿Dónde dejé mis llaves?".
//

import Foundation
import UIKit

public struct TemporalSnapshot: Identifiable {
  public let id = UUID()
  public let image: UIImage
  public let timestamp: Date
  public let locationContext: String?
  public let thumbnail: [UInt8]

  public var timeAgoString: String {
    let seconds = Int(-timestamp.timeIntervalSinceNow)
    if seconds < 60 {
      return "hace \(max(1, seconds)) segundos"
    } else if seconds < 3600 {
      let minutes = seconds / 60
      return "hace \(minutes) minuto\(minutes > 1 ? "s" : "")"
    } else {
      let hours = seconds / 3600
      return "hace \(hours) hora\(hours > 1 ? "s" : "")"
    }
  }
}

public final class TemporalVisualMemory {
  public static let shared = TemporalVisualMemory()

  private let lock = NSLock()
  private var ringBuffer: [TemporalSnapshot] = []
  private let maxCapacity: Int = 24
  private var lastRecordedTime: Date = Date.distantPast
  private var lastThumbnail: [UInt8] = []

  private init() {}

  /// Registra un fotograma en la memoria temporal si ha pasado suficiente tiempo o hubo cambio de escena.
  public func recordFrameIfSignificant(_ image: UIImage, locationContext: String? = nil) {
    let now = Date()
    let timeSinceLast = now.timeIntervalSince(lastRecordedTime)

    // Evaluar thumbnail de cambio de escena
    let thumb = FrameChange.grayThumbnail(image)
    let isDifferentScene = lastThumbnail.isEmpty || FrameChange.isNewScene(lastThumbnail, thumb)

    // Guardar si cambió de escena o si pasaron más de 12 segundos desde el último registro
    guard isDifferentScene || timeSinceLast >= 12.0 else { return }

    // Redimensionar imagen para mantener bajo uso de memoria (~400x300 px)
    let targetSize = CGSize(width: 400, height: 300)
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let optimizedImage = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    let snapshot = TemporalSnapshot(
      image: optimizedImage,
      timestamp: now,
      locationContext: locationContext,
      thumbnail: thumb
    )

    lock.lock()
    defer { lock.unlock() }

    ringBuffer.append(snapshot)
    if ringBuffer.count > maxCapacity {
      ringBuffer.removeFirst(ringBuffer.count - maxCapacity)
    }

    lastRecordedTime = now
    lastThumbnail = thumb
  }

  /// Retorna todos los fotogramas en orden cronológico inverso (más reciente primero).
  public func getRecentSnapshots(limit: Int = 10) -> [TemporalSnapshot] {
    lock.lock()
    defer { lock.unlock() }
    return Array(ringBuffer.reversed().prefix(limit))
  }

  /// Retorna el fotograma más reciente almacenado.
  public func mostRecentSnapshot() -> TemporalSnapshot? {
    lock.lock()
    defer { lock.unlock() }
    return ringBuffer.last
  }

  /// Genera un resumen textual de los momentos capturados recientemente para inyectar en el prompt de búsqueda.
  public func buildTimelineContext() -> String {
    lock.lock()
    let snapshots = ringBuffer
    lock.unlock()

    guard !snapshots.isEmpty else {
      return "No hay fotogramas previos registrados en el buffer temporal."
    }

    var lines: [String] = []
    lines.append("Historial de escenas recientes observadas por la cámara:")
    for (idx, snap) in snapshots.enumerated() {
      let loc = snap.locationContext.map { " en \($0)" } ?? ""
      lines.append("- Escena \(idx + 1) (\(snap.timeAgoString)\(loc))")
    }
    return lines.joined(separator: "\n")
  }

  /// Limpia el buffer (por ejemplo al finalizar la sesión).
  public func clear() {
    lock.lock()
    defer { lock.unlock() }
    ringBuffer.removeAll()
    lastRecordedTime = Date.distantPast
    lastThumbnail.removeAll()
  }
}
