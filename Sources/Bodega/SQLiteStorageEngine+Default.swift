public extension SQLiteStorageEngine {

    /// An ``SQLiteStorageEngine`` located in the platform-specific default storage directory.
    ///
    /// Equivalent to:
    /// `SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Data"))`
    static var `default`: SQLiteStorageEngine {
        self.default(appendingPath: "Data")
    }

    /// An ``SQLiteStorageEngine`` located in the platform-specific default storage directory.
    ///
    /// Equivalent to:
    /// `SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Your Path"))`
    /// - Parameter pathComponent: The path to append to the platform-specific defatult storage directory.
    static func `default`(appendingPath pathComponent: String) -> SQLiteStorageEngine {
        SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: pathComponent))!
    }

}
