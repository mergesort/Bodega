import Foundation
import SQLite

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
public actor SQLiteStorageEngine: StorageEngine {

    private let connection: Connection

    /// A directory on the filesystem where your ``StorageEngine``s data will be stored.
    private let directory: FileManager.Directory

    /// Initializes a new ``SQLiteStorageEngine`` for persisting `Data` to disk.
    ///
    /// - Parameter directory: A directory on the filesystem where your files will be written to.
    /// `FileManager.Directory` is a type-safe wrapper around URL that provides sensible defaults like
    ///  `.documents(appendingPath:)`, `.caches(appendingPath:)`, and more.
    public init?(directory: FileManager.Directory, databaseFilename filename: String = "data") {
        self.directory = directory

        do {
            if !Self.directoryExists(atURL: directory.url) {
                try Self.createDirectory(url: directory.url)
            }

            self.connection = try Connection(directory.url.appendingPathComponent(filename).appendingPathExtension("sqlite3").absoluteString)
            self.connection.busyTimeout = 3

            try self.connection.run(Self.storageTable.create(ifNotExists: true) { table in
                table.column(Self.expressions.keyRow, primaryKey: true)
                table.column(Self.expressions.dataRow)
                table.column(Self.expressions.createdAtRow, defaultValue: Date())
                table.column(Self.expressions.updatedAtRow, defaultValue: Date())
            })
        } catch {
            return nil
        }
    }

    /// Writes `Data` to the database with an associated ``CacheKey``.
    /// - Parameters:
    ///   - data: The `Data` being stored to disk.
    ///   - key: A ``CacheKey`` for matching `Data`.
    public func write(_ data: Data, key: CacheKey) throws {
        let values = [
            Self.expressions.keyRow <- key.rawValue,
            Self.expressions.dataRow <- data,
            Self.expressions.updatedAtRow <- Date()
        ]

        if self.keyExists(key) {
            try self.connection.run(
                Self.storageTable
                    .filter(Self.expressions.keyRow == key.rawValue)
                    .update(values)
            )
        } else {
            try self.connection.run(
                Self.storageTable.insert(values)
            )
        }
    }

    /// Writes an array of `Data` items to the database with their associated ``CacheKey`` from the tuple.
    /// - Parameters:
    ///   - dataAndKeys: An array of the `[(CacheKey, Data)]` to store
    ///   multiple `Data` items with their associated keys at once.
    public func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) throws {
        guard !dataAndKeys.isEmpty else { return }
        
        let values = dataAndKeys.map({[
            Self.expressions.keyRow <- $0.key.rawValue,
            Self.expressions.dataRow <- $0.data,
            Self.expressions.updatedAtRow <- Date()
        ]})

        try self.connection.run(
            Self.storageTable.insertMany(or: .replace, values)
        )
    }

    /// Reads `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The `Data` stored if it exists, nil if there is no `Data` stored for the `CacheKey`.
    public func read(key: CacheKey) -> Data? {
        do {
            let query = Self.storageTable
                .select(Self.expressions.keyRow, Self.expressions.dataRow)
                .filter(Self.expressions.keyRow == key.rawValue)
                .limit(1)

            return try self.connection.pluck(query)?[Self.expressions.dataRow]
        } catch {
            return nil
        }
    }

    /// Reads `Data` items based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items.
    /// - Returns: An array of `[Data]` stored on disk if the `CacheKey`s exist,
    /// and an `[]` if there is no `Data` matching the `keys` passed in.
    public func read(keys: [CacheKey]) -> [Data] {
        do {
            let query = Self.storageTable.select(Self.expressions.dataRow)
                .where(keys.map(\.rawValue).contains(Self.expressions.keyRow))
                .limit(keys.count)

            return try self.connection.prepare(query)
                .map({ $0[Self.expressions.dataRow] })
        } catch {
            return []
        }
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
    public func readDataAndKeys(keys: [CacheKey]) -> [(key: CacheKey, data: Data)] {
        let query = Self.storageTable.select(Self.expressions.keyRow, Self.expressions.dataRow)
            .where(keys.map(\.rawValue).contains(Self.expressions.keyRow))
            .limit(keys.count)

        do {
            return try self.connection.prepare(query)
                .map({ (key: CacheKey(verbatim: $0[Self.expressions.keyRow]), data: $0[Self.expressions.dataRow]) })
        } catch {
            return []
        }
    }

    /// Reads all the `[Data]` located in the database.
    /// - Returns: An array of the `[Data]` contained in the database.
    public func readAllData() -> [Data] {
        let allKeys = self.allKeys()
        return self.read(keys: allKeys)
    }

    /// Reads all the `Data` located in the database and returns an array
    /// of `[(CacheKey, Data)]` tuples associated with the ``CacheKey``.
    ///
    /// This method returns the ``CacheKey`` and `Data` together in an array of `[(CacheKey, Data)]`
    /// allowing you to know which ``CacheKey`` led to a specific `Data` item being retrieved.
    /// This can be useful in allowing manual iteration over `Data` items, but if you don't need
    /// to know which ``CacheKey`` led to a piece of `Data` being retrieved
    /// you can use ``readAllData()`` instead.
    /// - Returns: An array of the `[Data]` and it's associated ``CacheKey``s.
    public func readAllDataAndKeys() -> [(key: CacheKey, data: Data)] {
        let allKeys = self.allKeys()
        return self.readDataAndKeys(keys: allKeys)
    }

    /// Removes `Data` from disk based on the associated ``CacheKey``.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for finding the `Data` to remove.
    public func remove(key: CacheKey) throws {
        let deleteQuery = Self.storageTable.filter(Self.expressions.keyRow == key.rawValue)
        try self.connection.run(deleteQuery.delete())
    }

    /// Removes `Data` items from the database based on the associated array of ``CacheKey``s provided as a parameter.
    /// - Parameters:
    ///   - keys: A `[CacheKey]` for matching multiple `Data` items to remove.
    public func remove(keys: [CacheKey]) throws {
        guard !keys.isEmpty else { return }

        let deleteQuery = Self.storageTable.select(Self.expressions.keyRow, Self.expressions.dataRow)
            .where(keys.map(\.rawValue).contains(Self.expressions.keyRow))
            .limit(keys.count)

        try self.connection.run(deleteQuery.delete())
    }

    /// Removes all the `Data` items from the database.
    public func removeAllData() throws {
        try self.connection.run(Self.storageTable.delete())
    }

    /// Checks whether a value with a key is persisted.
    /// - Parameter key: The key to for existence.
    /// - Returns: If the key exists the function returns true, false if it does not.
    public func keyExists(_ key: CacheKey) -> Bool {
        do {
            let query = Self.storageTable
                .select(Self.expressions.keyRow)
                .filter(Self.expressions.keyRow == key.rawValue)
                .limit(1)

            return try self.connection.pluck(query)?[Self.expressions.keyRow] != nil
        } catch {
            return false
        }
    }

    /// Iterates through the database to find the total number of `Data` items.
    /// - Returns: The file/key count.
    public func keyCount() -> Int {
        do {
            return try self.connection.scalar(
                Self.storageTable.select(
                    Self.expressions.keyRow.distinct.count
                )
            )
        } catch {
            return 0
        }
    }

    /// Iterates through the database to find all of the keys.
    /// - Returns: An array of the keys contained in a directory.
    public func allKeys() -> [CacheKey] {
        let query = Self.storageTable.select(Self.expressions.keyRow)
        do {
            return try self.connection.prepare(query)
                .map({ CacheKey(verbatim: $0[Self.expressions.keyRow]) })
        } catch {
            return []
        }
    }

    /// Returns the date of creation for the `Data` item matching the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The creation date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func createdAt(key: CacheKey) -> Date? {
        do {
            let query = Self.storageTable
                .select(Self.expressions.createdAtRow)
                .filter(Self.expressions.keyRow == key.rawValue)
                .limit(1)

            return try self.connection.pluck(query)?[Self.expressions.createdAtRow]
        } catch {
            return nil
        }
    }

    /// Returns the modification date for the `Data` item matching the ``CacheKey``, if it exists.
    /// - Parameters:
    ///   - key: A ``CacheKey`` for matching `Data`.
    /// - Returns: The modification date of the `Data` on disk if it exists, nil if there is no `Data` stored for the ``CacheKey``.
    public func updatedAt(key: CacheKey) -> Date? {
        do {
            let query = Self.storageTable
                .select(Self.expressions.updatedAtRow)
                .filter(Self.expressions.keyRow == key.rawValue)
                .limit(1)

            return try self.connection.pluck(query)?[Self.expressions.updatedAtRow]
        } catch {
            return nil
        }
    }

}

private extension SQLiteStorageEngine {
    static let storageTable = Table("data")
}

private extension SQLiteStorageEngine {

    struct Expressions {}

    static var expressions: Expressions {
        Expressions()
    }

}

private extension SQLiteStorageEngine.Expressions {

    var keyRow: Expression<String> {
        Expression<String>("key")
    }

    var dataRow: Expression<Data> {
        Expression<Data>("value")
    }

    var createdAtRow: Expression<Date> {
        Expression<Date>("createdAt")
    }

    var updatedAtRow: Expression<Date> {
        Expression<Date>("updatedAt")
    }

}

private extension SQLiteStorageEngine {

    static func directoryExists(atURL url: URL) -> Bool {
        var isDirectory: ObjCBool = true

        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    }

    static func createDirectory(url: URL) throws {
        try FileManager.default
            .createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
    }

}
