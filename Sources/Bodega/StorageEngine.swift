import Foundation

/// A StorageEngine represents an underlying data store mechanism for saving and persisting data.
///
/// A `StorageEngine` is a construct you can build that plugs into ``ObjectStorage``
/// to use for persisting data.
///
/// This library has two implementations of `StorageEngine`, ``DiskStorageEngine`` and ``SQLiteStorageEngine``.
/// Both of these can serve as inspiration if you have your own persistence mechanism (such as Realm, CoreData, etc).
///
/// ``DiskStorageEngine`` takes `Data` and saves it to disk using file system operations.
/// ``SQLiteStorageEngine`` takes `Data` and saves it to an SQLite database under the hood.
///
/// If you have your own way of storing data then you can refer to ``DiskStorageEngine`` and ``SQLiteStorageEngine``
/// for inspiration, but all you need to do is conform to the `StorageEngine` protocol
/// and initialize ``ObjectStorage`` with that storage.
public protocol StorageEngine: Actor {
    var directory: FileManager.Directory { get }

    func write(_ data: Data, key: CacheKey) throws
    func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) throws

    func read(key: CacheKey) -> Data?
    func read(keys: [CacheKey]) -> [Data]
    func readDataAndKeys(keys: [CacheKey]) -> [(key: CacheKey, data: Data)]
    func readAllData() -> [Data]
    func readAllDataAndKeys() -> [(key: CacheKey, data: Data)]

    func remove(key: CacheKey) throws
    func remove(keys: [CacheKey]) throws
    func removeAllData() throws

    func keyCount() -> Int
    func keyExists(_ key: CacheKey) -> Bool
    func allKeys() -> [CacheKey]

    func createdAt(key: CacheKey) -> Date?
    func updatedAt(key: CacheKey) -> Date?
}

internal extension StorageEngine {

    /// A helper that `StorageEngine`s can use internally instead of referencing `directory.url`.
    var folder: URL {
        self.directory.url
    }

}
