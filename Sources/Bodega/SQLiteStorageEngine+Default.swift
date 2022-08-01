public extension SQLiteStorageEngine {

    static var `default`: SQLiteStorageEngine {
        SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Data"))!
    }

}
