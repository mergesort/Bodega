import Foundation

public actor ObjectStorage {

    private let storage: DiskStorage

    /// Initializes a new ObjectStorage object for persisting Objects to disk.
    /// - Parameter storagePath: A URL representing the folder on disk that your files will be written to.
    /// Constructed as a URL for those that wish to use features like shared containers,
    /// rather than as traditionally in the Documents or Caches directory.
    public init(storagePath: URL) {
        self.storage = DiskStorage(storagePath: storagePath)
    }

    /// Writes a `Codable` Object to disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - object: The object being stored to disk.
    ///   - key: key A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can write to.
    public func store<Object: Codable & Sendable>(_ object: Object, forKey key: CacheKey, subdirectory: String? = nil) async throws {
        let data = try JSONEncoder().encode(object)

        return try await storage.write(data, key: key, subdirectory: subdirectory)
    }

    /// Reads a `Codable` object from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The an object stored on disk if it exists, nil if there is no data stored behind the `CacheKey`.
    public func object<Object: Codable & Sendable>(forKey key: CacheKey, subdirectory: String? = nil) async -> Object? {
        guard let data = await storage.read(key: key, subdirectory: subdirectory) else { return nil }

        return try? JSONDecoder().decode(Object.self, from: data)
    }

    /// Removes an object from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can remove a file from.
    public func removeObject(forKey key: CacheKey, subdirectory: String? = nil) async throws {
        try await storage.remove(key: key, subdirectory: subdirectory)
    }

    /// Removes all the objects located at the `storagePath` or it's `subdirectory`.
    /// - Parameter subdirectory: An optional subdirectory the caller can remove a file from.
    public func removeAllObjects(inSubdirectory subdirectory: String? = nil) async throws {
        try await storage.removeAllData(inSubdirectory: subdirectory)
    }

    /// Iterates through a directory to find all of the files and their respective keys.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys(inSubdirectory subdirectory: String? = nil) async -> [CacheKey] {
        return await storage.allKeys(inSubdirectory: subdirectory)
    }

    /// Iterates through a directory to find the total number of files.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: The file/key count.
    public func keyCount(inSubdirectory subdirectory: String? = nil) async -> Int {
        return await storage.keyCount(inSubdirectory: subdirectory)
    }

}
