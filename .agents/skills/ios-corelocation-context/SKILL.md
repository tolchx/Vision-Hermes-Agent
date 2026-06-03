---
description: How to transparently inject the user's CoreLocation GPS coordinates and geocoded city name into an AI LLM prompt stream.
---
# Contextual GPS Location on iOS

When users interact with "smart" AR glasses or mobile voice assistants outside, the AI often lacks critical spatial context. If the user says "What's the rating of the restaurant across the street?", a standard LLM will reply "Which restaurant?".

To make the AI feel truly spatially aware, the app must continuously query Apple's `CoreLocation` framework and inject the resulting data into the backend prompt silently.

## 1. Requesting `NSLocationWhenInUseUsageDescription`

Update the `Info.plist` to explain to the user why the app needs GPS data.

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to provide the AI with context about the places and businesses around you.</string>
```

## 2. Location Manager Manager Singleton

Create a wrapper around `CLLocationManager` to handle the heavy lifting of fetching coordinates and reverse-geocoding them into human-readable city and neighborhood names.

```swift
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var error: Error?

    override init() {
        super.init()
        manager.delegate = self
        // Balance battery life vs. accuracy
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters 
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    // CoreLocation delegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        // Reverse geocode to get city name
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                self.error = error
            } else {
                self.placemark = placemarks?.first
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
        print("Location update failed: \(error)")
    }
}
```

## 3. Formatting the Context String

The AI needs to understand the raw data. Best practice is to provide exact Latitude/Longitude for mapping API tools, alongside the human-readable neighborhood/city for conversational context.

```swift
extension LocationManager {
    var contextString: String? {
        guard let loc = location else { return nil }
        
        var str = "Current Location: Latitude \(loc.coordinate.latitude), Longitude \(loc.coordinate.longitude)."
        
        if let place = placemark {
            let city = place.locality ?? ""
            let neighborhood = place.subLocality ?? ""
            let country = place.country ?? ""
            
            str += " "
            if !neighborhood.isEmpty { str += "Neighborhood: \(neighborhood). " }
            if !city.isEmpty { str += "City: \(city), \(country)." }
        }
        
        return str
    }
}
```

## 4. Injecting into the AI Stream

When the user triggers a wake-word or sends a command, quickly prepend the `contextString` to the system prompt or user payload. The AI should be instructed *not* to mention the GPS coordinates unless specifically asked, simulating natural spatial awareness.

```swift
let userCommand = "What is the name of this park?"
var systemInjection = "You are a helpful AI assistant."

if let locationContext = LocationManager.shared.contextString {
    systemInjection += "\n\nCRITICAL CONTEXT: \(locationContext)\n"
    systemInjection += "Do not mention the user's coordinates unless asked. Use their location implicitly if they ask about nearby places."
}

// Send systemInjection + userCommand to OpenAI, Gemini, etc.
```
