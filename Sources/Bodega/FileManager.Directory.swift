import Foundation

public extension FileManager {

    struct Directory {
        public let url: URL
    }

}

public extension FileManager.Directory {

    /// Returns a URL to a subfolder created in the documents directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's documents directory.
    static func documents(appendingPath pathComponent: String) -> Self {
        self.init(
            url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        )
    }

    /// Returns a URL to a subfolder created in the caches directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's caches directory.
    static func caches(appendingPath pathComponent: String) -> Self {
        self.init(
            url: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        )
    }

    /// Returns a URL to a subfolder created in the temporary directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's temporary directory.
    static func temporary(appendingPath pathComponent: String) -> Self {
        self.init(
            url: FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
        )
    }

    /// For apps that use the App Groups feature this function returns a URL that
    /// appends a path to the app's group shared directory.
    ///
    /// - Parameters:
    ///   - identifier: The app's group identifier as declared in your app's App Groups Entitlement.
    ///   - pathComponent: A path to append to the app's group shared directory.
    /// - Returns: A URL to a subfolder created in the app's group shared directory.
    static func sharedContainer(forAppGroupIdentifier identifier: String, appendingPath pathComponent: String) -> Self {
        self.init(
            url: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!.appendingPathComponent(pathComponent)
        )
    }

    @available(macOS 11, *)
    static func applicationSupport(appendingPath pathComponent: String) -> Self {
        self.init(
            url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        )
    }

}
