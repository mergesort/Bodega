# Building An Image Cache

Bodega takes data management off your plate, making once complex problems like building an image cache much simpler.

## Overview

When you're building an app that displays images the first thing you need to do is build an image cache. An image cache provides numerous benefits. It lets your app work offline, makes sure you never have to redownload images you've already saved, and it makes your app faster by skipping unnecessary network requests.

In this tutorial we'll build an image cache, connect it to a SwiftUI View, and demonstrate a good pattern for querying cached data. While the cache we'll build is for images, the same approach works for any data, whether you want to save videos, HTML, or even custom files. You can even use ``ObjectStorage`` to cache your app's models, as discussed in <doc:Using-ObjectStorage>.

## ImageCache

Below is the `ImageCache`, and like any cache it has an operation to save data and an operation to retrieve data.

```swift
import Bodega

final class ImageCache: ObservableObject {

    // 1
    private let imageStore = SQLiteStorageEngine.default(appendingPath: "Images")

    init() { }

    // 2
    func cache(image: UIImage, forKey key: CacheKey) async throws {
        guard let data = image.pngData() else { return }
        try await self.imageStore.write(data, key: key)
    }

    // 3
    func image(forKey key: CacheKey) async -> UIImage? {
        guard let imageData = await self.imageStore.read(key: key) else { return nil }
        return UIImage(data: imageData)
    }

}
```

1. We create an instance of ``SQLiteStorageEngine`` (`imagesStore`) to hold the images we will be caching. The document <doc:Using-StorageEngines> discusses the differences between ``SQLiteStorageEngine`` and ``DiskStorageEngine`` in depth, you can use either for this task but we'll choose to use ``SQLiteStorageEngine``.

2. Our `cache(image: UIImage, forKey: CacheKey)` function does one thing and does it well. If the image passed into the function can be converted to `Data`, we will write that `Data` into the ``StorageEngine``. If it can't write the `Data` to the ``StorageEngine`` we'll return early instead. If there are any errors thrown when writing the data they will be provided to the caller of the `cache` function.

3. Our `image(forKey: CacheKey)` function is similarly focused, tasked with retrieving an image from the cache if that image exists in our cache. If you haven't yet retrieved an image from the server then it won't be in the cache. This case is very common so it doesn't make sense to throw errors, instead a `nil` value signals to us that we have a reason to attempt retrieving an image from our API.

## ImageFetchingAPI 

Now that we have a cache for storing images, we'll need to fetch images to store. We won't build a real API for the purposes of this tutorial, but this approach should work for fetching any image from the internet.

```swift
struct ImageFetchingAPI {

    func download(url: URL) async -> UIImage {
        // Make a network call download an image
        return UIImage()
    }

}
```

For our `ImageFetchingAPI` our `download(url: URL)` function will use the `url` parameter provided to download an image.

## ProfileHeaderView

Having the ability to save, load, and download images is great, but for the user to enjoy the image we'll need to put the image into a `View`. Let's imagine we're a navigation bar that shows a user of our Jolene app their avatar if an avatar exists. 

![Profile Header View](ProfileHeaderview.png)

```swift
import SwiftUI

struct ProfileHeaderView: View {

    // 1 
    @StateObject private var imageCache = ImageCache()

    // 2
    @State private var avatarImage: UIImage?

    private static let avatarCacheKey = CacheKey("username-avatar")

    var body: some View {
        HStack {
            // 3
            if let headerImage = self.avatarImage {
                Image(uiImage: headerImage)
                    .frame(width: 32.0, height: 32.0)
            } else {
                Rectangle()
                    .background(Color.blue)
                    .cornerRadius(8.0)
                    .frame(width: 32.0, height: 32.0)
            }

            Spacer()

            Text("Jolene 🌻")

            Spacer()
        }
        .frame(alignment: .center)
        }.task({
            // 4
            if let cachedImage = await self.imageCache.image(forKey: Self.avatarCacheKey) {
                self.avatarImage = cachedImage
            } else { 
                let imageAPI = ImageFetchingAPI()
                let avatarImage = await imageAPI.fetchAvatar()
                self.avatarImage = avatarImage
                try? await self.imageCache.cache(image: avatarImage, forKey: Self.avatarCacheKey)
            }
        })
    }
}
```

1. Our `ProfileHeaderview` needs to have an instance of `ImageCache`, that way we can retrieve the image we want to display from our cache. Some developers may prefer to put this property into a `ViewModel`, and that's a configuration Bodega supports. Bodega isn't prescriptive, it only focuses on storing and loading data, you can choose the rest and figure out what approach is best for you.

2. We'll create an `avatarImage` property to store the avatar image we will retrieve. It will be `nil` by default, but will be updated when we fetch an image from either our cache or from the API. Marking the property with `@State` signals to our `ProfileHeaderView` to automatically refresh when an image is retrieved, no matter the source of the image.  

3. Here we have an if condition depending on whether `avatarImage` exists or not. If `avatarImage` is `nil` we will render a lovely blue rectangle that serves as a placeholder for when we retrieve an image. If `avatarImage` is not `nil`, we will display the user's avatar as expected. The beauty of the cache is that if we've already downloaded the image before we won't have to wait for a network request to our API, instead the user will immediately see the avatar image as expected.

4. There are two distinct pathways in our `.task`, so let's go over the `if` and the `else` blocks separately.

The `.task` will run when the view appears, immediately checking to see if the image already exists in the cache. If it does we will set `avatarImage` to the image we find in the cache so the user immediately sees their avatar in the header.
```swift
if let cachedImage = await self.imageCache.image(forKey: Self.avatarCacheKey) {
    self.avatarImage = cachedImage
}
```

If the image isn't yet cached we will end up in the `else` block. In that case we will 
1. Download the user's avatar from our API, 
2. Set the result to `avatarImage`, 
3. Finish up the process by calling `imageCache.cache(image: avatarImage, forKey: Self.avatarCacheKey)` to ensure that the next time we need this avatar we have it cached.
```swift
let imageAPI = ImageFetchingAPI()
let avatarImage = await imageAPI.download(url: URL(string: "https://image.redpanda.club/random")!)
self.avatarImage = avatarImage
try? await self.imageCache.cache(image: avatarImage, forKey: Self.avatarCacheKey)
```

## Further Exploration

Building a performant and reliable cache can be a difficult task, but with Bodega's help we were able to build one in only a few lines of code. There are many complex abstractions you can build much more simply using Bodega.

As we saw above Bodega is fully usable and useful on its own, but it's also the foundation of [Boutique](https://github.com/mergesort/Boutique). Boutique helps you build a complete SwiftUI, UIKit, or AppKit app that works fully offline with the help of a similar caching approach as built for our image cache. But Boutique goes above and beyond that, providing realtime updates to your views so they're always showing the most up to date data based on your cached data. If you'd like to build an app with all of these capabilities in only a few lines of code, it's easy to get started with [Boutique's documentation](https://build.ms/boutique/docs).
