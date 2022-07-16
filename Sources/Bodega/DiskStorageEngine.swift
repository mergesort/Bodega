import Foundation

public actor DiskStorageEngine: StorageEngine {

    /// A directory on the filesystem where your `StorageEngine`s data will be stored.
    public var directory: FileManager.Directory

    /// Initializes a new `DiskStorageEngine` object for persisting `Data` to disk.
    /// - Parameter directory: A directory on the filesystem where your files will be written to.
    /// `FileManager.Directory` is a type-safe wrapper around URL that provides sensible defaults like
    ///  `.documents(appendingPath:)`, `.caches(appendingPath:)`, and more.
    public init(directory: FileManager.Directory) {
        self.directory = directory
    }

    /// Writes `Data` to disk based on the associated `CacheKey`.
    /// - Parameters:
    ///   - data: The `Data` being stored to disk.
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    public func write(_ data: Data, key: CacheKey) throws {
        let fileURL = self.concatenatedPath(key: key.value)
        let folderURL = fileURL.deletingLastPathComponent()

        if !Self.directoryExists(atURL: folderURL) {
            try Self.createDirectory(url: folderURL)
        }

        try data.write(to: fileURL, options: .atomic)
    }

    /// Writes an array of `Data` items to disk based on the associated `CacheKey` passed in the tuple.
    /// - Parameters:
    ///   - dataAndKeys: An array of the `[(CacheKey, Data)]` to store
    ///   multiple `Data` items with their associated keys at once.
    public func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) throws {
        for dataAndKey in dataAndKeys {
            try self.write(dataAndKey.data, key: dataAndKey.key)
        }
    }

    /// Reads `Data` from disk based on the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    /// - Returns: The `Data` stored on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func read(key: CacheKey) -> Data? {
        return try? Data(contentsOf: self.concatenatedPath(key: key.value))
    }

    /// Reads `Data` items from disk based on the associated array of `CacheKey`s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items to their a location on disk.
    /// - Returns: An array of `[Data]` stored on disk if the `CacheKey`s exist,
    /// and an `[]` if there is no `Data` matching the `keys` passed in.
    public func read(keys: [CacheKey]) -> [Data] {
        return keys.compactMap({ self.read(key: $0) })
    }

    /// Reads `Data` from disk based on the associated array of `CacheKey`s provided as a parameter
    /// and returns an array `[(CacheKey, Data)]` associated with the passed in `CacheKey`s.
    ///
    /// This method returns the `CacheKey` and `Data` together in a tuple of `[(CacheKey, Data)]`
    /// allowing you to know which `CacheKey` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over data, but if you don't need
    /// to know which `CacheKey` that led to a piece of `Data` being retrieved
    ///  you can use ``read(keys:)`` instead.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items to their a location on disk.
    /// - Returns: An array of `[(CacheKey, Data)]` read from disk if the `CacheKey`s exist,
    /// and an empty array if there are no `Data` items matching the `keys` passed in.
    public func readDataAndKeys(keys: [CacheKey]) -> [(key: CacheKey, data: Data)] {
        return zip(
            keys,
            self.read(keys: keys)
        ).map { ($0, $1) }
    }

    /// Reads all the `[Data]` located in the `directory`.
    /// - Returns: An array of the `[Data]` contained in a directory.
    public func readAllData() -> [Data] {
        let allKeys = self.allKeys()
        return self.read(keys: allKeys)
    }

    /// Reads all the `Data` located in the `directory` and returns an array
    /// of `[(CacheKey, Data)]` tuples associated with the `CacheKey`.
    ///
    /// This method returns the `CacheKey` and `Data` together in an array of `[(CacheKey, Data)]`
    /// allowing you to know which `CacheKey` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over `Data` items, but if you don't need
    /// to know which `CacheKey` led to a piece of `Data` being retrieved
    /// you can use ``readAllData()`` instead.
    /// - Returns: An array of the `[Data]` and it's associated `CacheKey`s contained in a directory.
    public func readAllDataAndKeys() -> [(key: CacheKey, data: Data)] {
        let allKeys = self.allKeys()
        return self.readDataAndKeys(keys: allKeys)
    }

    /// Removes `Data` from disk based on the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    public func remove(key: CacheKey) throws {
        do {
            try FileManager.default.removeItem(at: self.concatenatedPath(key: key.value))
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Removes `Data` items from disk based on the associated array of `[CacheKey]`s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items to their a location on disk.
    public func remove(keys: [CacheKey]) throws {
        for key in keys {
            try self.remove(key: key)
        }
    }

    /// Removes all the `Data` items located in the `directory`.
    public func removeAllData() throws {
        do {
            try FileManager.default.removeItem(at: self.folder)
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Iterates through a directory to find the total number of `Data` items.
    /// - Returns: The file/key count.
    public func keyCount() -> Int {
        return self.allKeys().count
    }

    /// Checks whether a value with a key is persisted.
    /// - Parameter key: The key to for existence.
    /// - Returns: If the key exists the function returns true, false if it does not.
    public func keyExists(_ key: CacheKey) -> Bool {
        self.allKeys().contains(key)
    }

    /// Iterates through a `directory` to find all of the keys.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys() -> [CacheKey] {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: self.folder, includingPropertiesForKeys: nil)
            let fileOnlyKeys = directoryContents.lazy.filter({ !$0.hasDirectoryPath }).map(\.lastPathComponent)

            return fileOnlyKeys.map(CacheKey.init(verbatim:))
        } catch {
            return []
        }
    }

    /// Returns the date of creation for the file represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    /// - Returns: The creation date of the `Data` on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func createdAt(key: CacheKey) -> Date? {
        return try? self.concatenatedPath(key: key.value)
            .resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    /// Returns the last access date of the file for the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    /// - Returns: The last access date of the `Data` on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func lastAccessed(key: CacheKey) -> Date? {
        return try? self.concatenatedPath(key: key.value)
            .resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }

    /// Returns the modification date for the file represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching `Data` to a location on disk.
    /// - Returns: The modification date of the `Data` on disk if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func updatedAt(key: CacheKey) -> Date? {
        return try? self.concatenatedPath(key: key.value)
            .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
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

    func concatenatedPath(key: String) -> URL {
        return self.folder.appendingPathComponent(key)
    }

}
