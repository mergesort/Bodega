import XCTest
@testable import Bodega

final class DiskStorageTests: XCTestCase {

    private var storage: DiskStorage!

    override func setUp() async throws {
        storage = DiskStorage(storagePath: Self.testStoragePath)
        try await storage.removeAllData()
    }

    func testWriteDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)

        XCTAssert(readData == Self.testData)

        // Test overwriting data
        let updatedTestData = Data("Updated Test Data".utf8)
        try await storage.write(updatedTestData, key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)

        XCTAssertNotEqual(readData, updatedData)
    }

    func testReadingMissingData() async throws {
        let readData = await storage.read(key: CacheKey(verbatim: "fake-key"))
        XCTAssertNil(readData)
    }

    func testSubdirectoryResolves() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: "test-subdirectory")
        let readData = await storage.read(key: Self.testCacheKey, subdirectory: "test-subdirectory")

        XCTAssert(readData == Self.testData)

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
        let keyCount = await storage.allKeys().count
        XCTAssert(keyCount == 1)

        try await storage.removeAllData()
        let updatedKeyCount = await storage.allKeys().count
        XCTAssert(updatedKeyCount == 0)

        let subdirectory = "subdirectory"
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssert(subdirectoryKeyCount == 1)

        try await storage.removeAllData()
        let updatedSubdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssert(updatedSubdirectoryKeyCount == 0)
    }

    func testRemovingNonExistentObjectDoesNotError() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        try await storage.remove(key: CacheKey(verbatim: "alternative-test-key"))

        let readData = await storage.read(key: Self.testCacheKey)
        XCTAssert(readData == Self.testData)
    }

    func testKeyCount() async throws {
        let keyCount = await storage.keyCount()

        XCTAssert(keyCount == 0)

        try await self.writeCacheKeys(count: 10)
        let updatedKeyCount = await storage.keyCount()
        XCTAssert(updatedKeyCount == 10)

        // Overwriting data in the same cache keys and ensuring that the count doesn't change
        try await self.writeCacheKeys(count: 10)
        let overwrittenKeyCount = await storage.keyCount()
        XCTAssert(overwrittenKeyCount == 10)

        let subdirectory = "subdirectory"
        try await storage.write(Self.testData, key: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssert(subdirectoryKeyCount == 1)

        // Ensure that subdirectories are not treated as additional keys
        let directoryAfterAddingSubdirectoryKeyCount = await storage.allKeys().count
        XCTAssert(directoryAfterAddingSubdirectoryKeyCount == 10)
    }

    func testAllKeys() async throws {
        try await self.writeCacheKeys(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        XCTAssert(allKeys[0].value == "0")
        XCTAssert(allKeys[3].value == "3")
        XCTAssert(allKeys.count == 10)
    }
    
    func testModificationDate() async throws {
        // Make sure the modificationDate is nil if the key hasn't been stored
        var modificationDate = await storage.modificationDate(key: Self.testCacheKey)
        XCTAssertNil(modificationDate)
        
        // Make sure the modification date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        modificationDate = await storage.modificationDate(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure the modification date is updated when the data is re-written
        dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        dateAfter = Date()
        modificationDate = await storage.modificationDate(key: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
    }
    
    func testAccessDate() async throws {
        // Make sure the accessDate is nil if the key hasn't been stored
        var accessDate = await storage.accessDate(key: Self.testCacheKey)
        XCTAssertNil(accessDate)
        
        // Make sure the access date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.write(Self.testData, key: Self.testCacheKey)
        var dateAfter = Date()
        accessDate = await storage.accessDate(key: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        XCTAssertLessThanOrEqual(accessDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure the access date is updated when the data is read
        dateBefore = Date()
        let data = await storage.read(key: Self.testCacheKey)
        dateAfter = Date()
        XCTAssert(data == Self.testData)
        accessDate = await storage.accessDate(key: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        // Note that there is a slight delay between reading the data and the access time,
        // so we need to allow for that.
        XCTAssertLessThanOrEqual(accessDate!, dateAfter.addingTimeInterval(0.001))
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure fetching the access date doesn't change the access date
        let accessDate2 = await storage.accessDate(key: Self.testCacheKey)
        XCTAssertEqual(accessDate, accessDate2)
    }

}

private extension DiskStorageTests {

    static let testData = Data("Test".utf8)
    static let testCacheKey = CacheKey(verbatim: "test-key")
    static let pathComponent = "Test"
    static let testStoragePath = DiskStorage.temporaryDirectory(appendingPath: DiskStorageTests.pathComponent)

    func writeCacheKeys(count: Int) async throws {
        for i in 0..<count {
            try await storage.write(Self.testData, key: CacheKey(verbatim: "\(i)"))
        }
    }

}
