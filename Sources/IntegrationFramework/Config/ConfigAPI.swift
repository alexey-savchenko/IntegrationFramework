import Foundation

enum ConfigAPI {
    case getConfig
    
    var baseURL: URL {
        return URL(string: IntegrationFramework.shared.baseURL)!
    }
    
    var path: String {
        return IntegrationFramework.shared.path
    }
    
    var method: String {
        return "GET"
    }
    
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

extension ConfigAPI {
    private var deviceIDKey: String {
        "persistent_device_id"
    }
    
    var persistentDeviceID: String {
        if let existingID = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existingID
        }
        
        // Generate new UUID and persist it
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }
    
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
