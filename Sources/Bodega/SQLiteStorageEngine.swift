import Foundation
import SQLite3

/// A ``StorageEngine`` based on an SQLite database.
///
/// ``SQLiteStorageEngine`` is significantly faster than ``DiskStorageEngine`` because it uses SQLite
/// rather than saving files to disk. As much as ``DiskStorageEngine`` was optimized, file system operations
/// like reading, writing, and removing files have a relatively high cost per operation, and SQLite
/// [has been shown](https://www.sqlite.org/fasterthanfs.html) to be significantly faster than files for storing data.
///
/// If you're not using your own persistence mechanism such as Realm, Core Data, etc,
/// it is highly recommended you use ``SQLiteStorageEngine`` to power your ``ObjectStorage``.
///
/// When initializing a database there is a possibility that the database Connection will fail.
/// There isn't much reason to expect this, but it is a possibility so this initializer returns an optional.
///
/// Generally creating implicitly unwrapped optionals is frowned upon, but it's worth asking
/// what will happen if you use one when initializing a ``SQLiteStorageEngine``.
///
/// Code like this may look dangerous at first glance because of the `!`,
/// but if that database is storing important data and fails to initialize
/// then the app will likely not function as the user expects.
/// ```
/// let storageEngine = SQLiteStorageEngine(directory: .documents(appending: "Notes))!
/// ```
/// The alternate experience is to continue running the app with a database not capable of saving data,
/// an equally bad if not more confusing experience for a user.
///
/// One alternative is to make the initializer `throw`, and that's a perfectly reasonable tradeoff.
/// While that is doable, I believe it's very unlikely the caller will have specific remedies for
/// specific SQLite errors, so for simplicity I've made the initializer return an optional ``SQLiteStorageEngine``.
public actor SQLiteStorageEngine {
    private let tableName: String
    private let sqliteFileURL: URL

    private var dbPointer: OpaquePointer?

    /// Initialize a new instance of the ``SQLiteStorageEngine`` for persisting `Data` to disk.
    /// - Parameters:
    ///   - directory: The director that will contain the sqlite3 file. `FileManager.Directory` is a type safe wrapper around URL that provides sensible defaults like `.documents(appendingPath:)`, `.caches(appendingPath:)` and more.
    ///   - filename: The `String` filename to use for the database, this will also be used as the table name in the database.
    ///   - fileProtection: The `URLFileProtection` used when creating sqlite3 file. **NOTE** Using .complete or .completeUnlessOpen
    ///   will cause the database to not be able to be read or written to while the app is in the background.
    init?(
        directory: FileManager.Directory,
        databaseFilename filename: String = "data",
        fileProtection: URLFileProtection = .completeUntilFirstUserAuthentication
    ) {
        tableName = filename

        do {
            sqliteFileURL = try Self.createSQLiteFile(in: directory, withFilename: filename, attributes: [.protectionKey: fileProtection])

            // Open connection to database
            guard sqlite3_open(sqliteFileURL.relativePath, &dbPointer) == SQLITE_OK else {
                throw SQLite.SQLiteDatabaseError.unableToOpenDatabaseConnection
            }

            // Create the table, if needed.
            try SQLite.createTableNamed(tableName, inDatabase: dbPointer)
        } catch {
            return nil
        }
    }

    deinit {
        sqlite3_close(dbPointer)
    }
}

// MARK: - StorageEngine

extension SQLiteStorageEngine: StorageEngine {
    /// Writes `Data` to the database with an associated ``CacheKey``.
    /// - Parameters:
    ///   - data: The `Data` being stored to disk.
    ///   - key: A ``CacheKey`` for matching `Data`.
    public func write(_ data: Data, key: CacheKey) async throws {
        try await write([(key, data)])
    }

    /// Writes an array of `Data` items to the database with their associated ``CacheKey`` from the tuple.
    /// - Parameters:
    ///   - dataAndKeys: An array of the `[(CacheKey, Data)]` to store
    ///   multiple `Data` items with their associated keys at once.
    public func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) async throws {
        guard dataAndKeys.isEmpty == false else { return }
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try SQLite.writeDataAndKeys(dataAndKeys, toTableNamed: tableName, inDatabase: dbPointer)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Reads `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The `Data` stored if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func read(key: CacheKey) async -> Data? {
        await readDataAndKeys(keys: [key]).first?.data
    }

    /// Reads `Data` items based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    /// - Returns: An array of `[Data]` stored on disk if the `CacheKey`s exist,
    /// and an `[]` if there is no `Data` matching the `keys` passed in.
    public func read(keys: [CacheKey]) async -> [Data] {
        await readDataAndKeys(keys: keys).map(\.data)
    }

    /// Reads `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The `Data` stored if it exists, nil if there is no `Data` stored for the `CacheKey`.

    /// This method returns the ``CacheKey`` and `Data` together in a tuple of `[(CacheKey, Data)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over data, but if you don't need
    /// to know which ``CacheKey`` that led to a piece of `Data` being retrieved
    ///  you can use ``read(keys:)`` instead.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    /// - Returns: An array of `[(CacheKey, Data)]` if the `CacheKey`s exist,
    /// and an empty array if there are no `Data` items matching the `keys` passed in.
    public func readDataAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, data: Data)] {
        return await withCheckedContinuation { continuation in
            let results = SQLite.selectKeys(keys, inTable: tableName, inDatabase: dbPointer)
            continuation.resume(returning: results)
        }
    }

    /// Removes `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for finding the `Data` to remove.
    public func remove(key: CacheKey) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try SQLite.deleteKeys([key], fromTable: tableName, inDatabase: dbPointer)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Removes `Data` items from the database based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items to remove.
    public func remove(keys: [CacheKey]) async throws {
        guard keys.isEmpty == false else { return }
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try SQLite.deleteKeys(keys, fromTable: tableName, inDatabase: dbPointer)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Removes all the `Data` items from the database.
    public func removeAllData() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try SQLite.emptyTableNamed(tableName, inDatabase: dbPointer)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Checks whether a value with a key is persisted.
    /// - Parameter key: The key to for existence.
    /// - Returns: If the key exists the function returns true, false if it does not.
    public func keyExists(_ key: CacheKey) async -> Bool {
        return await withCheckedContinuation { continuation in
            do {
                try SQLite.keyExists(key, inTable: tableName, inDatabase: dbPointer)
                continuation.resume(returning: true)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Iterates through the database to find the total number of `Data` items.
    /// - Returns: The file/key count.
    public func keyCount() async -> Int {
        return await withCheckedContinuation { continuation in
            let queryResult = SQLite.keyCount(inTable: tableName, inDatabase: dbPointer)
            continuation.resume(returning: queryResult)
        }
    }

    /// Iterates through the database to find all of the keys.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys() async -> [CacheKey] {
        return await withCheckedContinuation { continuation in
            let queryResult = SQLite.selectAllKeys(inTable: tableName, inDatabase: dbPointer)
            continuation.resume(returning: queryResult)
        }
    }

    /// Returns the date of creation for the `Data` item matching the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The creation date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func createdAt(key: CacheKey) async -> Date? {
        return await withCheckedContinuation { continuation in
            let result = SQLite.selectDateColumn(.createdAt, matchingKeys: [key], inTable: tableName, inDatabase: dbPointer).first
            continuation.resume(returning: result)
        }
    }

    /// Returns the modification date for the `Data` item matching the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The modification date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func updatedAt(key: CacheKey) async -> Date? {
        return await withCheckedContinuation { continuation in
            let result = SQLite.selectDateColumn(.updatedAt, matchingKeys: [key], inTable: tableName, inDatabase: dbPointer).first
            continuation.resume(returning: result)
        }
    }
}

private extension SQLiteStorageEngine {
    static func createSQLiteFile(in directory: FileManager.Directory, withFilename filename: String, attributes: [FileAttributeKey: Any]) throws -> URL {
        let fileURL = directory.url
            .appendingPathComponent(filename)
            .appendingPathExtension("sqlite3")

        guard FileManager.default.fileExists(atPath: fileURL.relativePath) == false else {
            return fileURL
        }
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: fileURL.relativePath, contents: nil, attributes: attributes)
        return fileURL
    }
}

extension SQLiteStorageEngine {
    // The destroy method isn't exposed outside of the module, as it's only used by the unit tests to clean up the database file.
    func deleteSQLiteFile() throws {
        sqlite3_close(dbPointer)
        guard FileManager.default.fileExists(atPath: sqliteFileURL.relativePath) else {
            // No file exists, fail silently
            return
        }
        try FileManager.default.removeItem(atPath: sqliteFileURL.relativePath)
    }
}
