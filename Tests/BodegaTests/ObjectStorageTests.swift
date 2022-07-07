import XCTest
@testable import Bodega

final class ObjectStorageTests: XCTestCase {

    private var storage: ObjectStorage!

    override func setUp() async throws {
        storage = ObjectStorage(storagePath: Self.testStoragePath)
        try await storage.removeAllObjects()
    }

    func testWritingObjectSucceeds() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertEqual(readObject, Self.testObject)

        // Test overwriting an object
        let updatedTestObject = CodableObject(value: "updated-value")
        try await storage.store(updatedTestObject, forKey: Self.testCacheKey)
        let updatedObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNotEqual(readObject, updatedObject)
    }

    func testReadingObjectsSucceeds() async throws {
        // Read one object
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssertEqual(readObject, Self.testObject)

        // Remove all the objects to create a clean slate
        try await storage.removeAllObjects()

        // Write some more test objects to a subdirectory
        let subdirectory = "subdirectory"
        try await self.writeObjectsToDisk(count: 10, subdirectory: subdirectory)
        let keyCount = await storage.keyCount(inSubdirectory: subdirectory)
        XCTAssertEqual(keyCount, 10)

        // Read an array of objects
        let objects: [CodableObject] = await storage.objects(forKeys: [CacheKey(verbatim: "0"), CacheKey(verbatim: "1")], subdirectory: subdirectory)
        let objectValues = objects.map(\.value)

        XCTAssertEqual(objectValues, [
            "Test 0",
            "Test 1"
        ])

        // Write some more test data to storage root
        try await self.writeObjectsToDisk(count: 10)

        // Read all data with method that also provides CacheKeys
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })
        let lastTwoKeys = Array(allKeys.suffix(2))
        let lastTwoCacheKeysAndObjects: [(key: CacheKey, object: CodableObject)] = await storage.objectsAndKeys(keys: lastTwoKeys)

        // Testing that the keys returned are correct
        XCTAssertEqual(lastTwoCacheKeysAndObjects.map(\.key), [
            CacheKey(verbatim: "8"),
            CacheKey(verbatim: "9"),
        ])

        // Testing that the objects returned are correct
        XCTAssertEqual(lastTwoCacheKeysAndObjects.map(\.object.value), [
            "Test 8",
            "Test 9"
        ])

        // Reading all objects
        let allObjects: [CodableObject] = await storage.allObjects().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allObjects.count, 10)
        XCTAssertEqual([
            allObjects[0].value,
            allObjects[3].value,
            allObjects[6].value,
            allObjects[9].value,
        ], [
            "Test 0",
            "Test 3",
            "Test 6",
            "Test 9"
        ])

        // Reading all objects with the read method variant that also provides CacheKeys
        let allKeysAndObjects: [(key: CacheKey, object: CodableObject)] = await storage.allObjectsAndKeys()
        XCTAssertEqual(allKeysAndObjects.count, 10)

        let keysDerivedFromKeysAndObjects = allKeysAndObjects.map(\.key)
            .sorted(by: { $0.value < $1.value } )

        let objectsDerivedFromKeysAndObjects = allKeysAndObjects.map(\.object)
            .sorted(by: { $0.value < $1.value })

        XCTAssertEqual([
            keysDerivedFromKeysAndObjects[0],
            keysDerivedFromKeysAndObjects[5],
            keysDerivedFromKeysAndObjects[9],
        ], [
            CacheKey(verbatim: "0"),
            CacheKey(verbatim: "5"),
            CacheKey(verbatim: "9"),
        ])

        XCTAssertEqual([
            objectsDerivedFromKeysAndObjects[1].value,
            objectsDerivedFromKeysAndObjects[4].value,
            objectsDerivedFromKeysAndObjects[7].value,
        ], [
            "Test 1",
            "Test 4",
            "Test 7",
        ])
    }

    func testReadingMissingObject() async throws {
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssertNil(readObject)
    }

    func testSubdirectoryResolves() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: "test-subdirectory")
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey, subdirectory: "test-subdirectory")

        XCTAssertEqual(readObject, Self.testObject)

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
        XCTAssertEqual(readObject, Self.testObject)
    }

    func testRemoveAllObjects() async throws {
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let keyCount = await storage.allKeys().count
        XCTAssertEqual(keyCount, 1)

        try await storage.removeAllObjects()
        let updatedKeyCount = await storage.allKeys().count
        XCTAssertEqual(updatedKeyCount, 0)

        let subdirectory = "subdirectory"
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssertEqual(subdirectoryKeyCount, 1)

        try await storage.removeAllObjects()
        let updatedSubdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssertEqual(updatedSubdirectoryKeyCount, 0)
    }

    func testKeyCount() async throws {
        let keyCount = await storage.keyCount()

        XCTAssertEqual(keyCount, 0)

        try await self.writeObjectsToDisk(count: 10)
        let updatedKeyCount = await storage.keyCount()
        XCTAssertEqual(updatedKeyCount, 10)

        // Overwriting an object in the same cache keys and ensuring that the count doesn't change
        try await self.writeObjectsToDisk(count: 10)
        let overwrittenKeyCount = await storage.keyCount()
        XCTAssertEqual(overwrittenKeyCount, 10)

        let subdirectory = "subdirectory"
        try await storage.store(Self.testObject, forKey: Self.testCacheKey, subdirectory: subdirectory)

        let subdirectoryKeyCount = await storage.allKeys(inSubdirectory: subdirectory).count
        XCTAssertEqual(subdirectoryKeyCount, 1)

        // Ensure that subdirectories are not treated as additional keys
        let directoryAfterAddingSubdirectoryKeyCount = await storage.allKeys().count
        XCTAssertEqual(directoryAfterAddingSubdirectoryKeyCount, 10)
    }

    func testAllKeys() async throws {
        try await self.writeObjectsToDisk(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allKeys[0].value, "0")
        XCTAssertEqual(allKeys[3].value, "3")
        XCTAssertEqual(allKeys.count, 10)
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

        try await Task.sleep(nanoseconds: 1_000_000)

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
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
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
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
        // Make sure the access date is updated when the data is read
        dateBefore = Date()
        let object: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        dateAfter = Date()
        XCTAssertEqual(object, Self.testObject)
        accessDate = await storage.lastAccessed(forKey: Self.testCacheKey)
        XCTAssertNotNil(accessDate)
        XCTAssertLessThanOrEqual(dateBefore, accessDate!)
        // Note that there is a slight delay between reading the data and the access time,
        // so we need to allow for that.
        XCTAssertLessThanOrEqual(accessDate!, dateAfter.addingTimeInterval(0.001))
        
        try await Task.sleep(nanoseconds: 1_000_000)
        
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

    func writeObjectsToDisk(count: Int, subdirectory: String? = nil) async throws {
        for i in 0..<count {
            try await storage.store(CodableObject(value: "Test \(i)"), forKey: CacheKey(verbatim: "\(i)"), subdirectory: subdirectory)
        }
    }

}
