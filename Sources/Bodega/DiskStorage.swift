import Foundation

public actor DiskStorage {

    private let folder: URL

    /// Initializes a new DiskStorage object for persisting data to disk.
    /// - Parameter storagePath: A URL representing the folder on disk that your files will be written to.
    /// Constructed as a URL for those that wish to use features like shared containers, rather than as traditionally in the Documents or Caches directory.
    public init(storagePath: URL) {
        self.folder = storagePath
    }

    /// Writes `Data` to disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - data: The data being stored to disk.
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can write to.
    public func write(_ data: Data, key: CacheKey, subdirectory: String? = nil) throws {
        let fileURL = self.concatenatedPath(key: key.value, subdirectory: subdirectory)
        let folderURL = fileURL.deletingLastPathComponent()

        if !Self.directoryExists(atURL: folderURL) {
            try Self.createDirectory(url: folderURL)
        }

        try data.write(to: fileURL, options: .atomic)
    }

    /// Writes an array `Data` items to disk based on the associated `CacheKey` passed in the tuple.
    /// - Parameters:
    ///   - dataAndKeys: An array of the tuple type (CacheKey, Data) to store multiple data items
    ///   with their associated keys at once.
    ///   - subdirectory: An optional subdirectory the caller can write to.
    public func write(_ dataAndKeys: [(key: CacheKey, data: Data)], subdirectory: String? = nil) throws {
        for dataAndKey in dataAndKeys {
            try self.write(dataAndKey.data, key: dataAndKey.key, subdirectory: subdirectory)
        }
    }

    /// Reads `Data` from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The data stored on disk if it exists, nil if there is no data stored for the `CacheKey`.
    public func read(key: CacheKey, subdirectory: String? = nil) -> Data? {
        return try? Data(contentsOf: self.concatenatedPath(key: key.value, subdirectory: subdirectory))
    }

    /// Reads data from disk based on the associated array of `CacheKey`s provided as a parameter.
    /// - Parameters:
    ///   - keys: A [CacheKey] for matching multiple `Data` items to their a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: An array of `[Data]` stored on disk if the `CacheKey`s exist,
    /// and an `[]` if there is no data matching the `keys` passed in.
    public func read(keys: [CacheKey], subdirectory: String? = nil) -> [Data] {
        return keys.compactMap({ self.read(key: $0, subdirectory: subdirectory) })
    }

    /// Reads data from disk based on the associated array of `CacheKey`s provided as a parameter
    /// and returns an array of a tuple of the `CacheKey` and `Data` associated with the passed in `CacheKey`s.
    ///
    /// This method returns the `CacheKey` and `Data` together in a tuple of `(CacheKey, Data)`
    /// allowing you to know which `CacheKey` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over data, but if you don't need
    /// to know which `CacheKey` that led to a piece of `Data` being retrieved
    ///  you can use ``read(keys:subdirectory:)`` instead.
    /// - Parameters:
    ///   - keys: A [CacheKey] for matching multiple `Data` items to their a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: An array of `[(CacheKey, Data)]` read from disk if the `CacheKey`s exist,
    /// and an empty array if there are no data items matching the `keys` passed in.
    public func readDataAndKeys(keys: [CacheKey], subdirectory: String? = nil) -> [(key: CacheKey, data: Data)] {
        return zip(
            keys,
            self.read(keys: keys, subdirectory: subdirectory)
        ).map { ($0, $1) }
    }

    /// Reads all the data located at the `storagePath` or it's `subdirectory`.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the data contained in a directory.
    public func readAllData(inSubdirectory subdirectory: String? = nil) -> [Data] {
        let allKeys = self.allKeys(inSubdirectory: subdirectory)
        return self.read(keys: allKeys)
    }

    /// Reads all the data located at the `storagePath` or it's `subdirectory` and returns an array
    /// of a tuple of the `CacheKey` and `Data` associated with the `CacheKey`.
    ///
    /// This method returns the `CacheKey` and `Data` together in a tuple of `(CacheKey, Data)`
    /// allowing you to know which `CacheKey` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over data, but if you don't need
    /// to know which `CacheKey` led to a piece of `Data` being retrieved
    /// you can use ``readAllDataAndKeys(inSubdirectory:)`` instead.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the data and it's associated `CacheKey`s contained in a directory.
    public func readAllDataAndKeys(inSubdirectory subdirectory: String? = nil) -> [(key: CacheKey, data: Data)] {
        let allKeys = self.allKeys(inSubdirectory: subdirectory)
        return self.readDataAndKeys(keys: allKeys)
    }

    /// Removes `Data` from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can remove a file from.
    public func remove(key: CacheKey, subdirectory: String? = nil) throws {
        do {
            try FileManager.default.removeItem(at: self.concatenatedPath(key: key.value, subdirectory: subdirectory))
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Removes `Data` items from disk based on the associated array of `CacheKey`s provided as a parameter.
    /// - Parameters:
    ///   - keys: A [CacheKey] for matching multiple `Data` items to their a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can remove a file from.
    public func remove(keys: [CacheKey], subdirectory: String? = nil) throws {
        for key in keys {
            try self.remove(key: key, subdirectory: subdirectory)
        }
    }

    /// Removes all the data located at the `storagePath` or it's `subdirectory`.
    /// - subdirectory: An optional subdirectory the caller can remove a file from.
    public func removeAllData(inSubdirectory subdirectory: String? = nil) throws {
        let folderToRemove: URL
        if let subdirectory = subdirectory {
            folderToRemove = self.folder.appendingPathComponent(subdirectory)
        } else {
            folderToRemove = self.folder
        }

        do {
            try FileManager.default.removeItem(at: folderToRemove)
        } catch CocoaError.fileNoSuchFile {
            // No-op, we treat deleting a non-existent file/folder as a successful removal rather than throwing
        } catch {
            throw error
        }
    }

    /// Iterates through a directory to find the total number of files.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: The file/key count.
    public func keyCount(inSubdirectory subdirectory: String? = nil) -> Int {
        return self.allKeys(inSubdirectory: subdirectory).count
    }

    /// Iterates through a directory to find all of the files and their respective keys.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys(inSubdirectory subdirectory: String? = nil) -> [CacheKey] {
        let directory: URL

        if let subdirectory = subdirectory {
            directory = folder.appendingPathComponent(subdirectory)
        } else {
            directory = folder
        }

        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let fileOnlyKeys = directoryContents.lazy.filter({ !$0.hasDirectoryPath }).map(\.lastPathComponent)

            return fileOnlyKeys.map(CacheKey.init(verbatim:))
        } catch {
            return []
        }
    }

    /// Returns the date of creation for the file represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The last access date of the data on disk if it exists, nil if there is no data stored for the `CacheKey`.
    public func createdAt(key: CacheKey, subdirectory: String? = nil) -> Date? {
        return try? self.concatenatedPath(key: key.value, subdirectory: subdirectory)
            .resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    /// Returns the last access date of the file for the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The last access date of the data on disk if it exists, nil if there is no data stored for the `CacheKey`.
    public func lastAccessed(key: CacheKey, subdirectory: String? = nil) -> Date? {
        return try? self.concatenatedPath(key: key.value, subdirectory: subdirectory)
            .resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }

    /// Returns the modification date for the file represented by the `CacheKey`, if it exists.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The modification date of the data on disk if it exists, nil if there is no data stored for the `CacheKey`.
    public func lastModified(key: CacheKey, subdirectory: String? = nil) -> Date? {
        return try? self.concatenatedPath(key: key.value, subdirectory: subdirectory)
            .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

}

private extension DiskStorage {

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

    func concatenatedPath(key: String, subdirectory: String?) -> URL {
        if let subdirectory = subdirectory {
            return self.folder.appendingPathComponent(subdirectory).appendingPathComponent(key)
        } else {
            return self.folder.appendingPathComponent(key)
        }
    }

}
