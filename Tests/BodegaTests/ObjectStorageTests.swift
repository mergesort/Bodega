import XCTest
@testable import Bodega

final class ObjectStorageTests: XCTestCase {

    private var storage: ObjectStorage!

    override func setUp() async throws {
        storage = ObjectStorage(storagePath: Self.testStoragePath)
        try await storage.removeAllObjects()
    }

    func testWriteObjectSucceeds() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)

        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssert(readObject == Self.testObject)

        // Test overwriting an object
        let updatedTestObject = CodableObject(value: "updated-value")
        try await storage.store(updatedTestObject, forKey: Self.testCacheKey)
        let updatedObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNotEqual(readObject, updatedObject)
    }

    func testReadingMissingObject() async throws {
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssertNil(readObject)
    }

    func testSubdirectoryResolves() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: "test-subdirectory")
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey, subdirectory: "test-subdirectory")

        XCTAssert(readObject == Self.testObject)

        let incorrectSubdirectoryObject: CodableObject? = await storage.object(forKey: Self.testCacheKey, subdirectory: "fake-subdirectory")
        XCTAssertNil(incorrectSubdirectoryObject)
    }

    func testRemoveObjectSucceeds() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNotNil(readObject)

        try await storage.removeObject(forKey: Self.testCacheKey)
        let updatedObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNil(updatedObject)
    }

    func testInvalidRemoveErrors() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        try await storage.removeObject(forKey: CacheKey("alternative-test-key"))

        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssert(readObject == Self.testObject)
    }

    func testRemoveAllObjects() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let keyCount = await storage.allKeys().count
        XCTAssert(keyCount == 1)

        try await storage.removeAllObjects()
        let updatedKeyCount = await storage.allKeys().count
        XCTAssert(updatedKeyCount == 0)

        let subdirectory = "subdirectory"
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssert(subdirectoryKeyCount == 1)

        try await storage.removeAllObjects()
        let updatedSubdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssert(updatedSubdirectoryKeyCount == 0)
    }

    func testKeyCount() async throws {
        let keyCount = await storage.keyCount()

        XCTAssert(keyCount == 0)

        try await self.writeCacheKeys(count: 10)
        let updatedKeyCount = await storage.keyCount()
        XCTAssert(updatedKeyCount == 10)

        // Overwriting an object in the same cache keys and ensuring that the count doesn't change
        try await self.writeCacheKeys(count: 10)
        let overwrittenKeyCount = await storage.keyCount()
        XCTAssert(overwrittenKeyCount == 10)

        let subdirectory = "subdirectory"
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: subdirectory)

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

    func testCreationDate() async throws {
        // Make sure the creationDate is nil if the key hasn't been stored
        var creationDate = await storage.creationDate(forKey: Self.testCacheKey)
        XCTAssertNil(creationDate)

        // Make sure the modification date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        var dateAfter = Date()
        creationDate = await storage.creationDate(forKey: Self.testCacheKey)
        XCTAssertNotNil(creationDate)
        XCTAssertLessThanOrEqual(dateBefore, creationDate!)
        XCTAssertLessThanOrEqual(creationDate!, dateAfter)

        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Make sure the creationDate date is updated when the data is re-written
        dateBefore = Date()
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        dateAfter = Date()
        creationDate = await storage.creationDate(forKey: Self.testCacheKey)
        XCTAssertNotNil(creationDate)
        XCTAssertLessThanOrEqual(dateBefore, creationDate!)
        XCTAssertLessThanOrEqual(creationDate!, dateAfter)
    }

    func testModificationDate() async throws {
        // Make sure the modificationDate is nil if the key hasn't been stored
        var modificationDate = await storage.lastModified(forKey: Self.testCacheKey)
        XCTAssertNil(modificationDate)
        
        // Make sure the modification date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        var dateAfter = Date()
        modificationDate = await storage.lastModified(forKey: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure the modification date is updated when the data is re-written
        dateBefore = Date()
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        dateAfter = Date()
        modificationDate = await storage.lastModified(forKey: Self.testCacheKey)
        XCTAssertNotNil(modificationDate)
        XCTAssertLessThanOrEqual(dateBefore, modificationDate!)
        XCTAssertLessThanOrEqual(modificationDate!, dateAfter)
    }
    
    func testAccessDate() async throws {
        // Make sure the accessDate is nil if the key hasn't been stored
        var accessDate = await storage.lastAccessed(forKey: Self.testCacheKey)
        XCTAssertNil(accessDate)
        
        // Make sure the access date is in the right range if it has been stored
        var dateBefore = Date()
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        var dateAfter = Date()
        accessDate = await storage.lastAccessed(forKey: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        XCTAssertLessThanOrEqual(accessDate!, dateAfter)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure the access date is updated when the data is read
        dateBefore = Date()
        let object: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        dateAfter = Date()
        XCTAssert(object == Self.testObject)
        accessDate = await storage.lastAccessed(forKey: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        // Note that there is a slight delay between reading the data and the access time,
        // so we need to allow for that.
        XCTAssertLessThanOrEqual(accessDate!, dateAfter.addingTimeInterval(0.001))
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Make sure fetching the access date doesn't change the access date
        let accessDate2 = await storage.lastAccessed(forKey: Self.testCacheKey)
        XCTAssertEqual(accessDate, accessDate2)
    }

}

private struct CodableObject: Codable, Equatable {
    let value: String
}

private extension ObjectStorageTests {

    static let testObject = CodableObject(value: "default-value")
    static let testCacheKey = CacheKey("test-key")
    static let pathComponent = "Test"
    static let testStoragePath = DiskStorage.temporaryDirectory(appendingPath: ObjectStorageTests.pathComponent)

    func writeCacheKeys(count: Int) async throws {
        for i in 0..<count {
            try await storage.store(CodableObject(value: "value-\(i)"), forKey: CacheKey(verbatim: "\(i)"))
        }
    }

}
