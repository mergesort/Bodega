# Using StorageEngines

The ``StorageEngine`` is at the heart of what makes Bodega, Bodega.  

## Overview

A ``StorageEngine`` represents a data storage mechanism for saving and persisting data. A ``StorageEngine`` is a construct you can build that plugs into ``ObjectStorage`` to use for persisting data, ``ObjectStorage`` providing a higher-level abstraction which allows you to interface with Swift types rather than `Data` so you don't ever have to think about databases, persistence layers, or servers.

This library has two implementations of ``StorageEngine``, ``DiskStorageEngine`` and ``SQLiteStorageEngine`` which we'll discuss below. Both of these can serve as inspiration if you have your own persistence mechanism (such as Realm, CoreData, CloudKit, etc).

``DiskStorageEngine`` takes `Data` and saves it to disk using file system operations. ``SQLiteStorageEngine`` takes `Data` and saves it to an SQLite database under the hood. This is fundamentally how a ``StorageEngine`` works, the protocol provides a blueprint for how to map Swift values and objects to `Data`, and how to map `Data` back to Swift types. 

If your app already has a persistence layer then all you need to do is conform to the ``StorageEngine`` protocol. You can turn to the <doc:Building-A-StorageEngine> tutorial to learn how to create your own ``StorageEngine``, or you can use ``DiskStorageEngine`` and ``SQLiteStorageEngine`` as references.

For now let's discuss the ``StorageEngine``s that are built-in with Bodega.

## DiskStorageEngine

In Bodega v1 there was no concept of a ``StorageEngine``, everyone was implicitly using a ``DiskStorageEngine``. In v2 we created the new ``StorageEngine`` abstraction, and rebuilt ``DiskStorageEngine`` by conforming to the ``StorageEngine`` protocol.

The ``DiskStorageEngine`` prioritizes simplicity over speed, it's a very easy to use and understand concept. The ``DiskStorageEngine`` will write a one file for every object you save, which makes it easy to inspect and debug any objects you're saving. The downside of using ``DiskStorageEngine`` is performance.

Initialization times vary based on the total number of objects you have saved, but a rule of thumb is that loading 1,000 objects from disk takes about 0.25 seconds. This can start to feel a bit slow if you are saving more than 2,000-3,000, at which point
it may be worth investigating an alternative ``StorageEngine``. By comparison if you're using ``SQLiteStorageEngine`` it only takes about 0.1 seconds to load 1,000 objects, the difference only growing more the more objects you have. Since ``DiskStorageEngine`` is backed by files, every operating system write or remove operation carries additional overhead, saving 10 files to disk requires 10 separate writes. This is different than an alternative like ``SQLiteStorageEngine`` where you only have one database that you write to and read from. This may not sound like a big difference but when you look at how it scales you can see that ``DiskStorageEngine`` is a subpar choice for a larger app.

![StorageEngine Read Performance](StorageEngine-Read-Performance)
![StorageEngine Write Performance](StorageEngine-Write-Performance)

If performance is important ``Bodega`` ships ``SQLiteStorageEngine``, and that is the recommended
default ``StorageEngine``. If you have your own persistence layer such as Core Data, Realm, etc,
you can easily build your own ``StorageEngine`` to plug into ``ObjectStorage``.

## SQLiteStorageEngine

As the name implies, ``SQLiteStorageEngine`` is a ``StorageEngine`` based on an SQLite database. ``SQLiteStorageEngine`` is Bodega's default ``StorageEngine``, If you're not using your own persistence mechanism such as Core Data, Realm, etc, it is highly recommended you use ``SQLiteStorageEngine`` to power your ``ObjectStorage`` (or Store if you're using [Boutique](https://github.com/mergesort/Boutique)).

``SQLiteStorageEngine`` is the default because it is significantly faster than ``DiskStorageEngine``. As much as ``DiskStorageEngine`` was optimized, file system operations like writing and removing files have a relatively high cost per operation. SQLite on the other hand [has been shown](https://www.sqlite.org/fasterthanfs.html) to be significantly faster than files for storing data.

The simplest way to get started with ``SQLiteStorageEngine`` is to use one of the defaults, `SQLiteStorageEngine.default`, or `SQLiteStorageEngine.default(appendingPath:)`. This will create an ``SQLiteStorageEngine`` in a platform-specific default storage directory, equivalent to `SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Your Path"))`.

## Which Should You Choose?

The answer should almost always be ``SQLiteStorageEngine``. The reason why is simple, it's significantly faster. If your app is storing any meaningful amount of objects then a ``DiskStorageEngine``-backed ``ObjectStorage`` will end up feeling a bit slow. But if you're not worried about performance and would prefer the ability to inspect the output without an SQLite editor, then using ``DiskStorageEngine`` is a reasonable choice.

If your app already has a persistence layer it may make sense to build your own ``StorageEngine``. If you'd like to explore that option you can read through the <doc:Building-A-StorageEngine> tutorial, or use ``DiskStorageEngine`` and ``SQLiteStorageEngine`` as references.

## Topics

### Referenced

- <doc:Building-A-StorageEngine>
