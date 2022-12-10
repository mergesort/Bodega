import Foundation

public protocol RemoteStorageEngine: StorageEngine {
    associatedtype PaginationOptions
    associatedtype PaginationCursor

    func readDataAndKeys(options: PaginationOptions) -> Paginator<PaginationCursor, (key: CacheKey, data: Data)>
}

public struct Paginator<Cursor, Item>: AsyncSequence {
    public typealias Element = [Item]
    private let fetch: (Cursor?) async throws -> (Cursor?, Element)

    init(fetch: @escaping (Cursor?) async throws -> (Cursor?, Element)) {
        self.fetch = fetch
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(state: AsyncPaginatorState(fetch: fetch))
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let state: AsyncPaginatorState

        init(state: AsyncPaginatorState) {
            self.state = state
        }

        public func next() async throws -> Element? {
            try await state.next()
        }
    }

    actor AsyncPaginatorState {
        private var finished = false
        private var cursor: Cursor?
        private var fetch: (Cursor?) async throws -> (Cursor?, Element)

        init(fetch: @escaping (Cursor?) async throws -> (Cursor?, Element)) {
            self.fetch = fetch
        }
        
        func next() async throws -> Element? {
            if finished {
                return nil
            }

            let (nextCursor, results) = try await fetch(cursor)
            cursor = nextCursor
            finished = nextCursor == nil

            return results
        }
    }
}
