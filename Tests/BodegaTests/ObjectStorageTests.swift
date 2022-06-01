import XCTest
@testable import Bodega

final class ObjectStorageTests: XCTestCase {

    private var storage: ObjectStorage!

    override func setUp() async throws {
        storage = ObjectStorage(storagePath: Self.testStoragePath!)

        let allKeys = await storage.allKeys()
        for key in allKeys {
            try await storage.removeObject(forKey: key)
        }
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

        do {
            try await storage.removeObject(forKey: "alternative-test-key")
        } catch {
            // We want to end up in the catch block if the caller tries to remove an object from a key that does not have an object
            let readObject: CodableObject? = await storage.object(forKey: Self.testCacheKey)
            XCTAssert(readObject == Self.testObject)
            return
        }

        XCTFail("Removing from non-existent key failed to produce an error as was expected")
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

}

private struct CodableObject: Codable, Equatable {
    let value: String
}

private extension ObjectStorageTests {

    static let testObject = CodableObject(value: "default-value")
    static let testCacheKey: CacheKey = "test-key"
    static let pathComponent = "Test"
    static let testStoragePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(ObjectStorageTests.pathComponent)

    func writeCacheKeys(count: Int) async throws {
        for i in 0..<count {
            try await storage.store(CodableObject(value: "value-\(i)"), forKey: CacheKey("\(i)"))
        }
    }

}
