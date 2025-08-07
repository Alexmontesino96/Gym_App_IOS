import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    @Published var currentLocationStatus: LocationStatus = .unknown
    @Published var isNearGym = false
    @Published var distanceToGym: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
    // Coordenadas del gimnasio (ejemplo - Madrid)
    private let gymLocation = CLLocation(latitude: 40.4168, longitude: -3.7038)
    private let gymProximityRadius: Double = 500 // 500 metros
    
    enum LocationStatus {
        case unknown
        case authorized
        case denied
        case nearGym
        case farFromGym
        case restricted
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        print("📍 LocationService initialized")
    }
    
    func requestLocationPermission() {
        print("📍 Requesting location permission...")
        errorMessage = nil
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location not authorized")
            errorMessage = "Location access not authorized"
            return
        }
        
        print("📍 Starting location updates...")
        errorMessage = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        print("📍 Stopping location updates...")
        locationManager.stopUpdatingLocation()
    }
    
    private func updateLocationStatus() {
        guard let location = currentLocation else { return }
        
        distanceToGym = location.distance(from: gymLocation)
        isNearGym = distanceToGym <= gymProximityRadius
        
        currentLocationStatus = isNearGym ? .nearGym : .farFromGym
        
        print("📍 Distance to gym: \(Int(distanceToGym))m, Near gym: \(isNearGym)")
    }
    
    // Public methods for manual testing
    func simulateNearGym() {
        print("🧪 Simulating near gym location")
        distanceToGym = 100
        isNearGym = true
        currentLocationStatus = .nearGym
    }
    
    func simulateFarFromGym() {
        print("🧪 Simulating far from gym location")
        distanceToGym = 2000
        isNearGym = false
        currentLocationStatus = .farFromGym
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location
            updateLocationStatus()
            
            print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        Task { @MainActor in
            currentLocationStatus = .unknown
            errorMessage = "Unable to get location: \(error.localizedDescription)"
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Authorization status changed: \(status.debugDescription)")
        
        Task { @MainActor in
            authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                currentLocationStatus = .authorized
                errorMessage = nil
                startLocationUpdates()
            case .denied:
                currentLocationStatus = .denied
                errorMessage = "Location access denied. Enable in Settings to see location-based actions."
                stopLocationUpdates()
            case .restricted:
                currentLocationStatus = .restricted
                errorMessage = "Location access restricted"
                stopLocationUpdates()
            case .notDetermined:
                currentLocationStatus = .unknown
                errorMessage = nil
            @unknown default:
                currentLocationStatus = .unknown
                errorMessage = "Unknown location authorization status"
            }
        }
    }
}

// MARK: - Extensions

extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
}