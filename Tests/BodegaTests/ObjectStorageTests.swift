import XCTest
@testable import Bodega

final class ObjectStorageTests: XCTestCase {

    private var storage: ObjectStorage!

    override func setUp() async throws {
        storage = ObjectStorage(directory: Self.testDirectory)
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

    func testWritingObjectsAndKeysSucceeds() async throws {
        try await storage.store(Self.storedKeysAndObjects)

        let objectCount = await storage.keyCount()
        XCTAssertEqual(objectCount, 4)

        let readKeysAndObjects: [(key: CacheKey, object: CodableObject)] = await storage.allObjectsAndKeys()
            .sorted(by: { $0.object.value < $1.object.value })

        XCTAssertEqual(Self.storedKeysAndObjects.map(\.key), readKeysAndObjects.map(\.key))
        XCTAssertEqual(Self.storedKeysAndObjects.map(\.object), readKeysAndObjects.map(\.object))
    }

    func testReadingObjectSucceeds() async throws {
        // Read one object
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssertEqual(readObject, Self.testObject)
    }

    func testReadingArrayOfObjectsSucceds() async throws {
        try await self.writeObjectsToDisk(count: 10)
        let keyCount = await storage.keyCount()
        XCTAssertEqual(keyCount, 10)

        // Read an array of objects
        let objects: [CodableObject] = await storage.objects(forKeys: [CacheKey(verbatim: "0"), CacheKey(verbatim: "1")])
        let objectValues = objects.map(\.value)

        XCTAssertEqual(objectValues, [
            "Value 0",
            "Value 1"
        ])
    }

    func testReadingObjectsAndKeysSucceeds() async throws {
        try await self.writeObjectsToDisk(count: 10)

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
            "Value 8",
            "Value 9"
        ])
    }

    func testReadingAllObjectsSucceeds() async throws {
        try await self.writeObjectsToDisk(count: 10)

        let allObjects: [CodableObject] = await storage.allObjects().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allObjects.count, 10)
        XCTAssertEqual([
            allObjects[0].value,
            allObjects[3].value,
            allObjects[6].value,
            allObjects[9].value,
        ], [
            "Value 0",
            "Value 3",
            "Value 6",
            "Value 9"
        ])
    }

    func testReadingAllObjectsAndKeysSucceeds() async throws {
        try await self.writeObjectsToDisk(count: 10)

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
            "Value 1",
            "Value 4",
            "Value 7",
        ])
    }

    func testReadingMissingObject() async throws {
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
        XCTAssertNil(readObject)
    }

    func testRemoveObjectSucceeds() async throws {
        // Test removing an object based on it's key
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNotNil(readObject)

        try await storage.removeObject(forKey: Self.testCacheKey)
        let updatedObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)

        XCTAssertNil(updatedObject)

        // Test removing multiple keys
        let storedKeysAndData = Self.storedKeysAndObjects
        try await storage.store(storedKeysAndData)

        try await storage.removeObject(forKeys: [
            storedKeysAndData[0].key,
            storedKeysAndData[1].key,
            storedKeysAndData[2].key,
        ])

        let allData: [(key: CacheKey, object: CodableObject)] = await storage.allObjectsAndKeys()
        XCTAssertEqual(allData[0].key, storedKeysAndData[3].key)
        XCTAssertEqual(allData[0].object, storedKeysAndData[3].object)

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

}

private struct CodableObject: Codable, Equatable {
    let value: String
}

private extension ObjectStorageTests {

    static let testObject = CodableObject(value: "default-value")
    static let testCacheKey = CacheKey("test-key")
    static let pathComponent = "Test"
    static let testDirectory = FileManager.Directory.temporary(appendingPath: ObjectStorageTests.pathComponent)

    static let storedKeysAndObjects: [(key: CacheKey, object: CodableObject)] = [
        (CacheKey(verbatim: "1"), CodableObject(value: "Value 1")),
        (CacheKey(verbatim: "2"), CodableObject(value: "Value 2")),
        (CacheKey(verbatim: "3"), CodableObject(value: "Value 3")),
        (CacheKey(verbatim: "4"), CodableObject(value: "Value 4"))
    ]

    func writeObjectsToDisk(count: Int) async throws {
        for i in 0..<count {
            try await storage.store(CodableObject(value: "Value \(i)"), forKey: CacheKey(verbatim: "\(i)"))
        }
    }

}
