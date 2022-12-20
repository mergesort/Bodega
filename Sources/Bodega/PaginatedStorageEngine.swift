import Foundation

public protocol PaginatedStorageEngine: StorageEngine {
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
}

public extension Paginator {
    struct AsyncIterator: AsyncIteratorProtocol {
        private let state: AsyncPaginatorState

        init(state: AsyncPaginatorState) {
            self.state = state
        }

        public func next() async throws -> Element? {
            try await self.state.next()
        }
    }
}

extension Paginator {
    actor AsyncPaginatorState {
        private var isFinished = false
        private var cursor: Cursor?
        private var fetch: (Cursor?) async throws -> (Cursor?, Element)

        init(fetch: @escaping (Cursor?) async throws -> (Cursor?, Element)) {
            self.fetch = fetch
        }

        func next() async throws -> Element? {
            if self.isFinished {
                return nil
            }

            let (nextCursor, results) = try await fetch(cursor)
            self.cursor = nextCursor
            self.isFinished = nextCursor == nil

            return results
        }
    }
}
