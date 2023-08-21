import XCTest
@testable import BodegaCore

final class StringFormattingTests: XCTestCase {

    func testCacheKeyURLHashing() {
        let redPandaClubHash = "37E97C2D-25C0-19AE-755D-FC39211AEE32"
        let url = URL(string: "https://www.redpanda.club")!
        let cacheKey = CacheKey(url: url)

        XCTAssertEqual(cacheKey.value, redPandaClubHash)

        let dummyHash = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
        XCTAssertNotEqual(cacheKey.value, dummyHash)
    }

    func testMD5Hash() {
        let md5123 = "123".md5
        let md5ABC = "abc".md5

        XCTAssertEqual(md5ABC, "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(md5123, "202cb962ac59075b964b07152d234b70")
    }

    func testUUIDFormatting() {
        let preformattedUUIDString = "37E97C2D25C019AE755DFC39211AEE32".uuidFormatted

        XCTAssertEqual(preformattedUUIDString, "37E97C2D-25C0-19AE-755D-FC39211AEE32")
        XCTAssertNotEqual(preformattedUUIDString, "37E97C2D25C019AE755DFC39211AEE32")
    }

}
