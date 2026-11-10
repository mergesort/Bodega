import Foundation

/// A ``StorageEngine`` based on saving items to the file system.
///
/// The ``DiskStorageEngine`` prioritizes simplicity over speed, it is very easy to use and understand.
/// A ``DiskStorageEngine`` will write a one file for every object you save, which makes
/// it easy to inspect and debug any objects you're saving.
///
/// Initialization times vary based on the total number of objects you have saved,
/// but a simple rule of thumb is that loading 1,000 objects from disk takes about 0.25 seconds.
/// This can start to feel a bit slow if you are saving more than 2,000-3,000, at which point
/// it may be worth investigating alternative ``StorageEngine``s.
///
/// If performance is important ``Bodega`` ships ``SQLiteStorageEngine``, and that is the recommended
/// default ``StorageEngine``. If you have your own persistence layer such as Realm, Core Data, etc,
/// you can easily build your own ``StorageEngine`` to plug into ``ObjectStorage``.
/// Reads throw on filesystem failures. Missing files and an absent storage directory are empty storage.
public actor DiskStorageEngine: StorageEngine {
    /// A directory on the filesystem where your ``StorageEngine``s data will be stored.
    private let directory: FileManager.Directory

    /// Initializes a new ``DiskStorageEngine`` for persisting `Data` to disk.
    /// - Parameter directory: A directory on the filesystem where your files will be written to.
    /// `FileManager.Directory` is a type-safe wrapper around URL that provides sensible defaults like
    ///  `.documents(appendingPath:)`, `.caches(appendingPath:)`, and more.
    public init(directory: FileManager.Directory) {
        self.directory = directory
    }

    /// Writes `Data` to disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - data: The `Data` being stored to disk.
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    public func write(_ data: Data, key: CacheKey) throws {
        let fileURL = self.concatenatedPath(key: key)
        let folderURL = fileURL.deletingLastPathComponent()

        if !Self.directoryExists(atURL: folderURL) {
            try Self.createDirectory(url: folderURL)
        }

        try data.write(to: fileURL, options: .atomic)
    }

    /// Writes an array of `Data` items to disk based on the associated ``CacheKey`` passed in the tuple.
    /// - Parameters:
    ///   - dataAndKeys: An array of the `[(CacheKey, Data)]` to store
    ///   multiple `Data` items with their associated keys at once.
    public func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) throws {
        for dataAndKey in dataAndKeys {
            try self.write(dataAndKey.data, key: dataAndKey.key)
        }
    }

    /// Reads `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    /// - Returns: The `Data` stored on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func read(key: CacheKey) throws -> Data? {
        do {
            return try Data(contentsOf: self.concatenatedPath(key: key))
        } catch let error where Self.isMissingFile(error) {
            return nil
        }
    }

    /// Reads `Data` from disk based on the associated array of ``CacheKey``s provided as a parameter
    /// and returns an array `[(CacheKey, Data)]` associated with the passed in ``CacheKey``s.
    ///
    /// This method returns the ``CacheKey`` and `Data` together in a tuple of `[(CacheKey, Data)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over data, but if you don't need
    /// to know which ``CacheKey`` that led to a piece of `Data` being retrieved
    ///  you can use ``read(keys:)`` instead.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    /// - Returns: An array of `[(CacheKey, Data)]` read from disk if the ``CacheKey``s exist,
    /// and an empty array if there are no `Data` items matching the `keys` passed in.
    public func readDataAndKeys(keys: [CacheKey]) async throws -> [(key: CacheKey, data: Data)] {
        var dataAndKeys: [(key: CacheKey, data: Data)] = []

        for key in keys {
            if let data = try self.read(key: key) {
                dataAndKeys.append((key, data))
            }
        }

        return dataAndKeys
    }

    /// Reads all the `[Data]` located in the `directory`.
    /// - Returns: An array of the `[Data]` contained on disk.
    public func readAllData() async throws -> [Data] {
        let allKeys = try self.allKeys()
        return try await self.read(keys: allKeys)
    }

    /// Reads all the `Data` located in the `directory` and returns an array
    /// of `[(CacheKey, Data)]` tuples associated with the ``CacheKey``.
    ///
    /// This method returns the ``CacheKey`` and `Data` together in an array of `[(CacheKey, Data)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over `Data` items, but if you don't need
    /// to know which ``CacheKey`` led to a piece of `Data` being retrieved
    /// you can use ``readAllData()`` instead.
    /// - Returns: An array of the `[Data]` and it's associated `CacheKey`s contained in a directory.
    public func readAllDataAndKeys() async throws -> [(key: CacheKey, data: Data)] {
        let allKeys = try self.allKeys()
        return try await self.readDataAndKeys(keys: allKeys)
    }

    /// Removes `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    public func remove(key: CacheKey) throws {
        do {
            try FileManager.default.removeItem(at: self.concatenatedPath(key: key))
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Removes all the `Data` items located in the `directory`.
    public func removeAllData() throws {
        do {
            try FileManager.default.removeItem(at: self.directory.url)
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Checks whether a value with a key is persisted.
    ///
    /// This implementation provides `O(1)` checking for the key's existence.
    /// - Parameter key: The key to check for existence.
    /// - Returns: If the key exists the function returns true, false if it does not.
    public func keyExists(_ key: CacheKey) throws -> Bool {
        do {
            let values = try self.concatenatedPath(key: key).resourceValues(forKeys: [.isDirectoryKey])
            return values.isDirectory == false
        } catch let error where Self.isMissingFile(error) {
            return false
        }
    }

    /// Iterates through a directory to find the total number of `Data` items.
    /// - Returns: The file/key count.
    public func keyCount() throws -> Int {
        return try self.allKeys().count
    }

    /// Iterates through a `directory` to find all of the keys.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys() throws -> [CacheKey] {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: self.directory.url, includingPropertiesForKeys: nil)
            let fileOnlyKeys = directoryContents.lazy.filter({ !$0.hasDirectoryPath }).map(\.lastPathComponent)

            return fileOnlyKeys.map(CacheKey.init(verbatim:))
        } catch let error where Self.isMissingFile(error) {
            return []
        }
    }

    /// Returns the date of creation for the file represented by the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    /// - Returns: The creation date of the `Data` on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func createdAt(key: CacheKey) throws -> Date? {
        do {
            return try self.concatenatedPath(key: key)
                .resourceValues(forKeys: [.creationDateKey]).creationDate
        } catch let error where Self.isMissingFile(error) {
            return nil
        }
    }

    /// Returns the updatedAt date for the file represented by the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    /// - Returns: The updatedAt date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func updatedAt(key: CacheKey) throws -> Date? {
        do {
            return try self.concatenatedPath(key: key)
                .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch let error where Self.isMissingFile(error) {
            return nil
        }
    }

    /// Returns the last access date of the file for the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data` to a location on disk.
    /// - Returns: The last access date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func lastAccessed(key: CacheKey) throws -> Date? {
        do {
            return try self.concatenatedPath(key: key)
                .resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
        } catch let error where Self.isMissingFile(error) {
            return nil
        }
    }
}

private extension DiskStorageEngine {
    static func createDirectory(url: URL) throws {
        try FileManager.default
            .createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
    }

    static func directoryExists(atURL url: URL) -> Bool {
        var isDirectory: ObjCBool = true

        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    }
    
    static func isMissingFile(_ error: any Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain
            && (error.code == CocoaError.fileNoSuchFile.rawValue || error.code == CocoaError.fileReadNoSuchFile.rawValue)
    }

    func concatenatedPath(key: CacheKey) -> URL {
        return self.directory.url.appendingPathComponent(key.value)
    }
}
