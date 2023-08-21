# Using ObjectStorage

``ObjectStorage`` serves as unified layer over ``StorageEngine``, allowing you to work with type-safe Swift models rather than `Data`.

## Overview

You can learn about the ``StorageEngine`` protocol in <doc:Using-StorageEngines>, but at it's most basic a ``StorageEngine`` defines functions such as `read(key: CacheKey)`, `write(data: Data, key: CacheKey)`, `remove(key: CacheKey)`, to let you read, store, and delete `Data` from your data storage mechanism.

As Swift developers we're used to interacting with higher-level types rather than `Data`. Our apps include types such as `String`, `URL`, or custom models such as `Note` or `Article`. ``ObjectStorage`` allows you to read, store, and delete Swift objects, that way you don't have to think about the underlying data.

## Setting Up ObjectStorage

The relationship between ``ObjectStorage`` and ``StorageEngine`` is that an ``ObjectStorage`` is initialized with a ``StorageEngine``, but the API you'll be interacting does not change no matter which ``StorageEngine`` you choose. This is very powerful because it gives us one API to work with no matter if we're saving files to disk, reading objects from a database, or even downloading models from CloudKit. To achieve this we have only one requirement for our model, it must conform to `Codable`. ``ObjectStorage`` requires `Codable` conformance so we can serialize items to their data storage, or even send them over the network.

```swift
// This could be any StorageEngine, so let's use the default SQLiteStorageEngine
let articlesStorageEngine = SQLiteStorageEngine.default(appendingPath: "Articles")
let articlesStorage = ObjectStorage(storage: articlesStorageEngine)

// Or on one line
let articlesStorage = ObjectStorage<Article>(
    storage: SQLiteStorageEngine.default(appendingPath: "Articles")
)
```

Now that ``ObjectStorage`` is set up, using it couldn't be simpler. The API is very similar to the ``StorageEngine`` API, but with slight function name differences to make the API feel more natural when working with Swift types rather than raw `Data`.


```swift
let article = Article(title: "How To Learn Swift", text: "... and then you practice for years")

// Write an article to your ObjectStorage
try await articlesStorage.store(article, forKey: CacheKey("how-to-learn-swift"))

// Read the article from your ObjectStorage
try await storage.object(forKey: CacheKey("how-to-learn-swift"))
```

And that's it! You now have a data storage layer that can work with your app's Swift types in only a few lines of code.
