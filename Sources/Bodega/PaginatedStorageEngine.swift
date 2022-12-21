import Foundation

/// A ``PaginatedStorageEngine`` represents a special type of ``StorageEngine`` capable of fetching pages of data on demand.
///
/// Use a ``PaginatedStorageEngine`` when the amount of stored data is large, and fetching all data upfront is a performance issue.
///
/// Refer to ``SQLiteStorageEngine`` for inspiration on how to implement paginated methods.
public protocol PaginatedStorageEngine: StorageEngine {
    associatedtype PaginationOptions
    associatedtype PaginationCursor

    func readDataAndKeys(options: PaginationOptions) -> Paginator<PaginationCursor, (key: CacheKey, data: Data)>
    func readData(options: PaginationOptions) -> Paginator<PaginationCursor, Data>
}

/// A ``Paginator`` is an ``AsyncSequence`` that can iterate over the pages fetched from ``PaginatedStorageEngine``.
public struct Paginator<Cursor: Sendable, Item: Sendable>: AsyncSequence {
    public typealias Element = [Item]
    private let next: @Sendable (Cursor?) async throws -> (Cursor?, Element)

    public init(next: @Sendable @escaping (Cursor?) async throws -> (Cursor?, Element)) {
        self.next = next
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(state: AsyncPaginatorState(next: next))
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
        private var next: @Sendable (Cursor?) async throws -> (Cursor?, Element)

        init(next: @Sendable @escaping (Cursor?) async throws -> (Cursor?, Element)) {
            self.next = next
        }

        func next() async throws -> Element? {
            if self.isFinished {
                return nil
            }

            let (nextCursor, results) = try await next(cursor)
            self.cursor = nextCursor
            self.isFinished = nextCursor == nil

            return results
        }
    }
}
