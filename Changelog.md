### [2.1.1] - 2026-04-09

#### Performance Optimizations
- **Reduced Scan Frequency**: Implemented a scan interval that triggers even when no target is found, preventing per-frame raycasts and limiting idle scans to 10 times per second.
- **Early Rejection Logic**: Refined target search loops to perform low-cost priority, range, and distance checks before executing expensive mathematical operations or visibility raycasts.
- **Squared Distance Comparison**: Replaced `Vector3.distance` with squared distance calculations (`Vector3.distance_squared`) to avoid unnecessary square root operations during bulk unit filtering.
- **Comprehensive Caching**:
    - Enhanced visibility cache with frame-specific duration.
    - Introduced unit metadata caching to avoid redundant `ScriptUnit.extension` calls and breed lookups.
    - Implemented frame-level caching for expensive engine calls like `Unit.box` and `Actor.world_bounds`.
- **Lua Efficiency**:
    - Localized frequently used global functions and engine methods (`math.sqrt`, `Unit.alive`, `pairs`, etc.) to improve execution speed.
    - Replaced `pairs` with numeric loops in hot code paths to reduce GC pressure and CPU overhead.
- **Deferred Processing**: Postponed heavy geometry and visibility calculations until after a candidate has passed all cheaper filters.

#### Stability and Bug Fixes
- **Nil Hit Protection**: Added defensive checks to handle nil results from `PhysicsWorld.raycast`, preventing crashes during intense combat.
- **Invalid Actor Handling**: Wrapped `Actor.unit` calls in `pcall` and added distance thresholds to gracefully handle internal engine colliders or stale userdata.
- **Unit Lifecycle Management**: Integrated `Unit.alive` checks throughout the targeting logic to prevent errors when units are destroyed mid-scan.
- **Cache Management**: Added automated cleanup for metadata and visibility caches every 100 frames to maintain a low memory footprint.

#### Logic Refinements
- **Early Escapes**: Consolidated marking conditions (cooldowns, manual mark presence, class settings) to skip the entire scanning process as early as possible.
- **Contextual Fetching**: Moved expensive extension lookups (like player buffs and companion state) out of the unit loops, passing pre-calculated data instead.
- **Improved Targeting Consistency**: Ensured that focus targets and execution order priorities are respected without redundant scanning passes.
