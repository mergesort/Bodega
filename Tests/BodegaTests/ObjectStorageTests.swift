import XCTest
@testable import Bodega

// Testing an ObjectStorage instance that's backed by a SQLiteStorageEngine
final class SQLiteStorageEngineBackedObjectStorageTests: ObjectStorageTests {
    override func setUp() async throws {
        storage = ObjectStorage(
            storage: SQLiteStorageEngine(directory: .temporary(appendingPath: "SQLiteTests"))!
        )

        try await storage.removeAllObjects()
    }

    // Like most StorageEngines when a SQLiteStorageEngine rewrites data the createdAt does not change.
    // This is in contrast to DiskStorage where we are overwriting a file
    // and a new file with a new createdAt is created.
    func testCreatedAtDate() async throws {
        // Make sure the createdAt is nil if the key hasn't been stored
        let initialCreatedAt = await storage.createdAt(forKey: Self.testCacheKey)
        XCTAssertNil(initialCreatedAt)

        // Make sure the createdAt is in the right range if it has been stored
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let firstWriteDate = await storage.createdAt(forKey: Self.testCacheKey)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the createdAt date is not updated when the data is re-written
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let secondWriteDate = await storage.createdAt(forKey: Self.testCacheKey)

        XCTAssertEqual(firstWriteDate, secondWriteDate)
    }
}

// Testing an ObjectStorage instance that's backed by a DiskStorageEngine
final class DiskStorageEngineBackedObjectStorageTests: ObjectStorageTests {
    override func setUp() async throws {
        storage = ObjectStorage(
            storage: DiskStorageEngine(directory: .temporary(appendingPath: "DiskStorageTests"))
        )

        try await storage.removeAllObjects()
    }

    // Unlike most StorageEngines when a DiskStorage rewrites data the createdAt changes.
    // Since we are overwriting a file, a new file with a new createdAt is created.
    func testCreatedAtDate() async throws {
        // Make sure the createdAt is nil if the key hasn't been stored
        let initialCreatedAt = await storage.createdAt(forKey: Self.testCacheKey)
        XCTAssertNil(initialCreatedAt)

        // Make sure the createdAt is in the right range if it has been stored
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let firstWriteDate = await storage.createdAt(forKey: Self.testCacheKey)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the createdAt date is not updated when the data is re-written
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let secondWriteDate = await storage.createdAt(forKey: Self.testCacheKey)

        // DiskStorageEngine will overwrite the original data so unlike other engines
        // a new `createdAt` will be generated on write.
        XCTAssertNotEqual(firstWriteDate, secondWriteDate)
    }
}

class ObjectStorageTests: XCTestCase {
    fileprivate var storage: ObjectStorage<CodableObject>!

    // You should run SQLiteStorageEngineBackedObjectStorageTests and DiskStorageEngineBackedObjectStorageTests
    // but not ObjectStorageTests since it's only here for the purpose of shared code.
    // Since this can run on it's own, instead what we do is pick one of the two storages at random
    // and let the tests run, since they should pass anyhow as long as the storages work.
    override func setUp() async throws {
        let diskStorageEngine = DiskStorageEngine(directory: .temporary(appendingPath: "FileSystemTests"))
        let sqliteStorageEngine = SQLiteStorageEngine(directory: .temporary(appendingPath: "SQLiteTests"))!

        storage = ObjectStorage(
            storage: [diskStorageEngine, sqliteStorageEngine].randomElement()!
        )

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

    func testUpdatedAtDate() async throws {
        // Make sure the updatedAt is nil if the key hasn't been stored
        let initialUpdatedAt = await storage.updatedAt(forKey: Self.testCacheKey)
        XCTAssertNil(initialUpdatedAt)

        // Make sure the updatedAt is in the right range if it has been stored
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let firstWriteDate = await storage.updatedAt(forKey: Self.testCacheKey)

        try await Task.sleep(nanoseconds: 1_000_000)

        // Make sure the updatedAt date is updated when the data is re-written
        try await storage.store(Self.testObject, forKey: Self.testCacheKey)
        let secondWriteDate = await storage.updatedAt(forKey: Self.testCacheKey)

        XCTAssertNotEqual(firstWriteDate, secondWriteDate)
    }
}

private struct CodableObject: Codable, Equatable {
    let value: String
}

private extension ObjectStorageTests {
    static let testObject = CodableObject(value: "default-value")
    static let testCacheKey = CacheKey("test-key")

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
