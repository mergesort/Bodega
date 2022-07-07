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
    ///   - key: key A `CacheKey` for matching `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can write to.
    public func store<Object: Codable>(_ object: Object, forKey key: CacheKey, subdirectory: String? = nil) async throws {
        let data = try JSONEncoder().encode(object)

        return try await storage.write(data, key: key, subdirectory: subdirectory)
    }

    /// Reads a `Codable` object from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching an `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The object stored on disk if it exists, nil if there is no `Object` stored for the `CacheKey`.
    public func object<Object: Codable>(forKey key: CacheKey, subdirectory: String? = nil) async -> Object? {
        guard let data = await storage.read(key: key, subdirectory: subdirectory) else { return nil }

        return try? JSONDecoder().decode(Object.self, from: data)
    }

    /// Reads `Codable` objects from disk based on associated array of `CacheKey`s provided as a parameter.
    /// - Parameters:
    ///   - keys: A [CacheKey] for matching multiple `Codable` objects to their a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: An array of `[Object]`s stored on disk if the `CacheKey`s exist,
    /// and an `[]` if there are no `Object`s matching the `keys` passed in.
    public func objects<Object: Codable>(forKeys keys: [CacheKey], subdirectory: String? = nil) async -> [Object] {
        let dataItems = await storage.read(keys: keys, subdirectory: subdirectory)
        let decoder = JSONDecoder()

        do {
            return try dataItems.map({ try decoder.decode(Object.self, from: $0) })
        } catch {
            return []
        }
    }

    /// Reads `Object`s from disk based on associated array of `CacheKey`s provided as a parameter
    /// and returns an array of a tuple of the `CacheKey` and `Object` associated with the passed in `CacheKey`s.
    ///
    /// This method returns the `CacheKey` and `Object` together in a tuple of `(CacheKey, Object)`
    /// allowing you to know which `CacheKey` led to a specific `Object` being retrieved.
    /// This can be useful in allowing manual iteration over `Object`s, but if you don't need to know
    /// which `CacheKey` that led to an `Object` being retrieved
    /// you can use ``objects(forKeys:subdirectory:)`` instead.
    /// - Parameters:
    ///   - keys: A [CacheKey] for matching multiple `Object`s to their a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: An array of `[(CacheKey, Object)]` read from disk if it exists,
    /// and an empty array if there are no `Objects`s matching the `keys` passed in.
    public func objectsAndKeys<Object: Codable>(keys: [CacheKey], subdirectory: String? = nil) async -> [(CacheKey, Object)] {
        return zip(
            keys,
            await self.objects(forKeys: keys, subdirectory: subdirectory)
        ).map { ($0, $1) }
    }

    /// Reads all `Codable` objects located at the `storagePath` or it's `subdirectory`.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of `[Object]`s contained in a directory.
    public func allObjects<Object: Codable>(inSubdirectory subdirectory: String? = nil) async -> [Object] {
        let allKeys = await self.allKeys(inSubdirectory: subdirectory)
        return await self.objects(forKeys: allKeys, subdirectory: subdirectory)
    }

    /// Reads all the `Object`s located at the `storagePath` or it's `subdirectory` and returns an array
    /// of a tuple of the `CacheKey` and `Object` associated with the `CacheKey`.
    ///
    /// This method returns the `CacheKey` and `Object` together in a tuple of `(CacheKey, Object)`
    /// allowing you to know which `CacheKey` led to a specific `Object` being retrieved.
    /// This can be useful in allowing manual iteration over `Object`s, but if you
    /// don't need to know which `CacheKey` led to an `Object` being retrieved
    /// you can use ``readAllObjects(inSubdirectory:)`` instead.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of `Object`s and it's associated `CacheKey`s contained in a directory.
    public func allObjectsAndKeys<Object: Codable>(inSubdirectory subdirectory: String? = nil) async -> [(CacheKey, Object)] {
        let allKeys = await self.allKeys(inSubdirectory: subdirectory)
        return await self.objectsAndKeys(keys: allKeys)
    }

    /// Removes an object from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can remove a file from.
    public func removeObject(forKey key: CacheKey, subdirectory: String? = nil) async throws {
        try await storage.remove(key: key, subdirectory: subdirectory)
    }

    /// Removes all the objects located at the `storagePath` or it's `subdirectory`.
    /// - Parameter subdirectory: An optional subdirectory the caller can remove a file from.
    public func removeAllObjects(inSubdirectory subdirectory: String? = nil) async throws {
        try await storage.removeAllData(inSubdirectory: subdirectory)
    }

    /// Iterates through a directory to find the total number of files.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: The file/key count.
    public func keyCount(inSubdirectory subdirectory: String? = nil) async -> Int {
        return await storage.keyCount(inSubdirectory: subdirectory)
    }

    /// Iterates through a directory to find all of the files and their respective keys.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys(inSubdirectory subdirectory: String? = nil) async -> [CacheKey] {
        return await storage.allKeys(inSubdirectory: subdirectory)
    }

    /// Returns the date of creation for the object represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching an `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The last access date of the `Object` on disk if it exists, nil if there is no `Object` stored for the `CacheKey`.
    public func creationDate(forKey key: CacheKey, subdirectory: String? = nil) async -> Date? {
        return await storage.createdAt(key: key, subdirectory: subdirectory)
    }

    /// Returns the last access date of the object for the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching an `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The last access date of the object on disk if it exists, nil if there is no object stored for the `CacheKey`.
    public func lastAccessed(forKey key: CacheKey, subdirectory: String? = nil) async -> Date? {
        return await storage.lastAccessed(key: key, subdirectory: subdirectory)
    }

    /// Returns the modification date for the object represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching an `Object` to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The modification date of the object on disk if it exists, nil if there is no object stored for the `CacheKey`.
    public func lastModified(forKey key: CacheKey, subdirectory: String? = nil) async -> Date? {
        return await storage.lastModified(key: key, subdirectory: subdirectory)
    }

}
