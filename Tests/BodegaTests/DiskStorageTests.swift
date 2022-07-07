import XCTest
@testable import Bodega

final class DiskStorageTests: XCTestCase {

    private var storage: DiskStorage!

    override func setUp() async throws {
        storage = DiskStorage(storagePath: Self.testStoragePath)
        try await storage.removeAllData()
    }

    func testWritingDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)

        XCTAssertEqual(readData, Self.testData)

        // Test overwriting data
        let updatedTestData = Data("Updated Test Data".utf8)
        try await storage.write(updatedTestData, key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)

        XCTAssertNotEqual(readData, updatedData)
    }

    func testReadingDataSucceeds() async throws {
        // Read one piece of data
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)
        XCTAssertEqual(readData, Self.testData)

        // Remove all the data to create a clean slate
        try await storage.removeAllData()

        // Write some test data to a subdirectory
        let subdirectory = "subdirectory"
        try await self.writeItemsToDisk(count: 10, subdirectory: subdirectory)
        let keyCount = await storage.keyCount(inSubdirectory: subdirectory)
        XCTAssertEqual(keyCount, 10)

        // Read an array of data
        let firstTwoValues = await storage.read(keys: [CacheKey(verbatim: "0"), CacheKey(verbatim: "1")], subdirectory: subdirectory)
        let firstTwoStrings = firstTwoValues.map({ String(data: $0, encoding: .utf8) })

        XCTAssertEqual(firstTwoStrings, [
            "Value 0",
            "Value 1"
        ])

        // Write some more test data to storage root
        try await self.writeItemsToDisk(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        // Read all data with method that also provides CacheKeys
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

        // Reading all data
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

        // Reading all data with the read method variant that also provides CacheKeys
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

    func testSubdirectoryResolves() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: "test-subdirectory")
        let readData = await storage.read(key: Self.testCacheKey, subdirectory: "test-subdirectory")

        XCTAssertEqual(readData, Self.testData)

        let incorrectSubdirectoryData = await storage.read(key: Self.testCacheKey, subdirectory: "fake-subdirectory")
        XCTAssertNil(incorrectSubdirectoryData)
    }

    func testRemoveDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)

        XCTAssertNotNil(readData)

        try await storage.remove(key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)

        XCTAssertNil(updatedData)
    }

    func testRemoveAllData() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let keyCount = await storage.keyCount()
        XCTAssertEqual(keyCount, 1)

        try await storage.removeAllData()
        let updatedKeyCount = await storage.keyCount()
        XCTAssertEqual(updatedKeyCount, 0)

        let subdirectory = "subdirectory"
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.keyCount(inSubdirectory: subdirectory)
        XCTAssertEqual(subdirectoryKeyCount, 1)

        try await storage.removeAllData()
        let updatedSubdirectoryKeyCount = await storage.keyCount(inSubdirectory: subdirectory)
        XCTAssertEqual(updatedSubdirectoryKeyCount, 0)
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

        let subdirectory = "subdirectory"
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.keyCount(inSubdirectory: subdirectory)
        XCTAssertEqual(subdirectoryKeyCount, 1)

        // Ensure that subdirectories are not treated as additional keys
        let directoryAfterAddingSubdirectoryKeyCount = await storage.keyCount()
        XCTAssertEqual(directoryAfterAddingSubdirectoryKeyCount, 10)
    }

    func testAllKeys() async throws {
        try await self.writeItemsToDisk(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allKeys[0].value, "0")
        XCTAssertEqual(allKeys[3].value, "3")
        XCTAssertEqual(allKeys.count, 10)
    }

    func testCreationDate() async throws {
        // Make sure the modificationDate is nil if the key hasn't been stored
        var modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNil(modificationDate)

        // Make sure the modification date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the modification date is updated when the data is re-written
        dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        dateAfter = Date()
        modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
    }

    func testLastModifiedDate() async throws {
        // Make sure the modificationDate is nil if the key hasn't been stored
        var modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNil(modificationDate)
        
        // Make sure the modification date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // Make sure the modification date is updated when the data is re-written
        dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        dateAfter = Date()
        modificationDate = await storage.lastModified(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
    }
    
    func testLastAccessDate() async throws {
        // Make sure the accessDate is nil if the key hasn't been stored
        var accessDate = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertNil(accessDate)
        
        // Make sure the access date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        accessDate = await storage.lastAccessed(key: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        XCTAssertLessThanOrEqual(accessDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // Make sure the access date is updated when the data is read
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

private extension DiskStorageTests {

    static let testData = Data("Test".utf8)
    static let testCacheKey = CacheKey(verbatim: "test-key")
    static let pathComponent = "Test"
    static let testStoragePath = DiskStorage.temporaryDirectory(appendingPath: DiskStorageTests.pathComponent)

    func writeItemsToDisk(count: Int, subdirectory: String? = nil) async throws {
        for i in 0..<count {
            // This encoding could fail in some use cases but we're going to use very simple strings for testing
            try await storage.write("Value \(i)".data(using: .utf8)!, key: CacheKey(verbatim: "\(i)"), subdirectory: subdirectory)
        }
    }

}
