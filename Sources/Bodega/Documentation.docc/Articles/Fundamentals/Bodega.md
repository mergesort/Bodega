# ``Bodega``

A simple store all your basic needs, and also so much more. 🐱

## Overview

Bodega is an actor-based library that started as a simple cache based on reading and writing files to/from disk with an incredibly simple API. The ``DiskStorageEngine`` still provides that functionality, but Bodega has also blossomed into much more, offering a form of infrastructure that any app's data can use.

Bodega's ``StorageEngine`` is at the heart of what's possible. Conforming any database, persistence layer, or even an API server, to the ``StorageEngine`` protocol automatically provides an incredibly simple data layer for your app thanks to Bodega's ``ObjectStorage``. Rather than thinking about `Data` and databases developers interact with regular ol' Swift types. You can store whatever data you want with a unified API for persistence, and concurrency handled out of the box.

Bodega provides two kinds of storage primitives for you, ``StorageEngine`` and ``ObjectStorage``. ``StorageEngine`` lets you write `Data` to your data storage, whether it's files on disk, SQLite, or your own database. ``ObjectStorage`` offers a unified layer over ``StorageEngine``s, providing a single API for saving `Codable` objects to the ``StorageEngine`` of your choice. ``Bodega`` has a ``DiskStorageEngine`` and ``SQLiteStorageEngine`` built in, or you can even build a ``StorageEngine`` based on your app's persistencey layer, database, or API server if you want a simple way to interface with your API. Composing storage engines allows you to create complex data pipelines, for example imagine querying the keychain for an API token, hitting your API, and saving the resulting items into a database, all with one API call. The possibilities are endless.

## Getting Started

There are numerous ways to get started with Bodega depending on how you prefer to learn. 

You can explore using the built-in ``SQLiteStorageEngine`` to see how to build an image cache in only a few lines of code.

- <doc:Building-An-Image-Cache>

The built-in ``DiskStorageEngine`` and ``SQLiteStorageEngine`` should be more than enough to handle most of the tasks iOS and macOS developers perform. It's still good to know the tradeoffs, or even when you should consider building your own ``StorageEngine``. If you want to build a ``StorageEngine`` for Core Data, the keychain, or your own custom API server, it'll be wortwhile to explore how the ``StorageEngine`` works.

- <doc:Using-StorageEngines>

Most of the time though you'll find yourself working with Swift models rather than `Data` directly, a task ``ObjectStorage`` is perfect for. Learn how to set up ``ObjectStorage``, and you'll be storing Swift types in no time.

- <doc:Using-ObjectStorage>

Bodega is fully usable and useful on its own, but it's also the foundation of [Boutique](https://github.com/mergesort/Boutique). If you're looking to build a complete SwiftUI, UIKit, or AppKit app around these concepts then Boutique is a perfect fit for that problem. The library allows you to build an offline-ready realtime updating app in only a few lines of code.

- [Boutique Documentation](https://build.ms/boutique/docs)

## Topics

### Fundamentals

- <doc:Using-StorageEngines>
- <doc:Using-ObjectStorage>

### Walkthroughs

- <doc:Building-An-Image-Cache>
