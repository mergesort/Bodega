import XCTest
@testable import Bodega

final class CacheKeyTests: XCTestCase {

    func testCacheKeyExpressibleByStringLiteral() {
        let literalCacheKey: CacheKey = "cache-key"
        let cacheKey = CacheKey("cache-key")

        XCTAssertEqual(cacheKey.value, literalCacheKey.value)
        XCTAssertEqual(cacheKey.value, "cache-key")
    }

    func testCacheKeyURLHashing() {
        let redPandaClubHash = "37E97C2D-25C0-19AE-755D-FC39211AEE32"
        let url = URL(string: "https://www.redpanda.club")!
        let cacheKey = CacheKey(url: url)

        XCTAssertEqual(cacheKey.value, redPandaClubHash)

        let dummyHash = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
        XCTAssertNotEqual(cacheKey.value, dummyHash)
    }

}
