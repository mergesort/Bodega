import Foundation

/// An unified layer over a ``StorageEngine`` primitives, allowing you to read, write, and save Swift objects.
///
/// An ``ObjectStorage`` is a higher level abstraction than a ``StorageEngine``, allowing you
/// to interact with Swift objects, never thinking about the persistence layer that's saving
/// objects under the hood.
///
/// If you do not provide a ``StorageEngine`` parameter then ``ObjectStorage`` will default to
/// using an ``SQLiteStorageEngine``, with a database located in the app's Documents directory.
///
/// The ``SQLiteStorageEngine`` is a safe, fast, and easy database to based on SQLite,
/// but if you prefer to use your own persistence layer or want to save your objects
/// to another location, you can use the `storage` parameter like so
/// ```
/// SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Assets"))
/// ```
public actor ObjectStorage<Object: Codable> {

    private let storage: StorageEngine

    // A property for performance reasons, to avoid creating a new encoder on every write, N times for array-based methods.
    private let encoder = JSONEncoder()

    // A property for performance reasons, to avoid creating a new decoder on every read, N times for array-based methods.
    private let decoder = JSONDecoder()

    /// Initializes a new ``ObjectStorage`` object for persisting `Object`s.
    /// - Parameter storage: A ``StorageEngine`` to initialize an ``ObjectStorage`` instance with.
    public init(storage: StorageEngine) {
        self.storage = storage
    }

    /// Writes an `Object` based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - object: The object being stored.
    ///   - key: A ``CacheKey`` for matching an `Object`.
    public func store(_ object: Object, forKey key: CacheKey) async throws {
        let data = try self.encoder.encode(object)

        return try await storage.write(data, key: key)
    }

    /// Writes an array of `[Object]`s based on the associated ``CacheKey`` passed in the tuple.
    /// - Parameters:
    ///   - objectsAndKeys: An array of `[(CacheKey, Object)]` to store
    ///   multiple objects with their associated keys at once.
    public func store(_ objectsAndKeys: [(key: CacheKey, object: Object)]) async throws {
        let dataAndKeys = try objectsAndKeys.map({ try ($0.key, self.encoder.encode($0.object)) })

        try await storage.write(dataAndKeys)
    }

    /// Reads an `Object` based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching an `Object`.
    /// - Returns: The object stored if it exists, nil if there is no `Object` stored for the ``CacheKey``.
    public func object(forKey key: CacheKey) async -> Object? {
        guard let data = await storage.read(key: key) else { return nil }

        return try? self.decoder.decode(Object.self, from: data)
    }

    /// Reads `Object`s based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Object`s.
    /// - Returns: An array of `[Object]`s stored if the ``CacheKey``s exist,
    /// and an `[]` if there are no `Object`s matching the `keys` passed in.
    public func objects(forKeys keys: [CacheKey]) async -> [Object] {
        let dataItems = await storage.read(keys: keys)

        do {
            return try dataItems.map({ try self.decoder.decode(Object.self, from: $0) })
        } catch {
            return []
        }
    }

    /// Reads `Object`s based on the associated array of ``CacheKey``s provided as a parameter
    /// and returns an array `[(CacheKey, Object)]` associated with the passed in ``CacheKey``s.
    ///
    /// This method returns the ``CacheKey`` and `Object` together in a tuple of `[(CacheKey, Object)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Object` being retrieved.
    /// This can be useful in allowing manual iteration over `Object`s, but if you don't need to know
    /// which ``CacheKey`` that led to an `Object` being retrieved you can use ``objects(forKeys:)`` instead.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Object`s.
    /// - Returns: An array of `[(CacheKey, Object)]` read if it exists,
    /// and an empty array if there are no `Objects`s matching the `keys` passed in.
    public func objectsAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, object: Object)] {
        return zip(
            keys,
            await self.objects(forKeys: keys)
        ).map { ($0, $1) }
    }

    /// Reads all `[Object]` objects.
    /// - Returns: An array of `[Object]`s contained in a directory.
    public func allObjects() async -> [Object] {
        let allKeys = await self.allKeys()
        return await self.objects(forKeys: allKeys)
    }

    /// Reads all of the objects and returns an array
    /// of `[(CacheKey, Object)]` associated with the ``CacheKey``.
    ///
    /// This method returns the ``CacheKey`` and `Object` together in an array of `[(CacheKey, Object)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Object` item being retrieved.
    /// This can be useful in allowing manual iteration over `Object`s, but if you
    /// don't need to know which ``CacheKey`` led to an `Object` being retrieved
    /// you can use ``allObjects()`` instead.
    /// - Returns: An array of `Object`s and it's associated ``CacheKey``s contained in a directory.
    public func allObjectsAndKeys() async -> [(key: CacheKey, object: Object)] {
        let allKeys = await self.allKeys()
        return await self.objectsAndKeys(keys: allKeys)
    }

    /// Removes an `Object` based on the the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching an `Object`.
    public func removeObject(forKey key: CacheKey) async throws {
        try await storage.remove(key: key)
    }

    /// Removes `[Object]`s from the underlying Storage based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Object`s.
    public func removeObject(forKeys keys: [CacheKey]) async throws {
        for key in keys {
            try await storage.remove(key: key)
        }
    }

    /// Removes all of the `Object`s.
    public func removeAllObjects() async throws {
        try await storage.removeAllData()
    }

    /// Iterates through a directory to find the total number of objects.
    /// - Returns: The object/key count.
    public func keyCount() async -> Int {
        return await storage.keyCount()
    }

    /// Iterates through the ``ObjectStorage`` to find all of the `Object`s keys.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys() async -> [CacheKey] {
        return await storage.allKeys()
    }

    /// Returns the date of creation for the object represented by the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching an `Object`.
    /// - Returns: The creation date of the `Object` if it exists, nil if there is no `Object` stored for the ``CacheKey``.
    public func createdAt(forKey key: CacheKey) async -> Date? {
        return await storage.createdAt(key: key)
    }

    /// Returns the modification date for the object represented by the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching an `Object`.
    /// - Returns: The modification date of the object if it exists, nil if there is no object stored for the ``CacheKey``.
    public func updatedAt(forKey key: CacheKey) async -> Date? {
        return await storage.updatedAt(key: key)
    }

}
