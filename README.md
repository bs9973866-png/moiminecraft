# NovaCraft

**Active engine: Godot 4.5.1.** The Android APK is built from the Godot project using GitHub Actions. The Unity C# files in `Assets/` are retained as a legacy/reference implementation and are not currently part of the active APK build.

## Current mobile gameplay

- Android-first Godot project using the GL Compatibility renderer.
- Procedural 64×64 voxel terrain with grass, dirt, stone, trees, wood and leaves.
- One exposed-face mesh and one collision mesh; no scene object is created for each block.
- Touch movement, look, jump, break and place controls.
- 24-slot inventory with stack limits and an 8-slot clickable hotbar.
- Two-tap item transfer between inventory slots: matching stacks merge up to 64; different items swap.
- Basic crafting: 1 wood → 4 planks, 2 planks → 4 sticks, 4 planks → 1 crafting table.
- Wooden and stone pickaxes can be crafted only when a placed crafting table is nearby.
- The crafting table is a real placeable block with its own atlas tile.
- Breaking a block is prevented when the inventory has no room for its drop.
- Inventory and world edits are saved locally. World saves now store only player-made changes against deterministic generated terrain; older version-2 full-world saves are migrated.

## Build an Android APK

1. Open **Actions** in this repository.
2. Select the Android APK build workflow and run it.
3. Wait for the workflow to finish.
4. Download the APK artifact from the run summary.

The active Godot workflow does not require a Unity license. This repository has not been verified on a physical Android device as part of the current inventory/crafting change.

## Controls

- Android: left-side arrows move; drag on the right side to look; buttons on the right jump, break and place; tap a hotbar slot to select it.
- Inventory: open the inventory, tap one slot, then tap another to move/merge/swap its stack. Tap the same slot again to cancel.
- Keyboard: WASD / arrow keys move, Space jumps. Hold right mouse and move to look around.

## Known limitations

- The current Godot port still has a single terrain mesh. Mesh and collision rebuilds are deferred and coalesced, but a large edit still rebuilds the terrain mesh; chunk-local rebuilds are a future optimization.
- Tools are inventory/crafting items; tool-specific mining speed and durability are not yet implemented in the active Godot port.
- Fluids, caves, ores, advanced recipes and full chunk streaming are not yet ported to Godot.
- UI scaling and touch hit areas still need real-device testing.

NovaCraft is an independent voxel sandbox and is not affiliated with Mojang or Microsoft.
