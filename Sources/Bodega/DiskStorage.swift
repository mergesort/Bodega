import Foundation

public actor DiskStorage {

    private let folder: URL

    /// Initializes a new DiskStorage object for persisting data to disk.
    /// - Parameter storagePath: A URL representing the folder on disk that your files will be written to.
    /// Constructed as a URL for those that wish to use features like shared containers, rather than as
    /// traditionally in the Documents or Caches directory.
    public init(storagePath: URL) {
        self.folder = storagePath
    }

    /// Writes `Data` to disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - data: The data being stored to disk.
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can write to.
    public func write(_ data: Data, key: CacheKey, subdirectory: String = "") throws {
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
    public func read(key: CacheKey, subdirectory: String = "") -> Data? {
        return try? Data(contentsOf: self.concatenatedPath(key: key.value, subdirectory: subdirectory))
    }

    /// Removes `Data` from disk with the associated `CacheKey`.
    /// - Parameters:
    ///   - key: A `CacheKey` for matching Data to a location on disk.
    ///   - subdirectory: An optional subdirectory the caller can remove a file from.
    public func remove(key: CacheKey, subdirectory: String = "") throws {
        try FileManager.default.removeItem(at: self.concatenatedPath(key: key.value, subdirectory: subdirectory))
    }

    /// Iterates through a directory to find all of the files and their respective keys.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys(subdirectory: String = "") -> [CacheKey] {
        guard let keys = try? FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent(subdirectory).path) else { return [] }

        return keys.map({ CacheKey.init($0) })
    }

    /// Iterates through a directory to find the total number of files.
    /// - Parameter subdirectory: An optional subdirectory the caller can navigate for iteration.
    /// - Returns: The file/key count.
    public func keyCount(inSubdirectory subdirectory: String = "") -> Int {
        return self.allKeys(subdirectory: subdirectory).count
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

    func concatenatedPath(key: String, subdirectory: String) -> URL {
        self.folder.appendingPathComponent(subdirectory).appendingPathComponent(key)
    }

}
