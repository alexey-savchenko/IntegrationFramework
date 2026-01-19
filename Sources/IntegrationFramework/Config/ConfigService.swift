import Foundation

public protocol ConfigServiceProtocol: Sendable {
    func fetchConfig(completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    func getConfig() -> ConfigResponse?
}
    
final class ConfigService: ConfigServiceProtocol, @unchecked Sendable {
    static let shared = ConfigService()
    
    private init() {}
    
    let session = URLSession.shared
    let configFileName = "config.json"
    
    // In-memory storage for faster access
    private var cachedConfigResponse: ConfigResponse?
    
    private var configFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(configFileName)
    }
    
    func fetchConfig(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let request = ConfigAPI.getConfig.asURLRequest()
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to fetch config: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "ConfigService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            do {
                if let json = data.prettyPrintedJSONString {
                    print("✅ Fetched config: \(json)")
                }
                
                let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
                // Store in memory
                self.cachedConfigResponse = config
                
                // Save to disk
                self.saveConfigToDisk(config)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func getConfig() -> ConfigResponse? {
        // First check in-memory cache for fastest access
        if let memoryConfig = cachedConfigResponse {
            return memoryConfig
        }
        
        // Fallback to disk cache
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configFileURL)
            let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
            // Store in memory for next time
            cachedConfigResponse = config
            return config
        } catch {
            print("❌ Failed to load cached config: \(error)")
            return nil
        }
    }
    
    private func saveConfigToDisk(_ config: ConfigResponse) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configFileURL)
            print("✅ Config saved to disk")
        } catch {
            print("❌ Failed to save config to disk: \(error)")
        }
    }
}
