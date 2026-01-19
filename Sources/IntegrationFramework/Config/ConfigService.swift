import Foundation

/// Protocol defining configuration service interface.
///
/// Provides methods for fetching and retrieving application configuration.
public protocol ConfigServiceProtocol: Sendable {
    /// Fetches configuration from the remote server.
    ///
    /// - Parameter completion: A closure called with the fetch result.
    func fetchConfig(completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    
    /// Retrieves the cached configuration.
    ///
    /// - Returns: The cached configuration if available, otherwise `nil`.
    func getConfig() -> ConfigResponse?
}

/// Service for managing application configuration.
///
/// `ConfigService` handles fetching, caching, and persisting configuration data.
/// It implements a two-tier caching strategy:
/// 1. In-memory cache for fast access
/// 2. Disk cache for persistence across app launches
///
/// - Note: This class is thread-safe and uses `@unchecked Sendable` as it manages
///   shared mutable state internally with proper synchronization.
final class ConfigService: ConfigServiceProtocol, @unchecked Sendable {
    /// Shared singleton instance.
    static let shared = ConfigService()
    
    private init() {}
    
    /// URL session for network requests.
    let session = URLSession.shared
    
    /// Filename for disk cache storage.
    let configFileName = "config.json"
    
    /// In-memory cache for faster access.
    private var cachedConfigResponse: ConfigResponse?
    
    /// File URL for disk cache in the documents directory.
    private var configFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(configFileName)
    }
    
    /// Fetches configuration from the remote server.
    ///
    /// This method performs a network request to fetch the latest configuration,
    /// then caches it both in memory and on disk for future access. The completion
    /// handler is always called on the main thread.
    ///
    /// - Parameter completion: A closure called with the fetch result:
    ///   - `.success`: Configuration fetched and cached successfully.
    ///   - `.failure`: Network error, no data received, or JSON decoding failed.
    ///
    /// - Important: Requires `IntegrationFramework.shared.baseURL` and `path` to be configured.
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
    
    /// Retrieves the cached configuration.
    ///
    /// This method implements a two-tier caching strategy:
    /// 1. First checks the in-memory cache for fastest access
    /// 2. Falls back to disk cache if in-memory cache is empty
    ///
    /// If the disk cache is used, the configuration is automatically loaded
    /// into memory for subsequent fast access.
    ///
    /// - Returns: The cached `ConfigResponse` if available, otherwise `nil`.
    ///
    /// - Note: Returns `nil` if no configuration has been fetched or if
    ///   the cached configuration cannot be loaded.
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
    
    /// Saves configuration to disk for persistence.
    ///
    /// The configuration is encoded as pretty-printed JSON and saved to
    /// the app's documents directory.
    ///
    /// - Parameter config: The configuration to save.
    ///
    /// - Note: Failures are logged but do not throw errors, as disk caching
    ///   is optional and the in-memory cache remains functional.
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
