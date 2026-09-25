/// A uniform grid for broadphase collision detection.
///
/// Divides a ``WorldBounds`` region into fixed-size cells. Objects are
/// inserted by position each frame, and the grid returns candidate pairs
/// that share cells — the consumer performs narrowphase checks on those pairs.
///
/// The grid is designed to be cleared and rebuilt every frame:
/// ```swift
/// grid.clear()
/// grid.insert(contentsOf: objects)
/// for (a, b) in grid.potentialPairs() {
///     if a.collider.doesCollideWith(collider: b.collider) { ... }
/// }
/// ```
///
/// **Cell size guidance:** set cell size >= the diameter of the largest
/// object. Objects insert by position only; ``potentialPairs()`` checks
/// each cell plus its forward neighbors, so collisions within one cell
/// width across boundaries are always found.
@MainActor
public class SpatialGrid {

    /// The world region this grid covers.
    public let bounds: WorldBounds

    /// Width of each cell in world units.
    public let cellWidth: Float

    /// Height of each cell in world units.
    public let cellHeight: Float

    /// Number of columns in the grid.
    public let columns: Int

    /// Number of rows in the grid.
    public let rows: Int

    /// Flat array of buckets. Index = row * columns + column.
    private var cells: [[GameObj]]

    /// Creates a grid with explicit cell dimensions.
    ///
    /// - Parameters:
    ///   - bounds: The world region to partition.
    ///   - cellWidth: Width of each cell in world units. Must be > 0.
    ///   - cellHeight: Height of each cell in world units. Must be > 0.
    public init(bounds: WorldBounds, cellWidth: Float, cellHeight: Float) {
        precondition(cellWidth > 0, "cellWidth must be > 0")
        precondition(cellHeight > 0, "cellHeight must be > 0")

        self.bounds = bounds
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.columns = max(1, Int(ceil(bounds.width / cellWidth)))
        self.rows = max(1, Int(ceil(bounds.height / cellHeight)))
        self.cells = Array(repeating: [GameObj](), count: rows * columns)
    }

    /// Creates a grid with a given number of rows and columns.
    ///
    /// - Parameters:
    ///   - bounds: The world region to partition.
    ///   - columns: Number of columns. Must be >= 1.
    ///   - rows: Number of rows. Must be >= 1.
    public init(bounds: WorldBounds, columns: Int, rows: Int) {
        precondition(columns >= 1, "columns must be >= 1")
        precondition(rows >= 1, "rows must be >= 1")

        self.bounds = bounds
        self.columns = columns
        self.rows = rows
        self.cellWidth = bounds.width / Float(columns)
        self.cellHeight = bounds.height / Float(rows)
        self.cells = Array(repeating: [GameObj](), count: rows * columns)
    }

    // MARK: - Core Operations

    /// Removes all objects from every cell. Call once per frame before inserting.
    public func clear() {
        for i in 0..<cells.count {
            cells[i].removeAll(keepingCapacity: true)
        }
    }

    /// Inserts an object into the cell containing its position.
    ///
    /// Objects outside the grid bounds are clamped to the nearest edge cell.
    /// Inactive objects are silently skipped.
    public func insert(_ obj: GameObj) {
        guard obj.isActive else { return }
        let (col, row) = cellIndex(for: obj.position)
        cells[flatIndex(column: col, row: row)].append(obj)
    }

    /// Inserts all active objects from the array.
    public func insert(contentsOf objects: [GameObj]) {
        for obj in objects {
            insert(obj)
        }
    }

    /// Returns all candidate collision pairs.
    ///
    /// Allocates the returned array. In a per-frame loop, prefer
    /// ``forEachPotentialPair(_:)``, which allocates nothing.
    public func potentialPairs() -> [(GameObj, GameObj)] {
        var result = [(GameObj, GameObj)]()
        forEachPotentialPair { result.append(($0, $1)) }
        return result
    }

    /// Calls the closure for each candidate collision pair. Allocates nothing
    /// in optimized builds (pinned by `AllocationTests`).
    ///
    /// Uses half-neighbor traversal: for each cell, pairs objects within the
    /// cell, then pairs with the 4 forward neighbors (right, below-left,
    /// below, below-right). This visits each cell-pair exactly once, so
    /// no deduplication is needed.
    public func forEachPotentialPair(_ body: (GameObj, GameObj) -> Void) {
        for row in 0..<rows {
            for col in 0..<columns {
                let cell = cells[flatIndex(column: col, row: row)]
                guard !cell.isEmpty else { continue }

                for i in 0..<cell.count {
                    for j in (i + 1)..<cell.count {
                        body(cell[i], cell[j])
                    }
                }

                // Four explicit calls, not an array of offsets. The optimizer
                // stack-promotes such an array in Release, but Debug builds
                // heap-allocate it once per cell per frame.
                pairAcross(cell, column: col + 1, row: row, body)
                pairAcross(cell, column: col - 1, row: row + 1, body)
                pairAcross(cell, column: col, row: row + 1, body)
                pairAcross(cell, column: col + 1, row: row + 1, body)
            }
        }
    }

    /// Returns all objects in the same cell as the position, plus all 8
    /// neighboring cells.
    ///
    /// Positions outside the grid bounds are clamped to the nearest edge cell.
    /// Allocates the returned array; in a per-object, per-frame loop prefer
    /// ``forEachNear(_:_:)``.
    public func query(near position: Vec2) -> [GameObj] {
        var result = [GameObj]()
        forEachNear(position) { result.append($0) }
        return result
    }

    /// Returns all objects near the given object's position,
    /// excluding the object itself.
    public func query(near obj: GameObj) -> [GameObj] {
        var result = [GameObj]()
        forEachNear(obj.position) { other in
            if other !== obj { result.append(other) }
        }
        return result
    }

    /// Calls the closure for every object in the position's cell and its 8
    /// neighbors. Allocates nothing in optimized builds, so it suits "what's
    /// near me?" for every object every frame.
    ///
    /// Positions outside the grid bounds are clamped to the nearest edge cell.
    public func forEachNear(_ position: Vec2, _ body: (GameObj) -> Void) {
        let (col, row) = cellIndex(for: position)
        for nr in (row - 1)...(row + 1) where nr >= 0 && nr < rows {
            for nc in (col - 1)...(col + 1) where nc >= 0 && nc < columns {
                for obj in cells[flatIndex(column: nc, row: nr)] {
                    body(obj)
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Converts a world position to a (column, row) cell index,
    /// clamping to grid bounds.
    private func cellIndex(for position: Vec2) -> (column: Int, row: Int) {
        return (
            axisIndex((position.x - bounds.minX) / cellWidth, count: columns),
            axisIndex((position.y - bounds.minY) / cellHeight, count: rows))
    }

    /// Clamps as a Float before converting, because `Int(_:)` traps on NaN
    /// and on values past `Int.max`. A NaN position is a bug upstream, so
    /// debug builds assert; release builds put the object in the first cell
    /// rather than crash the game.
    private func axisIndex(_ raw: Float, count: Int) -> Int {
        assert(!raw.isNaN, "SpatialGrid: position is NaN")
        guard !raw.isNaN else { return 0 }
        return Int(GameMath.clamp(value: raw, low: 0, high: Float(count - 1)))
    }

    /// Pairs every object in `cell` with every object in the cell at
    /// (column, row), if that cell exists.
    private func pairAcross(
        _ cell: [GameObj], column: Int, row: Int, _ body: (GameObj, GameObj) -> Void
    ) {
        guard column >= 0, column < columns, row >= 0, row < rows else { return }
        let neighbor = cells[flatIndex(column: column, row: row)]
        for objA in cell {
            for objB in neighbor {
                body(objA, objB)
            }
        }
    }

    /// Converts (column, row) to flat array index.
    private func flatIndex(column: Int, row: Int) -> Int {
        return row * columns + column
    }
}
