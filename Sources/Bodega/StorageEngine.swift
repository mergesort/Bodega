import Foundation

/// A ``StorageEngine`` represents a data storage mechanism for saving and persisting data.
///
/// A ``StorageEngine`` is a construct you can build that plugs into ``ObjectStorage``
/// to use for persisting data.
///
/// This library has two implementations of ``StorageEngine``, ``DiskStorageEngine`` and ``SQLiteStorageEngine``.
/// Both of these can serve as inspiration if you have your own persistence mechanism (such as Realm, CoreData, etc).
///
/// ``DiskStorageEngine`` takes `Data` and saves it to disk using file system operations.
/// ``SQLiteStorageEngine`` takes `Data` and saves it to an SQLite database under the hood.
///
/// If you have your own way of storing data then you can refer to ``DiskStorageEngine`` and ``SQLiteStorageEngine``
/// for inspiration, but all you need to do is conform to the ``StorageEngine`` protocol
/// and initialize ``ObjectStorage`` with that storage.
public protocol StorageEngine: Actor {
    func write(_ data: Data, key: CacheKey) async throws
    func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) async throws

    func read(key: CacheKey) async -> Data?
    func read(keys: [CacheKey]) async -> [Data]
    func readDataAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, data: Data)]
    func readAllData() async -> [Data]
    func readAllDataAndKeys() async -> [(key: CacheKey, data: Data)]

    func remove(key: CacheKey) async throws
    func remove(keys: [CacheKey]) async throws
    func removeAllData() async throws

    func keyExists(_ key: CacheKey) async -> Bool
    func keysExist(_ keys: [CacheKey]) async -> [CacheKey]
    func keyCount() async -> Int
    func allKeys() async -> [CacheKey]

    func createdAt(key: CacheKey) async -> Date?
    func updatedAt(key: CacheKey) async -> Date?
}

// These default implementations make it easier to implement the `StorageEngine` protocol.
// Some `StorageEngine`s such as ``SQLiteStorageEngine`` may want to implement the one-item
// and array-based functions separately for optimization purposes, but these are safe defaults.
extension StorageEngine {
    /// Reads `Data` items based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    /// - Returns: An array of `[Data]` stored on disk if the ``CacheKey``s exist,
    /// and an `[]` if there is no `Data` matching the `keys` passed in.
    public func read(keys: [CacheKey]) async -> [Data] {
        var dataItems: [Data] = []

        for key in keys {
            if let data = await self.read(key: key) {
                dataItems.append(data)
            }
        }

        return dataItems
    }

    /// Removes `Data` items based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    public func remove(keys: [CacheKey]) async throws {
        for key in keys {
            try await self.remove(key: key)
        }
    }

    /// Reads all the `[Data]` located in the ``StorageEngine``.
    /// - Returns: An array of the `[Data]` contained in a ``StorageEngine``.
    public func readAllData() async -> [Data] {
        let allKeys = await self.allKeys()
        return await self.read(keys: allKeys)
    }

    /// Reads all the `Data` located in the ``StorageEngine`` and returns an array
    /// of `[(CacheKey, Data)]` tuples associated with the ``CacheKey``.
    ///
    /// This method returns the ``CacheKey`` and `Data` together in an array of `[(CacheKey, Data)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over `Data` items, but if you don't need
    /// to know which ``CacheKey`` led to a piece of `Data` being retrieved
    /// you can use ``readAllData()`` instead.
    /// - Returns: An array of the `[Data]` and it's associated `CacheKey`s contained in a directory.
    public func readAllDataAndKeys() async -> [(key: CacheKey, data: Data)] {
        let allKeys = await self.allKeys()
        return await self.readDataAndKeys(keys: allKeys)
    }
    
    /// Checks whether a value with a key is persisted.
    /// - Parameter key: The key to check for existence.
    /// - Returns: If the key exists the function returns true, false if it does not.
    public func keyExists(_ key: CacheKey) async -> Bool {
        return await self.allKeys().contains(key)
    }
    
    /// Filters the provided keys to return only the ones that exist in the engine
    /// - Parameter keys: The list of keys to check for existence.
    /// - Returns: An array of keys that exist. This value is always a subset of the `keys` passed in.
    public func keysExist(_ keys: [CacheKey]) async -> [CacheKey] {
        let allKeys = await self.allKeys()
        let keySet = Set(allKeys)
        return keys.filter { keySet.contains($0) }
    }
    
    /// Read the number of keys located in the ``StorageEngine``.
    /// - Returns: The number of keys located in the ``StorageEngine``
    public func keyCount() async -> Int {
        return await self.allKeys().count
    }
}
