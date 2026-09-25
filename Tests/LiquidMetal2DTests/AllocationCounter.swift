import Darwin
import XCTest

/// Counts heap allocations made on the calling thread while `body` runs.
///
/// Uses Darwin's `malloc_logger` hook, which the allocator calls on every
/// allocation when it is set (it is how Malloc Stack Logging works). Only
/// the calling thread counts, so XCTest's own background threads don't add
/// noise. Tests must run one warm-up pass before counting, so that one-time
/// growth (array capacity, lazy statics) isn't counted.
///
/// `testCounterSeesAllocations` is the positive control: if the hook ever
/// stops firing, it fails, instead of every zero-allocation test passing
/// for the wrong reason.
enum AllocationCounter {

    static func count(_ body: () -> Void) -> Int {
        guard let hook = loggerSlot else {
            XCTFail("malloc_logger symbol not found; allocation counting unavailable")
            return -1
        }
        countedThread = pthread_self()
        allocations = 0
        hook.pointee = record
        body()
        hook.pointee = nil
        countedThread = nil
        return allocations
    }

    private typealias MallocLogger = @convention(c) (UInt32, UInt, UInt, UInt, UInt, UInt32) -> Void

    /// `MALLOC_LOG_TYPE_ALLOCATE` from libmalloc's stack_logging.h.
    private static let allocateFlag: UInt32 = 2

    nonisolated(unsafe) private static var countedThread: pthread_t?
    nonisolated(unsafe) private static var allocations = 0

    nonisolated(unsafe) private static let loggerSlot: UnsafeMutablePointer<MallocLogger?>? = {
        // RTLD_DEFAULT is ((void *)-2) on Darwin.
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = dlsym(rtldDefault, "malloc_logger") else { return nil }
        return symbol.assumingMemoryBound(to: MallocLogger?.self)
    }()

    private static let record: MallocLogger = { type, _, _, _, _, _ in
        guard type & AllocationCounter.allocateFlag != 0,
              let thread = AllocationCounter.countedThread,
              pthread_equal(pthread_self(), thread) != 0 else { return }
        AllocationCounter.allocations += 1
    }
}
