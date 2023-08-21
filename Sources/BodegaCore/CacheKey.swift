import Foundation

/// ``CacheKey`` is a type meant to provide a stable storage key.
/// If initialized from a URL the ``CacheKey`` value will generate
/// a consistent UUID-formatted MD5 version of the URL string as the key
/// to ensure it is file system safe.
public struct CacheKey: Codable, Equatable, Hashable, Sendable {
    /// The `String` representation of your `CacheKey`.
    public let value: String

    /// The `String` that was passed in to any initializer, regardless of whether it was hashed afterwards or not.
    /// Currently this is used in ``StorageEngine``s that are not file system based
    /// and will be deprecated in the future, when ``CacheKey`` is [deprecated](https://github.com/mergesort/Bodega/issues/9).
    public let rawValue: String

    /// Initializes a ``CacheKey`` from a `URL`. This initializer is useful if you plan on using
    /// `CacheKey`s for storing files on disk because file have many limitations about
    /// which characters that are allowed in file names, and the maximum length of a file name.
    /// - Parameter url: The URL to use as the foundation of your cache key.
    /// The URL will be sanitized to account for common user-generated differences
    /// before generating a cache key, so note that https://redpanda.club and https://www.redpanda.club
    /// will generate a ``CacheKey`` with the same underlying value.
    public init(url: URL) {
        self.rawValue = url.absoluteString

        let md5HashedURLString = Self.sanitizedURLString(url).md5
        self.value = md5HashedURLString.uuidFormatted ?? md5HashedURLString
    }

    /// Initializes a ``CacheKey`` from a `String`, creating a hashed version of the input `String`.
    /// This initializer is useful if you plan on using ``CacheKey``s for storing files on disk
    /// because file have many limitations about characters that are allowed in file names,
    /// and the maximum length of a file name.
    /// - Parameter value: The `String` which will serve as the underlying value for this ``CacheKey``.
    public init(_ value: String) {
        self.rawValue = value
        self.value = value.md5.uuidFormatted ?? value.md5
    }

    /// Initializes a ``CacheKey`` from a `String`, using the exact `String` as the value of the ``CacheKey``.
    /// - Parameter value: The `String` which will serve as the underlying value for this ``CacheKey``.
    public init(verbatim value: String) {
        self.rawValue = value
        self.value = value
    }
}

private extension CacheKey {
    /// A function to remove common discrepancies that do not represent differences
    /// a user truly intended such as URLs with trailing slashes, www, etc.
    /// - Parameter url: The URL to normalize
    /// - Returns: A normalized string
    static func sanitizedURLString(_ url: URL) -> String {
        var urlComponents = URLComponents(string: url.absoluteString)

        // Remove the scheme because we don't want a user saving https://www.xyz.com to clash with www.xyz.com
        urlComponents?.scheme = nil

        guard let url = urlComponents?.url else { return url.absoluteString }

        var normalizedURLString = url.absoluteString

        if normalizedURLString.hasPrefix("//") {
            normalizedURLString = String(normalizedURLString.dropFirst("//".count))
        }

        if normalizedURLString.hasSuffix("/") {
            normalizedURLString = String(normalizedURLString.dropLast("/".count))
        }

        normalizedURLString = normalizedURLString
            .replacingOccurrences(of: "www.", with: "") // Remove www so a version with/without it don't collide

        return normalizedURLString
    }
}
