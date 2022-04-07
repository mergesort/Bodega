![Bodega Logo](Images/logo.jpg)

### A simple store for all your basic needs, accepting cache money my friend. 🐱

Is this library the best caching library? Absolutely not, but nobody thinks a [bodega](https://en.wikipedia.org/wiki/Bodega_(store)) is the best store either. Like a bodega this library is there for you when you need something simple and you want it to work.

---

### Getting Started

There are two kinds of storage provided for you, `ObjectStorage` building on top of `DiskStorage`. `DiskStorage` is for writing `Data` to disk, and `ObjectStorage` allows you to write any `Codable` object to disk using a very similar API.

Both `DiskStorage` and `ObjectStorage` are implemented as actors which means they take care of properly synchronizing disk reads and writes. Until Swift implements [custom executors](https://forums.swift.org/t/support-custom-executors-in-swift-concurrency/44425) there will probably be a small performance penalty when using `ObjectStorage` since one actor has to talk to another, but in limited usage and performance profiling I have noticed no performance issues. No promises though!

---

#### DiskStorage

```swift
// CacheKeys can be generated from a String or URL.
// URLs will be reformatted into a file system safe format before writing to disk.
let url = URL(string: "https://redpanda.club/dope-quotes/dolly-parton")
let cacheKey = CacheKey(url: url)
let data = Data("Find out who you are. And do it on purpose. - Dolly Parton".utf8)

// Write data to disk
try await storage.write(data, key: cacheKey)

// Read data from disk
let readData = await storage.read(key: cacheKey)

// Remove data from disk
try await storage.remove(key: Self.testCacheKey)
```

#### ObjectStorage

`ObjectStorage` has a very similar API to `DiskStorage`, but with slight naming deviations to be more explicit that you're working with objects and not data.

```swift
// CacheKey conforms to ExpressibleByStringLiteral so you can pass in a string wherever you use a CacheKey.
let cacheKey: CacheKey = "churchill-optimisim"

let quote = Quote(
    id: "winston-churchill-1",
    text: "I am an optimist. It does not seem too much use being anything else.",
    author: "Winston Churchill",
    url: URL(string: "https://redpanda.club/dope-quotes/winston-churchill")
)

// Store an object to disk
try await storage.store(Self.testObject, forKey: cacheKey)

// Read an object from disk
let readObject: CodableObject? = await storage.object(forKey: cacheKey)

// Grab all the keys, which at this point will be one key, `cacheKey`.
let allKeys = await storage.allKeys()

// Verify by calling `keyCount`, both key-related methods are also available on `DiskStorage`.
await storage.keyCount()

// Remove an object from disk
try await storage.removeObject(forKey: cacheKey)
```

---

### Ideas 💭

These techniques aren't included in the library because they're too prescriptive for a library, but I still think it's worth including to see what you can compose atop Bodega. You can use any or all of these techniques, you can even combine them to your heart's delight!

#### Simple Generic Stores

Bodega provides a solid foundation for reading from and writing to disk, which makes setting up your own data store on top of it is mostly boilerplate. Boilerplate is often a signal that we can build a generic abstraction, and below is a simple Store for persisting and fetching data that's easy to setup, reusable, and easy to expand upon as needed.

```swift
struct Store<Object: Codable> {

    private let objectStorage: ObjectStorage

    init(storagePath: URL) {
        self.objectStorage = ObjectStorage(storagePath: storagePath)
    }

    func cached(forKey cacheKey: CacheKey) async -> Object? {
        return await self.objectStorage.object(forKey: cacheKey)
    }

    func cached() async throws -> [Object] {
        return await self.objectStorage
            .allKeys()
            .asyncCompactMap({ key in
                await self.cached(forKey: key)
            })
    }

    func cache(_ item: Object, identifier: KeyPath<Object, String>) async throws {
        try await self.objectStorage.store(item, forKey: CacheKey(item[keyPath: identifier]))
    }

    func cache(_ items: [Object], identifier: KeyPath<Object, String>) async throws {
        try await items.asyncForEach { item in
            try await self.cache(item, identifier: identifier)
        }
    }

}
```

Now that we have a simple Store setup, using it to store and fetch quotes couldn't be simpler.

```swift
let quotesStorageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Quotes")!
let quotesStore = Store<Quote>(storagePath: quotesStorageURL)

// Fetch all of the currently cached quotes.
let cachedQuotes = await quotesStore.cached()

// Cache a quote using a `KeyPath` to a `String` as the identifier.
// Providing a `KeyPath` allows us to create a different key creation strategy per-type
// without knowing the type ahead of time, or mandating the cached type 
// have specific constraints more than being `Codable`.
try await quotesStore.cache(quote, identifier: \.id)
```

#### Disk + Memory Caching Layer

While storing objects on disk is useful for persistence, caching objects in memory is useful for optimal performance. It's often worth having a layer in your app that synchronizes those reads and writes across the two layers, here's a simple example of how to create a Controller for managing your data.

```swift
public actor QuotesController {

    private let downloader = QuotesDownloader()
    private let quotesStorage = ObjectStorage()

    @Published public var quotes: [Quote] = []

    public func downloadQuote(fromURL url: URL) async throws -> Quote {
        let cacheKey = CacheKey(url: url)

        if let cachedQuote: Quote = await self.quotesStorage.object(forKey: cacheKey) {
            return cachedQuote
        }

        let quote = try await self.downloader.fetchQuote(fromURL: url)
        try await linkStorage.store(object: quote, forKey: cacheKey)
        self.quotes.insert(quote, at: 0)

        return quote
    }

}
```

#### Type-safe sharding

The `subdirectory` parameter takes in a `String` to be type-agnostic, but you can create your own type and extend `ObjectStorage` with methods that take in that type to more easily split data across folders. Here's an example of how to write a more type-safe API for your storage needs.

```swift
extension ObjectStorage {

    enum DataType: String {
        case quote = "quotes"
        case link = "links"
        case image = "images"
    }

    func store<Object: Codable>(object: Object, forKey key: CacheKey, dataType: DataType) async throws {
        try await storage.store(object, forKey: key, subdirectory: dataType.rawValue)
    }

}
```

And voila, you can call `ObjectStorage.store` with a clean type-safe API!

```swift
let cacheKey: CacheKey = "fred-rogers-lifetimes-work"

let quote = Quote(
    id: "fred-rogers-2",
    text: "Discovering the truth about ourselves is a lifetime’s work, but it’s worth the effort.",
    author: "Fred Rogers",
    url: URL(string: "https://redpanda.club/dope-quotes/fred-rogers")
)

self.objectStorage.store(quote, forKey: cacheKey, dataType: .quote)
```

### Requirements

- iOS 13.0+
- macOS 11.0
- Xcode 13.2+

### Installation

#### Swift Package Manager

The [Swift Package Manager](https://www.swift.org/package-manager) is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding Bodega as a dependency is as easy as adding it to the dependencies value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/mergesort/Bodega.git", .upToNextMajor(from: "1.0.0"))
]
```

#### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate Bodega into your project manually.

---

## About me

Hi, I'm [Joe](http://fabisevi.ch) everywhere on the web, but especially on [Twitter](https://twitter.com/mergesort).

## License

See the [license](LICENSE) for more information about how you can use Bodega.
