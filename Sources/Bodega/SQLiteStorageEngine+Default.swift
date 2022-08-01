public extension SQLiteStorageEngine {

    static var `default`: SQLiteStorageEngine {
        SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Data"))!
    }

    static func `default`(appendingPath pathComponent: String) -> SQLiteStorageEngine {
        SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: pathComponent))!
    }

}
