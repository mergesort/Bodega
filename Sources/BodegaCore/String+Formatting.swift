import CryptoKit
import Foundation

extension String {

    var md5: String {
        Data(self.utf8).md5.hexString
    }

    // Format characters as 8-4-4-4-12
    var uuidFormatted: String? {
        guard self.count == 32 else { return nil }

        var string = self.uppercased()
        var index = string.index(string.startIndex, offsetBy: 8)
        for _ in 0..<4 {
            string.insert("-", at: index)
            index = string.index(index, offsetBy: 5)
        }

        return string
    }

}

extension Data {

    var md5: Data {
        Data(Insecure.MD5.hash(data: self))
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

}

