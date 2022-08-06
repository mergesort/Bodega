# ``Bodega``

A simple store all your basic needs, but surprisingly so much more. 🐱

## Overview

Bodega is an actor-based library that started as a simple cache based on reading and writing files to/from disk with an incredibly simple API. The ``DiskStorageEngine`` still provides that functionality, but Bodega has also blossomed into so much more, offering a form of infrastructure that any app's data can use.

Bodega's ``StorageEngine`` is at the heart of what's possible. Conforming any database, persistence layer, or even an API server, to the ``StorageEngine`` protocol automatically provides an incredibly simple data layer for your app thanks to Bodega's ``ObjectStorage``. Rather than `Data` and databases developers interact with their app's Swift types no matter what those may be, have a unified API, and concurrency handled out of the box.

Bodega provides two kinds of storage primitives for you, ``StorageEngine`` and ``ObjectStorage``. A ``StorageEngine`` is for writing `Data` to a persistence layer, whether it's files on disk, SQLite, or your own database. An ``ObjectStorage`` offers a unified layer over ``StorageEngine``s, providing a single API for saving `Codable` objects to any ``StorageEngine`` you choose. ``Bodega`` offers ``DiskStorageEngine`` and ``SQLiteStorageEngine`` by default, or you can even build a ``StorageEngine`` based on your app's API server if you want a simple way to interface with your API. You can even compose storage engines to create a complex data pipeline that hits your API and saves items into a database, all in one API call. The possibilities are endless.

Bodega is fully usable and useful on its own, but it's also the foundation of [Boutique](https://github.com/mergesort/Boutique). You can find a reference implementation of an app built atop Boutique in the same [repo](https://github.com/mergesort/Boutique/tree/main/Boutique%20Demo), showing you how to make an offline-ready realtime updating SwiftUI app in only a few lines of code. You can read more about the thinking behind the architecture in this blog post exploring Boutique and the [Model View Controller Store architecture](https://build.ms/2022/06/22/model-view-controller-store).

## Topics

### Fundamentals

- <doc:Using-StorageEngines>
- <doc:Using-ObjectStorage>

### Walkthroughs

- <doc:Getting-Started-With-Bodega> 
- <doc:Building-A-StorageEngine>
- <doc:Building-An-Image-Cache>
