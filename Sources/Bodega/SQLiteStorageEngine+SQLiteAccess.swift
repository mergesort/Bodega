import Foundation
import SQLite3

extension SQLiteStorageEngine {
    // Contains SQLite access code.
    // These are all synchronous calls that share the same `OpaquePointer` value to the database. In order to guarantee
    // that access only happens in order, these methods need to be used within `CheckedContinuation` calls.
    // The raw SQLite commands are included inside of each method here in order to simplify readability.
    enum SQLite {}
}

extension SQLiteStorageEngine.SQLite {
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    enum SQLiteDatabaseError: Error {
        case unableToOpenDatabaseConnection
        case unableToCloseDatabaseConnection
    }

    enum SQLiteError: Error {
        case noDataForKey(String)
        case prepareFailed(Int32)
        case createFailed(Int32)
        case insertFailed(Int32)
        case deleteFailed(Int32)
        case queryFailed(Int32)
        case updateFailed(Int32)
    }

    enum Column: String, CaseIterable {
        case key
        case value
        case createdAt
        case updatedAt
    }

    enum DateColumn {
        case createdAt
        case updatedAt

        var asColumn: Column {
            switch self {
            case .createdAt:
                return .createdAt
            case .updatedAt:
                return .updatedAt
            }
        }
    }

    static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withFullDate,
            .withFullTime,
            .withFractionalSeconds,
        ]
        return formatter
    }
}

extension SQLiteStorageEngine.SQLite {
    static func prepareDatabase(_ databasePointer: OpaquePointer?, forCommand command: String, statementPointer: inout OpaquePointer?) throws {
        let result = sqlite3_prepare_v2(databasePointer, command, -1, &statementPointer, nil)
        guard result == SQLITE_OK else {
            throw SQLiteError.prepareFailed(result)
        }
    }

    // MARK: - CREATE TABLE

    static func createTableNamed(_ tableName: String, inDatabase database: OpaquePointer?) throws {
        let command = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            "\(Column.key.rawValue)" TEXT PRIMARY KEY NOT NULL,
            "\(Column.value.rawValue)" BLOB NOT NULL,
            "\(Column.createdAt.rawValue)" TEXT NOT NULL,
            "\(Column.updatedAt.rawValue)" TEXT NOT NULL
        )
        """
        var createTableStatement: OpaquePointer?
        try prepareDatabase(database, forCommand: command, statementPointer: &createTableStatement)
        let createResult = sqlite3_step(createTableStatement)
        guard createResult == SQLITE_DONE else {
            throw SQLiteError.createFailed(createResult)
        }
        sqlite3_finalize(createTableStatement)
    }

    // MARK: - INERT

    static func writeDataAndKeys(_ dataAndKeys: [(key: CacheKey, data: Data)], toTableNamed tableName: String, inDatabase database: OpaquePointer?) throws {
        let command = """
        INSERT INTO \(tableName)
            (\(Column.allCases.map(\.rawValue).joined(separator: ", ")))
        VALUES
            (\(Array(repeating: "?", count: Column.allCases.count).joined(separator: ", ")))
        ON CONFLICT (\(Column.key.rawValue)) DO UPDATE SET
            \(Column.value.rawValue) = EXCLUDED.\(Column.value.rawValue),
            \(Column.updatedAt.rawValue) = EXCLUDED.\(Column.updatedAt.rawValue)
        """
        var insertStatement: OpaquePointer?
        try prepareDatabase(database, forCommand: command, statementPointer: &insertStatement)
        let currentDateString = Self.dateFormatter.string(from: Date())
        for entry in dataAndKeys {
            let bytes = [UInt8](entry.data)
            sqlite3_bind_text(insertStatement, 1, strdup(entry.key.rawValue), -1, SQLITE_TRANSIENT)
            sqlite3_bind_blob(insertStatement, 2, bytes, Int32(bytes.count), SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement, 3, strdup(currentDateString), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(insertStatement, 4, strdup(currentDateString), -1, SQLITE_TRANSIENT)
            let result = sqlite3_step(insertStatement)
            guard result == SQLITE_DONE else {
                throw SQLiteError.insertFailed(result)
            }
            sqlite3_reset(insertStatement)
        }
        sqlite3_finalize(insertStatement)
    }

    // MARK: - DELETE

    static func deleteKeys(_ keys: [CacheKey], fromTable tableName: String, inDatabase database: OpaquePointer?) throws {
        let command = """
        DELETE FROM
            \(tableName)
        WHERE
            \(Column.key.rawValue) IN (\(Array(repeating: "?", count: keys.count).joined(separator: ", ")))
        LIMIT
            \(keys.count)
        """
        var removeStatement: OpaquePointer?
        try prepareDatabase(database, forCommand: command, statementPointer: &removeStatement)
        for (index, key) in keys.enumerated() {
            sqlite3_bind_text(removeStatement, Int32(index + 1), strdup(key.rawValue), -1, SQLITE_TRANSIENT)
        }
        let result = sqlite3_step(removeStatement)
        guard result == SQLITE_DONE else {
            throw SQLiteError.deleteFailed(result)
        }
        sqlite3_finalize(removeStatement)
    }

    static func emptyTableNamed(_ tableName: String, inDatabase database: OpaquePointer?) throws {
        let command = """
        DELETE FROM
            \(tableName)
        """
        var deleteStatement: OpaquePointer?
        try prepareDatabase(database, forCommand: command, statementPointer: &deleteStatement)
        let result = sqlite3_step(deleteStatement)
        guard result == SQLITE_DONE else {
            throw SQLiteError.deleteFailed(result)
        }
        sqlite3_finalize(deleteStatement)
    }

    // MARK: - SELECT

    static func selectKeys(_ keys: [CacheKey], inTable tableName: String, inDatabase database: OpaquePointer?) -> [(key: CacheKey, data: Data)] {
        let command = """
        SELECT
            \(Column.key.rawValue), \(Column.value.rawValue)
        FROM
            \(tableName)
        WHERE
            \(Column.key.rawValue) IN (\(Array(repeating: "?", count: keys.count).joined(separator: ", ")))
        LIMIT
            \(keys.count)
        """
        do {
            var selectStatement: OpaquePointer?
            try prepareDatabase(database, forCommand: command, statementPointer: &selectStatement)
            for (index, key) in keys.enumerated() {
                sqlite3_bind_text(selectStatement, Int32(index + 1), strdup(key.rawValue), -1, SQLITE_TRANSIENT)
            }
            var collector = [(key: CacheKey, data: Data)]()
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                guard
                    let rawKey = sqlite3_column_text(selectStatement, 0),
                    let valueBlob = sqlite3_column_blob(selectStatement, 1)
                else {
                    continue
                }
                let valueLength = Int(sqlite3_column_bytes(selectStatement, 1))
                let valuePointer = UnsafeBufferPointer(
                    start: valueBlob.assumingMemoryBound(to: UInt8.self),
                    count: valueLength
                )
                collector.append(
                    (CacheKey(verbatim: String(cString: rawKey)), Data(valuePointer))
                )
            }
            sqlite3_finalize(selectStatement)
            return collector
        } catch {
            return []
        }
    }

    static func keyExists(_ key: CacheKey, inTable tableName: String, inDatabase database: OpaquePointer?) throws {
        let command = """
        SELECT
            \(Column.allCases.map(\.rawValue).joined(separator: ", "))
        FROM
            \(tableName)
        WHERE
            EXISTS (
                SELECT
                    1
                FROM
                    \(tableName)
                WHERE
                    \(Column.key.rawValue) = '\(key.rawValue)'
            )
        """
        var queryStatement: OpaquePointer?
        try prepareDatabase(database, forCommand: command, statementPointer: &queryStatement)
        let result = sqlite3_step(queryStatement)
        guard result == SQLITE_ROW else {
            throw SQLiteError.queryFailed(result)
        }
        sqlite3_finalize(queryStatement)
    }

    static func keyCount(inTable tableName: String, inDatabase database: OpaquePointer?) -> Int {
        let command = """
        SELECT
            count(1)
        FROM
            \(tableName)
        """
        do {
            var selectStatement: OpaquePointer?
            try prepareDatabase(database, forCommand: command, statementPointer: &selectStatement)
            var collector: Int32 = 0
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                collector += sqlite3_column_int(selectStatement, 0)
            }
            sqlite3_finalize(selectStatement)
            return Int(collector)
        } catch {
            return 0
        }
    }

    static func selectAllKeys(inTable tableName: String, inDatabase database: OpaquePointer?) -> [CacheKey] {
        let command = """
        SELECT
            \(Column.key.rawValue)
        FROM
            \(tableName)
        """
        do {
            var queryStatement: OpaquePointer?
            try prepareDatabase(database, forCommand: command, statementPointer: &queryStatement)
            var collector = [CacheKey]()
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                guard let rawKey = sqlite3_column_text(queryStatement, 0) else {
                    continue
                }
                collector.append(CacheKey(verbatim: String(cString: rawKey)))
            }
            sqlite3_finalize(queryStatement)
            return collector
        } catch {
            return []
        }
    }

    static func selectDateColumn(_ dateColumn: DateColumn, matchingKeys keys: [CacheKey], inTable tableName: String, inDatabase database: OpaquePointer?) -> [Date] {
        let command = """
        SELECT
            \(dateColumn.asColumn.rawValue)
        FROM
            \(tableName)
        WHERE
            \(Column.key.rawValue) IN (\(Array(repeating: "?", count: keys.count).joined(separator: ", ")))
        LIMIT
            \(keys.count)
        """
        do {
            var selectStatement: OpaquePointer?
            try prepareDatabase(database, forCommand: command, statementPointer: &selectStatement)
            for (index, key) in keys.enumerated() {
                sqlite3_bind_text(selectStatement, Int32(index + 1), strdup(key.rawValue), -1, SQLITE_TRANSIENT)
            }
            var collector = [Date]()
            while sqlite3_step(selectStatement) == SQLITE_ROW {
                guard
                    let rawDateString = sqlite3_column_text(selectStatement, 0),
                    let date = dateFormatter.date(from: String(cString: rawDateString))
                else {
                    continue
                }
                collector.append(date)
            }
            sqlite3_finalize(selectStatement)
            return collector
        } catch {
            return []
        }
    }
}
