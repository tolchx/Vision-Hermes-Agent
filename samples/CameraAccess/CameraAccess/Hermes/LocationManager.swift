import CoreLocation
import Foundation

/// Singleton manager for transparently providing GPS coordinates and geocoded city/neighborhood context
/// to Gemini Live and Hermes agent tools.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  static let shared = LocationManager()

  private let manager = CLLocationManager()
  private let geocoder = CLGeocoder()

  @Published var location: CLLocation?
  @Published var placemark: CLPlacemark?
  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

  override private init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    authorizationStatus = manager.authorizationStatus
  }

  func requestLocation() {
    let status = manager.authorizationStatus
    if status == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else if status == .authorizedWhenInUse || status == .authorizedAlways {
      manager.requestLocation()
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    self.authorizationStatus = manager.authorizationStatus
    if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
      manager.requestLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    self.location = loc

    geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
      guard let self else { return }
      DispatchQueue.main.async {
        self.placemark = placemarks?.first
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    NSLog("[LocationManager] Failed to get location: %@", error.localizedDescription)
  }

  // MARK: - Context String for AI & Hermes

  var contextString: String? {
    guard let loc = location else { return nil }

    var str = String(format: "Ubicación GPS: Lat %.4f, Lon %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
    if let place = placemark {
      var parts: [String] = []
      if let hood = place.subLocality, !hood.isEmpty { parts.append(hood) }
      if let city = place.locality, !city.isEmpty { parts.append(city) }
      if let state = place.administrativeArea, !state.isEmpty { parts.append(state) }
      if let country = place.country, !country.isEmpty { parts.append(country) }
      if !parts.isEmpty {
        str += " (\(parts.joined(separator: ", ")))"
      }
    }
    return str
  }

  var shortLocationName: String? {
    if let place = placemark {
      let city = place.locality ?? ""
      let hood = place.subLocality ?? ""
      if !hood.isEmpty && !city.isEmpty { return "\(hood), \(city)" }
      if !city.isEmpty { return city }
    }
    return nil
  }
}
