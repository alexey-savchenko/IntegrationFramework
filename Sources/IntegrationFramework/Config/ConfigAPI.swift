import Foundation

/// Internal API definition for configuration endpoints.
///
/// Provides URL request construction with automatic device identification.
enum ConfigAPI {
    /// Fetch configuration endpoint.
    case getConfig
    
    /// Base URL from IntegrationFramework configuration.
    var baseURL: URL {
        return URL(string: IntegrationFramework.shared.baseURL)!
    }
    
    /// API path from IntegrationFramework configuration.
    var path: String {
        return IntegrationFramework.shared.path
    }
    
    /// HTTP method (always GET for config endpoints).
    var method: String {
        return "GET"
    }
    
    /// Constructs a URL request with device parameters.
    ///
    /// Automatically includes:
    /// - `device_id`: Persistent device identifier (UUID)
    /// - `device_type`: Device model identifier
    ///
    /// - Returns: A configured `URLRequest` ready to execute.
    func asURLRequest() -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        let parameters: [String: String] = [
            "device_id": persistentDeviceID,
            "device_type": deviceModel
        ]
        
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        return request
    }
}

/// Extension providing device identification utilities.
extension ConfigAPI {
    /// UserDefaults key for storing the persistent device ID.
    private var deviceIDKey: String {
        "persistent_device_id"
    }
    
    /// Persistent device identifier.
    ///
    /// Generates a UUID on first access and stores it in UserDefaults
    /// for consistent device identification across app launches.
    ///
    /// - Returns: A UUID string unique to this device/installation.
    var persistentDeviceID: String {
        if let existingID = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existingID
        }
        
        // Generate new UUID and persist it
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }
    
    /// Device model identifier.
    ///
    /// Retrieves the hardware model identifier using the `uname` system call.
    ///
    /// - Returns: The device model string (e.g., "iPhone14,2") or "Unknown" if unavailable.
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }
}
