import Foundation

public extension FileManager {
    /// A strongly typed directory allowing for easily specifying
    /// defaults like `documents`, `caches`, `temporary`, etc.
    struct Directory: Sendable {
        public let url: URL

        public init(url: URL) {
            self.url = url
        }
    }
}

public extension FileManager.Directory {
    /// Returns a directory that varies based on the OS the app is running on.
    /// - Parameter pathComponent: A path to append to the platform's default directory.
    /// - Returns: On macOS this returns the `Application Support` directory, otherwise `Documents`.
    static func defaultStorageDirectory(appendingPath pathComponent: String) -> Self {
#if os(macOS)
        .applicationSupport(appendingPath: pathComponent)
#else
        .documents(appendingPath: pathComponent)
#endif
    }

    /// Returns a URL to a subfolder created in the documents directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's documents directory.
    static func documents(appendingPath pathComponent: String) -> Self {
        let url: URL
        if #available(iOS 16.0, macOS 13.0, *) {
            url = URL.documentsDirectory.appending(path: pathComponent)
        } else {
            url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        }

        return self.init(url: url)
    }

    /// Returns a URL to a subfolder created in the caches directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's caches directory.
    static func caches(appendingPath pathComponent: String) -> Self {
        let url: URL
        if #available(iOS 16.0, macOS 13.0, *) {
            url = URL.cachesDirectory.appending(path: pathComponent)
        } else {
            url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        }

        return self.init(url: url)
    }

    /// Returns a URL to a subfolder created in the temporary directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's temporary directory.
    static func temporary(appendingPath pathComponent: String) -> Self {
        let url: URL
        if #available(iOS 16.0, macOS 13.0, *) {
            url = URL.temporaryDirectory.appending(path: pathComponent)
        } else {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
        }

        return self.init(url: url)
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

    /// Returns a URL to a subfolder created in the Application Support directory based on the `pathComponent`.
    ///   - pathComponent: A path to append to the app's group shared directory.
#if os(macOS)
    static func applicationSupport(appendingPath pathComponent: String) -> Self {
        let url: URL
        if #available(macOS 13.0, *) {
            url = URL.applicationSupportDirectory.appending(path: pathComponent)
        } else {
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(pathComponent)
        }

        return self.init(url: url)
    }
#endif
}
