import XCTest
@testable import Bodega

final class DiskStorageEngineTests: XCTestCase {

    private var storage: DiskStorageEngine!

    override func setUp() async throws {
        storage = DiskStorageEngine(directory: .temporary(appendingPath: "Tests"))

        try await storage.removeAllData()
    }

    func testWritingDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)

        XCTAssertEqual(readData, Self.testData)

        // Test overwriting data
        let updatedTestData = Data("updated-data".utf8)
        try await storage.write(updatedTestData, key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)

        XCTAssertNotEqual(readData, updatedData)
    }

    func testWritingDataAndKeysSucceeds() async throws {
        try await storage.write(Self.storedKeysAndData)

        let itemCount = await storage.keyCount()
        XCTAssertEqual(itemCount, 4)

        let readKeysAndObjects: [(key: CacheKey, data: Data)] = await storage.readAllDataAndKeys()
            .sorted(by: { String(data: $0.data, encoding: .utf8)! < String(data: $1.data, encoding: .utf8)! })

        XCTAssertEqual(Self.storedKeysAndData.map(\.key), readKeysAndObjects.map(\.key))
        XCTAssertEqual(Self.storedKeysAndData.map(\.data), readKeysAndObjects.map(\.data))
    }

    func testReadingDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)
        XCTAssertEqual(readData, Self.testData)
    }

    func testReadingArrayOfDataSucceeds() async throws {
        try await self.writeItemsToDisk(count: 10)
        let keyCount = await storage.keyCount()
        XCTAssertEqual(keyCount, 10)

        let firstTwoValues = await storage.read(keys: [CacheKey(verbatim: "0"), CacheKey(verbatim: "1")])
        let firstTwoStrings = firstTwoValues.map({ String(data: $0, encoding: .utf8) })

        XCTAssertEqual(firstTwoStrings, [
            "Value 0",
            "Value 1"
        ])
    }

    func testReadingDataAndKeysSucceeds() async throws {
        try await self.writeItemsToDisk(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        let lastTwoKeys = Array(allKeys.suffix(2))
        let lastTwoKeysAndData = await storage.readDataAndKeys(keys: lastTwoKeys)

        // Testing that the keys returned are correct
        XCTAssertEqual(lastTwoKeysAndData.map(\.key), [
            CacheKey(verbatim: "8"),
            CacheKey(verbatim: "9"),
        ])

        // Testing that the data returned is correct
        XCTAssertEqual(lastTwoKeysAndData.map(\.data).map({ String(data: $0, encoding: .utf8) }), [
            "Value 8",
            "Value 9"
        ])
    }

    func testReadingAllDataSucceeds() async throws {
        try await self.writeItemsToDisk(count: 10)

        let allData = await storage.readAllData()
        let allStrings = allData
            .map({ String(data: $0, encoding: .utf8)! })
            .sorted(by: { $0 < $1 } )

        XCTAssertEqual(allData.count, 10)
        XCTAssertEqual([
            allStrings[0],
            allStrings[3],
            allStrings[6],
            allStrings[9],
        ], [
            "Value 0",
            "Value 3",
            "Value 6",
            "Value 9"
        ])
    }

    func testReadingAllDataAndKeysSucceeds() async throws {
        try await self.writeItemsToDisk(count: 10)

        let allKeysAndData = await storage.readAllDataAndKeys()
        XCTAssertEqual(allKeysAndData.count, 10)

        let keysDerivedFromKeysAndData = allKeysAndData
            .map(\.key)
            .sorted(by: { $0.value < $1.value } )

        let stringsDerivedFromKeysAndData = allKeysAndData.map(\.data)
            .map({ String(data: $0, encoding: .utf8)! })
            .sorted(by: { $0 < $1 } )

        XCTAssertEqual([
            keysDerivedFromKeysAndData[0],
            keysDerivedFromKeysAndData[5],
            keysDerivedFromKeysAndData[9],
        ], [
            CacheKey(verbatim: "0"),
            CacheKey(verbatim: "5"),
            CacheKey(verbatim: "9"),
        ])

        XCTAssertEqual([
            stringsDerivedFromKeysAndData[1],
            stringsDerivedFromKeysAndData[4],
            stringsDerivedFromKeysAndData[7],
        ], [
            "Value 1",
            "Value 4",
            "Value 7",
        ])
    }

    func testReadingMissingData() async throws {
        let readData = await storage.read(key: CacheKey(verbatim: "fake-key"))
        XCTAssertNil(readData)
    }

    func testRemoveDataSucceeds() async throws {
        // Test removing an object based on it's key
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)
        XCTAssertNotNil(readData)

        try await storage.remove(key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)
        XCTAssertNil(updatedData)

        // Test removing multiple keys
        let storedKeysAndData = Self.storedKeysAndData
        try await storage.write(storedKeysAndData)

        try await storage.remove(keys: [
            storedKeysAndData[0].key,
            storedKeysAndData[1].key,
            storedKeysAndData[2].key,
        ])

        let allData = await storage.readAllDataAndKeys()
        XCTAssertEqual(allData[0].key, storedKeysAndData[3].key)
        XCTAssertEqual(allData[0].data, storedKeysAndData[3].data)
    }

    func testRemoveAllData() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let keyCount = await storage.keyCount()
        XCTAssertEqual(keyCount, 1)

        try await storage.removeAllData()
        let updatedKeyCount = await storage.keyCount()
        XCTAssertEqual(updatedKeyCount, 0)
    }

    func testRemovingNonExistentObjectDoesNotError() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        try await storage.remove(key: CacheKey(verbatim: "alternative-test-key"))

        let readData = await storage.read(key: Self.testCacheKey)
        XCTAssertEqual(readData, Self.testData)
    }

    func testKeyCount() async throws {
        let keyCount = await storage.keyCount()

        XCTAssertEqual(keyCount, 0)

        try await self.writeItemsToDisk(count: 10)
        let updatedKeyCount = await storage.keyCount()
        XCTAssertEqual(updatedKeyCount, 10)

        // Overwriting data in the same cache keys and ensuring that the count doesn't change
        try await self.writeItemsToDisk(count: 10)
        let overwrittenKeyCount = await storage.keyCount()
        XCTAssertEqual(overwrittenKeyCount, 10)
    }

    func testKeyExists() async throws {
        let cacheKeyExistsBeforeAddingData = await storage.keyExists(Self.testCacheKey)
        XCTAssertFalse(cacheKeyExistsBeforeAddingData)

        try await storage.write(Self.testData, key: Self.testCacheKey)
        let cacheKeyExistsAfterAddingData = await storage.keyExists(Self.testCacheKey)
        XCTAssertTrue(cacheKeyExistsAfterAddingData)

        try await storage.remove(key: Self.testCacheKey)
        let cacheKeyExistsAfterRemovingData = await storage.keyExists(Self.testCacheKey)
        XCTAssertFalse(cacheKeyExistsAfterRemovingData)
    }

    func testAllKeys() async throws {
        try await self.writeItemsToDisk(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allKeys[0].value, "0")
        XCTAssertEqual(allKeys[3].value, "3")
        XCTAssertEqual(allKeys.count, 10)
    }

    // Unlike most StorageEngines when a DiskStorage rewrites data the createdAt changes.
    // Since we are overwriting a file, a new file is created, with a new createdAt.
    func testCreatedAtDate() async throws {
        // Make sure the createdAt is nil if the key hasn't been stored
        let initialCreatedAt = await storage.createdAt(key: Self.testCacheKey)
        XCTAssertNil(initialCreatedAt)

        // Make sure the createdAt is in the right range if it has been stored
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let firstWriteDate = await storage.createdAt(key: Self.testCacheKey)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the createdAt date is not updated when the data is re-written
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let secondWriteDate = await storage.createdAt(key: Self.testCacheKey)

        // DiskStorageEngine will overwrite the original data so unlike other engines
        // a new `createdAt` will be generated on write.
        XCTAssertNotEqual(firstWriteDate, secondWriteDate)
    }

    func testUpdatedAtDate() async throws {
        // Make sure the updatedAt is nil if the key hasn't been stored
        let initialUpdatedAt = await storage.updatedAt(key: Self.testCacheKey)
        XCTAssertNil(initialUpdatedAt)

        // Make sure the updatedAt is in the right range if it has been stored
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let firstWriteDate = await storage.updatedAt(key: Self.testCacheKey)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the updatedAt date is updated when the data is re-written
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let secondWriteDate = await storage.updatedAt(key: Self.testCacheKey)

        XCTAssertNotEqual(firstWriteDate, secondWriteDate)
    }
    
    func testLastAccessDate() async throws {
        // Make sure lastAccessed is nil if the key hasn't been stored
        var accessDate = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertNil(accessDate)
        
        // Make sure lastAccessed is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        accessDate = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        XCTAssertLessThanOrEqual(accessDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // Make sure lastAccessed is updated when the data is read
        dateBefore = Date()
        let data = await storage.read(key: Self.testCacheKey)
        dateAfter = Date()
        XCTAssertEqual(data, Self.testData)
        accessDate = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        // Note that there is a slight delay between reading the data and the access time,
        // so we need to allow for that.
        XCTAssertLessThanOrEqual(accessDate!, dateAfter.addingTimeInterval(0.001))
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // Make sure fetching the access date doesn't change the access date
        let accessDate2 = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertEqual(accessDate, accessDate2)
    }

}

private extension DiskStorageEngineTests {

    static let testData = Data("Test".utf8)
    static let testCacheKey = CacheKey(verbatim: "test-key")

    static let storedKeysAndData: [(key: CacheKey, data: Data)] = [
        (CacheKey(verbatim: "1"), Data("Value 1".utf8)),
        (CacheKey(verbatim: "2"), Data("Value 2".utf8)),
        (CacheKey(verbatim: "3"), Data("Value 3".utf8)),
        (CacheKey(verbatim: "4"), Data("Value 4".utf8))
    ]

    func writeItemsToDisk(count: Int) async throws {
        for i in 0..<count {
            // This encoding could fail in some use cases but we're going to use very simple strings for testing
            try await storage.write("Value \(i)".data(using: .utf8)!, key: CacheKey(verbatim: "\(i)"))
        }
    }

}
