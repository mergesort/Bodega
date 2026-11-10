import SQLite
import XCTest
@testable import Bodega

final class StorageReadFailureTests: XCTestCase {
	func testSQLiteMissingValuesDifferFromQueryFailures() async throws {
		let directory = FileManager.Directory.temporary(appendingPath: "SQLiteReadFailures-\(UUID())")
		defer { try? FileManager.default.removeItem(at: directory.url) }

		let storage = try XCTUnwrap(SQLiteStorageEngine(directory: directory))
		let key = CacheKey(verbatim: "saved")
		try await self.assertMissingValues(in: storage, key: key)
		let object = TestObject(value: "saved")
		let bytes = try JSONEncoder().encode(object)
		try await storage.write(bytes, key: key)
		let saved = try await storage.read(key: key)
		XCTAssertEqual(saved, bytes)
		let objects = ObjectStorage<TestObject>(storage: storage)
		let savedObject = try await objects.object(forKey: key)
		XCTAssertEqual(savedObject, object)

		let connection = try Connection(directory.url.appendingPathComponent("data.sqlite3").path)
		try connection.run("DROP TABLE data")
		await self.assertQueriesFail(in: storage, key: key)
		await self.assertThrows("ObjectStorage.object", operation: { _ = try await objects.object(forKey: key) })
		await self.assertThrows("ObjectStorage.allObjects", operation: { _ = try await objects.allObjects() })
		await self.assertThrows("ObjectStorage.allObjectsAndKeys", operation: { _ = try await objects.allObjectsAndKeys() })
	}

	func testDiskMissingDirectoryDiffersFromInvalidStoragePath() async throws {
		let directory = FileManager.Directory.temporary(appendingPath: "DiskReadFailures-\(UUID())")
		defer { try? FileManager.default.removeItem(at: directory.url) }

		let storage = DiskStorageEngine(directory: directory)
		let key = CacheKey(verbatim: "saved")
		try await self.assertMissingValues(in: storage, key: key)
		let missingAccessDate = try await storage.lastAccessed(key: key)
		XCTAssertNil(missingAccessDate)

		let bytes = Data("A file cannot serve as the storage directory.".utf8)
		try bytes.write(to: directory.url)
		await self.assertQueriesFail(in: storage, key: key)
		await self.assertThrows("lastAccessed", operation: { _ = try await storage.lastAccessed(key: key) })
		XCTAssertEqual(try Data(contentsOf: directory.url), bytes)
	}

	func testDiskCollectionReadPropagatesAnIndividualReadFailure() async throws {
		let directory = FileManager.Directory.temporary(appendingPath: "DiskItemReadFailures-\(UUID())")
		defer { try? FileManager.default.removeItem(at: directory.url) }

		let storage = DiskStorageEngine(directory: directory)
		let goodKey = CacheKey(verbatim: "good")
		let badKey = CacheKey(verbatim: "bad")
		let bytes = Data("Keep the valid item.".utf8)
		try await storage.write(bytes, key: goodKey)
		try FileManager.default.createDirectory(at: directory.url.appendingPathComponent(badKey.value), withIntermediateDirectories: false)

		await self.assertThrows("read(key:)", operation: { _ = try await storage.read(key: badKey) })
		// Disk uses StorageEngine's default read(keys:), which must not return a partial array.
		await self.assertThrows("read(keys:)", operation: { _ = try await storage.read(keys: [goodKey, badKey]) })
		await self.assertThrows("readDataAndKeys", operation: { _ = try await storage.readDataAndKeys(keys: [goodKey, badKey]) })
		let saved = try await storage.read(key: goodKey)
		XCTAssertEqual(saved, bytes)
	}

	func testObjectStoragePropagatesCorruptJSONInsteadOfMissingOrPartialObjects() async throws {
		let directory = FileManager.Directory.temporary(appendingPath: "ObjectReadFailures-\(UUID())")
		defer { try? FileManager.default.removeItem(at: directory.url) }

		let engine = DiskStorageEngine(directory: directory)
		let storage = ObjectStorage<TestObject>(storage: engine)
		let goodKey = CacheKey(verbatim: "good")
		let badKey = CacheKey(verbatim: "bad")
		let object = TestObject(value: "Keep this object")
		try await storage.store(object, forKey: goodKey)
		let missing = try await storage.object(forKey: badKey)
		XCTAssertNil(missing)
		let corruptBytes = Data("invalid JSON".utf8)
		try await engine.write(corruptBytes, key: badKey)

		let reads: [(String, () async throws -> Void)] = [
			("object", { _ = try await storage.object(forKey: badKey) }),
			("objects", { _ = try await storage.objects(forKeys: [goodKey, badKey]) }),
			("objectsAndKeys", { _ = try await storage.objectsAndKeys(keys: [goodKey, badKey]) }),
			("allObjects", { _ = try await storage.allObjects() }),
			("allObjectsAndKeys", { _ = try await storage.allObjectsAndKeys() })
		]

		for (name, read) in reads {
			await self.assertThrows(name, matching: { $0 is DecodingError }, operation: read)
		}

		let savedBytes = try await engine.read(key: badKey)
		XCTAssertEqual(savedBytes, corruptBytes)
		try await engine.remove(key: badKey)
		let recovered = try await storage.allObjects()
		XCTAssertEqual(recovered, [object])
	}
}

private extension StorageReadFailureTests {
	struct TestObject: Codable, Equatable {
		let value: String
	}

	func assertMissingValues(in storage: StorageEngine, key: CacheKey) async throws {
		let data = try await storage.read(key: key)
		let values = try await storage.read(keys: [key])
		let keyedValues = try await storage.readDataAndKeys(keys: [key])
		let allData = try await storage.readAllData()
		let allKeyedData = try await storage.readAllDataAndKeys()
		let exists = try await storage.keyExists(key)
		let existingKeys = try await storage.keysExist([key])
		let count = try await storage.keyCount()
		let keys = try await storage.allKeys()
		let createdAt = try await storage.createdAt(key: key)
		let updatedAt = try await storage.updatedAt(key: key)
		XCTAssertNil(data)
		XCTAssertTrue(values.isEmpty)
		XCTAssertTrue(keyedValues.isEmpty)
		XCTAssertTrue(allData.isEmpty)
		XCTAssertTrue(allKeyedData.isEmpty)
		XCTAssertFalse(exists)
		XCTAssertTrue(existingKeys.isEmpty)
		XCTAssertEqual(count, 0)
		XCTAssertTrue(keys.isEmpty)
		XCTAssertNil(createdAt)
		XCTAssertNil(updatedAt)
	}

	func assertQueriesFail(in storage: StorageEngine, key: CacheKey) async {
		let queries: [(String, () async throws -> Void)] = [
			("read(key:)", { _ = try await storage.read(key: key) }),
			("read(keys:)", { _ = try await storage.read(keys: [key]) }),
			("readDataAndKeys", { _ = try await storage.readDataAndKeys(keys: [key]) }),
			("readAllData", { _ = try await storage.readAllData() }),
			("readAllDataAndKeys", { _ = try await storage.readAllDataAndKeys() }),
			("keyExists", { _ = try await storage.keyExists(key) }),
			("keysExist", { _ = try await storage.keysExist([key]) }),
			("keyCount", { _ = try await storage.keyCount() }),
			("allKeys", { _ = try await storage.allKeys() }),
			("createdAt", { _ = try await storage.createdAt(key: key) }),
			("updatedAt", { _ = try await storage.updatedAt(key: key) })
		]

		for (name, query) in queries {
			await self.assertThrows(name, operation: query)
		}
	}

	func assertThrows(_ name: String, matching predicate: (Error) -> Bool = { _ in true }, operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
		do {
			try await operation()
			XCTFail("\(name) succeeded instead of propagating the storage failure", file: file, line: line)
		} catch {
			XCTAssertTrue(predicate(error), "\(name) threw an unexpected error: \(error)", file: file, line: line)
		}
	}
}
