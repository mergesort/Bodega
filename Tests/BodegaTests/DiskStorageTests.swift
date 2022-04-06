import XCTest
@testable import Bodega

final class DiskStorageTests: XCTestCase {

    private var storage: DiskStorage!

    override func setUp() async throws {
        storage = DiskStorage(storagePath: Self.testStoragePath)

        let allKeys = await storage.allKeys()
        for key in allKeys {
            try await storage.remove(key: key)
        }
    }

    func testWriteDataSucceeds() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)
        let readData = await storage.read(key: Self.testCacheKey)

        XCTAssertEqual(readData, Self.testData)

        // Test overwriting data
        let updatedTestData = Data("Updated Test Data".utf8)
        try await storage.write(updatedTestData, key: Self.testCacheKey)
        let updatedData = await storage.read(key: Self.testCacheKey)

        XCTAssertNotEqual(readData, updatedData)
    }

    func testReadingMissingData() async throws {
        let readData = await storage.read(key: "fake-key")
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

    func testInvalidRemoveErrors() async throws {
        try await storage.write(Self.testData, key: Self.testCacheKey)

        do {
            try await storage.remove(key: "alternative-test-key")
        } catch {
            // We want to end up in the catch block if the caller tries to remove data from a key that does not have data
            let readData = await storage.read(key: Self.testCacheKey)
            XCTAssertEqual(readData, Self.testData)
            return
        }

        XCTFail("Removing from non-existent key failed to produce an error as was expected")
    }

    func testKeyCount() async throws {
        let keyCount = await storage.keyCount()

        XCTAssertEqual(keyCount, 0)

        try await self.writeCacheKeys(count: 10)
        let updatedKeyCount = await storage.keyCount()
        XCTAssertEqual(updatedKeyCount, 10)

        // Overwriting data in the same cache keys and ensuring that the count doesn't change
        try await self.writeCacheKeys(count: 10)
        let overwrittenKeyCount = await storage.keyCount()
        XCTAssertEqual(overwrittenKeyCount, 10)
    }

    func testAllKeys() async throws {
        try await self.writeCacheKeys(count: 10)
        let allKeys = await storage.allKeys().sorted(by: { $0.value < $1.value })

        XCTAssertEqual(allKeys[0].value, "0")
        XCTAssertEqual(allKeys[3].value, "3")
        XCTAssertEqual(allKeys.count, 10)
    }

}

private extension DiskStorageTests {

    static let testData = Data("Test".utf8)
    static let testCacheKey: CacheKey = "test-key"
    static let testStoragePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    func writeCacheKeys(count: Int) async throws {
        for i in 0..<count {
            try await storage.write(Self.testData, key: CacheKey("\(i)"))
        }
    }

}
