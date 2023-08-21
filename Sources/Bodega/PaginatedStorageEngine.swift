import Foundation

/// The ``PaginatedStorageEngine`` represents additional capabilities for a ``StorageEngine``, one that can fetch pages of data on demand.
///
/// Use a ``PaginatedStorageEngine`` when the amount of stored data is large, and fetching all data upfront can cause performance issues.
///
/// Refer to ``SQLiteStorageEngine`` for inspiration on how to implement paginated methods.
public protocol PaginatedStorageEngine: StorageEngine {
    associatedtype PaginationOptions
    associatedtype PaginationCursor

    func readDataAndKeys(options: PaginationOptions) -> PaginationSequence<PaginationCursor, (key: CacheKey, data: Data)>
    func readData(options: PaginationOptions) -> PaginationSequence<PaginationCursor, Data>
}

/// ``PaginationSequence`` is an ``AsyncSequence`` that can iterate over the pages fetched from ``PaginatedStorageEngine``.
public struct PaginationSequence<Cursor: Sendable, Item: Sendable>: AsyncSequence {
    public typealias Element = [Item]
    private let next: @Sendable (Cursor?) async throws -> (Cursor?, Element)

    public init(next: @Sendable @escaping (Cursor?) async throws -> (Cursor?, Element)) {
        self.next = next
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(state: AsyncPaginationSequenceState(next: next))
    }
}

public extension PaginationSequence {
    struct AsyncIterator: AsyncIteratorProtocol {
        private let state: AsyncPaginationSequenceState

        init(state: AsyncPaginationSequenceState) {
            self.state = state
        }

        public func next() async throws -> Element? {
            try await self.state.next()
        }
    }
}

extension PaginationSequence {
    actor AsyncPaginationSequenceState {
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
