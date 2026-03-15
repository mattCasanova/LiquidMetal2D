# Update Math Library

## Context

Audit of the math code in LiquidMetal2D revealed several improvements ranging from bug fixes to code organization. This plan covers Math.swift, Intersect.swift, and Circle.swift.

## Checklist

### Math.swift — Constants & Utility Functions

- [ ] **Replace custom pi with `Float.pi`** — use Swift's full-precision constant. `piOverTwo` and `twoPi` derive from it.
- [ ] **Fix `wrap` stack overflow risk** — recursive implementation works for reasonable values but is theoretically risky for extreme ones. Replace with modulo arithmetic using `truncatingRemainder(dividingBy:)`.
- [ ] **Add `simd_clamp` convenience** — keep the generic `clamp` (one-liner: `min(max(value, low), high)`) and add a simd-specific overload for `simd_float2` that calls `simd_clamp` under the hood.
- [ ] **Add comment to `nextPowerOfTwo`** — document that passing an already-power-of-two value intentionally returns the NEXT power of two (e.g., 4 → 8).
- [ ] **Move all functions into a `GameMath` enum** — namespace them to avoid polluting global scope. Constants become static properties (`GameMath.pi`, `GameMath.epsilon`). Matches the `Intersect` enum pattern.

### Intersect.swift — Collision Tests

- [x] **`pointLineSegment` range check was inverted** — FIXED in 0.3.3. The `isInRange` arguments were swapped — it was checking if the line length was in range of the projection instead of vice versa. Confirmed with 3 failing tests, now all passing.
- [x] **`simd_cross` on float2** — FIXED in 0.3.3. Replaced with `lineVector.cross(pointLineVector)` using our helper.
- [x] **`circleLineSegment` edge case** — VERIFIED correct. Wrote 8 edge case tests (perpendicular near miss, endpoint overlap, before start, past end, diagonal, etc.) — all passed. No bug here.

### Circle.swift — Protocol Design

- [ ] **Make Circle properties get-only** — currently `center` and `radius` are `{ get set }`. Intersection tests only need `{ get }`. Making them read-only is less restrictive for conforming types.

### Previously completed (earlier commits)

- [x] **Intersect class → enum** — prevents accidental instantiation (0.3.2)
- [x] **setToZero() cleanup** — replaced `memset` with `self = simd_float4x4()` (0.3.2)
- [x] **Added length/lengthSquared/normalized** — to simd_float2 and simd_float3 (0.3.2)
- [x] **Added cross() helper** — 2D cross product on simd_float2 (0.3.1)
- [x] **99 tests written** — covering math utilities, SIMD extensions, matrices, and all intersection methods (0.3.3)

## Notes

- Moving to `GameMath` enum is a **breaking API change** for any code calling `degreeToRadian()`, `clamp()`, etc. as free functions. The Demo project will need updating.
- The `wrap` function works for all tested values including 1000 and -1000, but the recursive approach is still theoretically O(n) for extreme inputs.

## Verification

1. ~~Add new tests for math, SIMD, intersect~~ — done (99 tests)
2. ~~Verify pointLineSegment bug and fix~~ — done
3. ~~Verify circleLineSegment edge cases~~ — done, all pass
4. Demo project updated to use `GameMath.` prefix (when enum migration happens)
5. Build and run demo to verify no regressions
