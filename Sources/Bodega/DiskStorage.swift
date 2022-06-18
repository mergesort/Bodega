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

    /// Reads `Data` from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can read from.
    /// - Returns: The data stored on disk if it exists, nil if there is no data stored behind the `CacheKey`.
    public func read(key: CacheKey, subdirectory: String? = nil) -> Data? {
        return try? Data(contentsOf: self.concatenatedPath(key: key.value, subdirectory: subdirectory))
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
            let fileOnlyKeys = directoryContents.filter({ !$0.hasDirectoryPath }).map(\.lastPathComponent)

            return fileOnlyKeys.map(CacheKey.init(verbatim:))
        } catch {
            return []
        }
    }

    /// Iterates through a directory to find the total number of files.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: The file/key count.
    public func keyCount(inSubdirectory subdirectory: String? = nil) -> Int {
        return self.allKeys(inSubdirectory: subdirectory).count
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
