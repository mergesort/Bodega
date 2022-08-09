# Using StorageEngines

The ``StorageEngine`` is at the heart of what makes Bodega, Bodega.  

## Overview

A ``StorageEngine`` represents a data storage mechanism for persisting data. A ``StorageEngine`` is a construct you can build to store `Data`, or you can plug it into ``ObjectStorage`` to have a unified type-safe Swift API to use for persisting data. ``ObjectStorage`` provides a higher-level abstraction so you don't ever have to think about databases, persistence layers, or servers.

This library has two implementations of ``StorageEngine``, ``DiskStorageEngine`` and ``SQLiteStorageEngine``, both of which we'll discuss below. Each can serve as inspiration if you want to build a ``StorageEngine`` for your own persistence mechanism such as Realm, CoreData, CloudKit, etc.

``DiskStorageEngine`` takes `Data` and saves it to disk using file system operations. ``SQLiteStorageEngine`` takes `Data` and transparently saves it to an SQLite database. This is fundamentally how a ``StorageEngine`` works, the protocol provides a blueprint for how to map Swift values and objects to `Data`, and how to map `Data` back to Swift types. 

If your app already has a persistence layer then you can create a ``StorageEngine`` by conforming to the ``StorageEngine``, such as creating a `CoreDataStorageEngine`, `RealmStorageEngine`, or even `CloudKitStorageEngine` to handle the needs of your app. ``DiskStorageEngine`` and ``SQLiteStorageEngine`` both serve as good references for building your own ``StorageEngine``.

For now let's discuss Bodega's built-in ``StorageEngine`` options.

## Which StorageEngine Is Right For You?

The answer will almost always be ``SQLiteStorageEngine``. The reason why is simple, it's significantly faster than ``DiskStorageEngine``. If your app is storing more than a few thousand objects then a ``DiskStorageEngine``-backed ``ObjectStorage`` will end up having long initialization times. But if you're not worried about performance and would prefer the ability to inspect the underlying data without an SQLite editor, then using ``DiskStorageEngine`` is a reasonable choice.

## DiskStorageEngine

In Bodega v1 there was no concept of a ``StorageEngine``, everyone was implicitly using a ``DiskStorageEngine``. In v2 we created the new ``StorageEngine`` abstraction, and rebuilt ``DiskStorageEngine`` by conforming to the ``StorageEngine`` protocol.

To initialize a `DiskStorageEngine` all you need to do is write one line of code.
```swift
private let imagesStorage = DiskStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Images"))
```

As with any other ``StorageEngine`` you'll then be able to read or write data to and from the ``DiskStorageEngine``.
```swift
// Write data to disk
try await self.imagesStorage.write(data, key: CacheKey("red-panda.jpg"))

// Read data from disk
await self.imagesStorage.read(key: CacheKey("red-panda.jpg"))
```

The ``DiskStorageEngine`` prioritizes simplicity over speed, focusing on ease of use and debugging. The ``DiskStorageEngine`` will write a one file for every object you save to the ``DiskStorageEngine``. That makes it easy to inspect and debug any objects you're saving, with a downside of poor performance as your ``DiskStorageEngine`` grows.

Initialization times vary based on the total number of objects you have saved, but a rule of thumb is that loading 1,000 objects from disk takes about 0.25 seconds. This can start to feel a bit slow if you are saving more than 2,000-3,000 objects, at which point
it may be worth investigating an alternative ``StorageEngine``. By comparison if you're using ``SQLiteStorageEngine`` it only takes about 0.1 seconds to load 1,000 objects, the difference only growing more the more objects you have. Since ``DiskStorageEngine`` is backed by files, every operating system write or remove operation carries additional overhead, saving 10 files to disk requires 10 separate writes.

This is different than an alternative like ``SQLiteStorageEngine`` where you only have one database that you write to and read from. This may not sound like a big difference but when you look at how it scales you can see that ``SQLiteStorageEngine`` is a superior choice for larger apps.

![StorageEngine Read Performance](StorageEngine-Read-Performance)
![StorageEngine Write Performance](StorageEngine-Write-Performance)

If performance is important ``Bodega`` ships ``SQLiteStorageEngine``, and that is the recommended
default ``StorageEngine``. If you have your own persistence layer such as Core Data, Realm, etc,
you can choose to build your own ``StorageEngine`` to plug into ``ObjectStorage``.

## SQLiteStorageEngine

As the name implies, ``SQLiteStorageEngine`` is a ``StorageEngine`` based on an SQLite database. ``SQLiteStorageEngine`` is Bodega's default ``StorageEngine``, If you're not using your own persistence mechanism such as Core Data, Realm, etc, it is highly recommended you use ``SQLiteStorageEngine`` to power your ``ObjectStorage`` (or Store if you're using [Boutique](https://github.com/mergesort/Boutique)).

``SQLiteStorageEngine`` is the default because it is significantly faster than ``DiskStorageEngine``. As much as ``DiskStorageEngine`` was optimized, file system operations like writing and removing files have a relatively high cost per operation. SQLite on the other hand [has been shown](https://www.sqlite.org/fasterthanfs.html) to be significantly faster than files for storing data.

The simplest way to get started with ``SQLiteStorageEngine`` is to use one of the defaults.

```swift
// Initializes an SQLiteStorageEngine in the platform-specific default storage directory
let storage = SQLiteStorageEngine.default

// Initializes an SQLiteStorageEngine in the platform-specific default storage directory, appending the path "Animals"
let animalsStorage = SQLiteStorageEngine.default(appendingPath: "Animals")
```

If you require more flexibility in specifying where you'd like to save your data you can use the ``SQLiteStorageEngine`` initializer with a `directory` parameter.

```swift
// Equivalent to SQLiteStorageEngine.default(appendingPath: "Animals")
let animalsStorage = SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Animals"))

// Initializes an SQLiteStorageEngine in the caches directory, appending the path "Animals"
let animalsStorage = SQLiteStorageEngine(directory: .caches(appendingPath: "Animals"))
```

## FileManager.Directory

Above we setup an ``SQLiteStorageEngine`` pointing to the `.caches` directory. This is thanks to a few static functions on `FileManager.Directory` that handle the locations most iOS and macOS apps store data.

```swift
// Works only on macOS
static func applicationSupport(appendingPath pathComponent: String) -> FileManager.Directory

static func caches(appendingPath pathComponent: String) -> FileManager.Directory

static func documents(appendingPath pathComponent: String) -> FileManager.Directory

// For apps that use Apple's App Groups feature to share data between multiple apps and extensions.
static func sharedContainer(forAppGroupIdentifier identifier: String, appendingPath pathComponent: String) -> FileManager.Directory

static func temporary(appendingPath pathComponent: String) -> FileManager.Directory
```

Depending on the needs of your app you can choose where to create the ``DiskStorageEngine`` or ``SQLiteStorageEngine``. Otherwise the default location will choose the `Documents` folder on all platforms other than macOS, where the ``StorageEngine`` will default to `Application Support`, matching platform conventions.
```swift
static func defaultStorageDirectory(appendingPath pathComponent: String) -> FileManager.Directory
```
