# Update Math Library

## Context

Audit of the math code in LiquidMetal2D revealed several improvements ranging from bug fixes to code organization. This plan covers Math.swift, Intersect.swift, and Circle.swift.

## Checklist

### Math.swift — Constants & Utility Functions

- [ ] **Replace custom pi with `Float.pi`** — use Swift's full-precision constant. `piOverTwo` and `twoPi` derive from it.
- [ ] **Fix `wrap` stack overflow bug** — recursive implementation will crash if value is far outside range. Replace with modulo arithmetic using `truncatingRemainder(dividingBy:)`.
- [ ] **Add `simd_clamp` convenience** — keep the generic `clamp` (one-liner: `min(max(value, low), high)`) and add a simd-specific overload for `simd_float2` that calls `simd_clamp` under the hood.
- [ ] **Add comment to `nextPowerOfTwo`** — document that passing an already-power-of-two value intentionally returns the NEXT power of two (e.g., 4 → 8).
- [ ] **Move all functions into a `GameMath` enum** — namespace them to avoid polluting global scope. Constants become static properties (`GameMath.pi`, `GameMath.epsilon`). Matches the `Intersect` enum pattern.

### Intersect.swift — Collision Tests

- [ ] **`pointLineSegment` range check may be inverted** — line 43 compares `simd_length_squared(lineVector)` as the value and `projectedLength * projectedLength` as the high bound. Should be the other way: check if the projection falls within the line's length range. Needs verification with test cases.
- [ ] **`simd_cross` on float2** — line 38 calls `simd_cross(lineVector, pointLineVector)` which requires float3. Should use the `lineVector.cross(pointLineVector)` helper we added. Cleaner and avoids any implicit conversion weirdness.
- [ ] **`circleLineSegment` edge case** — the early-out check on line 90 compares `(adjustedEndLength * adjustedEndLength) > simd_length_squared(lineVector)` but `adjustedEndLength` includes the radius offset while the line length doesn't. Could miss circles overlapping the segment endpoints. Needs verification with test cases.

### Circle.swift — Protocol Design

- [ ] **Make Circle properties get-only** — currently `center` and `radius` are `{ get set }`. Intersection tests only need `{ get }`. Making them read-only is less restrictive for conforming types.

## Notes

- Moving to `GameMath` enum is a **breaking API change** for any code calling `degreeToRadian()`, `clamp()`, etc. as free functions. The Demo project will need updating.
- The Intersect issues (pointLineSegment, circleLineSegment) should be verified with unit tests before and after changes to make sure we don't break working collision detection.
- The `simd_cross` call might actually work via implicit promotion to float3 — need to verify it compiles without the cross helper. Either way, switching to `.cross()` is cleaner.

## Verification

1. All existing tests pass
2. Add new tests for `wrap` edge cases (large values, negative values)
3. Add tests for `pointLineSegment` and `circleLineSegment` to verify correctness before/after fix
4. Demo project updated to use `GameMath.` prefix
5. Build and run demo to verify no regressions
