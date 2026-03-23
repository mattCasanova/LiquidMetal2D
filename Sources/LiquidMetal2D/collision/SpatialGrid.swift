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
    /// Uses half-neighbor traversal: for each cell, pairs objects within the
    /// cell, then pairs with the 4 forward neighbors (right, below-left,
    /// below, below-right). This visits each cell-pair exactly once, so
    /// no deduplication is needed.
    public func potentialPairs() -> [(GameObj, GameObj)] {
        var result = [(GameObj, GameObj)]()

        for row in 0..<rows {
            for col in 0..<columns {
                let cell = cells[flatIndex(column: col, row: row)]
                guard !cell.isEmpty else { continue }

                // Pair objects within this cell
                for i in 0..<cell.count {
                    for j in (i + 1)..<cell.count {
                        result.append((cell[i], cell[j]))
                    }
                }

                // Pair with 4 forward neighbors to avoid double-counting
                let neighbors = [
                    (col + 1, row),       // right
                    (col - 1, row + 1),   // below-left
                    (col,     row + 1),   // below
                    (col + 1, row + 1),   // below-right
                ]

                for (nc, nr) in neighbors {
                    guard nc >= 0, nc < columns, nr >= 0, nr < rows else { continue }
                    let neighbor = cells[flatIndex(column: nc, row: nr)]
                    guard !neighbor.isEmpty else { continue }

                    for objA in cell {
                        for objB in neighbor {
                            result.append((objA, objB))
                        }
                    }
                }
            }
        }
        return result
    }

    /// Calls the closure for each candidate collision pair. Zero allocation.
    ///
    /// Same half-neighbor traversal as ``potentialPairs()`` but avoids
    /// building an array. Use this in hot loops where allocation matters.
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

                let neighbors = [
                    (col + 1, row),
                    (col - 1, row + 1),
                    (col,     row + 1),
                    (col + 1, row + 1),
                ]

                for (nc, nr) in neighbors {
                    guard nc >= 0, nc < columns, nr >= 0, nr < rows else { continue }
                    let neighbor = cells[flatIndex(column: nc, row: nr)]
                    guard !neighbor.isEmpty else { continue }

                    for objA in cell {
                        for objB in neighbor {
                            body(objA, objB)
                        }
                    }
                }
            }
        }
    }

    /// Returns all objects in the same cell as the position, plus all 8
    /// neighboring cells.
    ///
    /// Positions outside the grid bounds are clamped to the nearest edge cell.
    public func query(near position: Vec2) -> [GameObj] {
        let (col, row) = cellIndex(for: position)
        var result = [GameObj]()

        for dr in -1...1 {
            for dc in -1...1 {
                let nc = col + dc
                let nr = row + dr
                guard nc >= 0, nc < columns, nr >= 0, nr < rows else { continue }
                result.append(contentsOf: cells[flatIndex(column: nc, row: nr)])
            }
        }
        return result
    }

    /// Returns all objects near the given object's position,
    /// excluding the object itself.
    public func query(near obj: GameObj) -> [GameObj] {
        return query(near: obj.position).filter { $0 !== obj }
    }

    // MARK: - Private Helpers

    /// Converts a world position to a (column, row) cell index,
    /// clamping to grid bounds.
    private func cellIndex(for position: Vec2) -> (column: Int, row: Int) {
        let col = max(0, min(Int((position.x - bounds.minX) / cellWidth), columns - 1))
        let row = max(0, min(Int((position.y - bounds.minY) / cellHeight), rows - 1))
        return (col, row)
    }

    /// Converts (column, row) to flat array index.
    private func flatIndex(column: Int, row: Int) -> Int {
        return row * columns + column
    }
}
