# NovaCraft

A mobile-first voxel sandbox prototype built with Unity and C#.

## Current milestone

- Seeded 16×64×16 chunk terrain.
- Exposed-face mesh generation; no GameObject per voxel.
- Chunk streaming with a per-frame generation budget and distant-chunk unloading.
- Procedural forest patches with voxel trunks and leaf crowns.
- Underground coal, iron, gold and diamond ore deposits with depth-based rarity.
- Gravel deposits and bedrock floor.
- Budgeted falling sand/gravel physics triggered by nearby block edits.
- Shallow sea-level lakes and shorelines.
- Rare underground pockets with lava springs.
- Separate transparent liquid mesh for water and lava.
- Budgeted cellular-automata liquid flow: water ticks faster and spreads farther than lava; liquids fall first, then spread sideways.
- Water/lava contact converts the contacted liquid cell into stone.
- Touch-first block breaking and placing with a five-slot hotbar and a 24-slot stack inventory.
- Inventory contents, hotbar selection, tool durability and player-made block edits are saved locally with PlayerPrefs; world edits are separated by world seed and restored when chunks load.
- Mobile inventory screen with tap-to-select, stack merging and slot swapping.
- Starter crafting recipes: one log makes four planks; two planks make four sticks; four planks make a crafting table; three planks/stone/iron ore plus two sticks make a pickaxe.
- Wooden, stone and iron pickaxes have individual durability; wooden mines stone/coal, stone mines stone/coal/iron, and iron mines all current ores.
- Solid terrain mesh collider excludes liquid geometry.

## Unity setup

1. Create/open a Unity 2022.3 LTS (or newer) 3D project.
2. Copy the repository's `Assets` folder into the project.
3. Open an empty scene and add an empty GameObject.
4. Add `WorldBootstrap` from `Assets/Scripts/World/WorldBootstrap.cs`.
5. Press Play. The bootstrap creates a player, camera and nearby terrain.
6. Configure Android SDK/NDK/JDK in Unity Hub before building for Android.

## Controls

- Editor: WASD + mouse look, Space to jump, left mouse breaks, right mouse places, number keys 1–5 select hotbar slots.
- Android: left half moves; drag on the right half looks around; BREAK and PLACE edit the targeted block; tap a hotbar slot to select a block; JUMP requests a jump; INV opens the inventory. In the inventory, tap one slot and then another to move, swap or merge stacks. Crafted pickaxes are non-stackable and show remaining durability.

## Performance notes

- Chunk meshes combine many voxel faces into a small number of renderers.
- Only exposed block faces are emitted.
- Liquids use a separate transparent mesh and a capped simulation budget.
- Flow simulation only processes queued active cells, not every world voxel.
- Sand and gravel checks are queued near terrain edits instead of scanning the world.
- Mesh colliders are built from solid geometry only.
- This is an early prototype: profile on real Android hardware and tune chunk distance, simulation budget and transparency overdraw before release.

## Known prototype limits

- Liquids are grid-based gameplay fluids, not physically accurate fluid dynamics.
- Fluid simulation currently updates loaded chunks only; unloaded-chunk fluid persistence is not implemented yet.
- Liquid blocks currently render as shallow full-cell surfaces; per-cell fluid-height blending and waves are planned.
- Fluid simulation state and unloaded-chunk liquid flow are not saved; only player-made block edits are persisted. The touch UI still needs device testing.
- The touch UI is an initial prototype and needs device testing for different aspect ratios and safe areas.

## Roadmap

1. Improve caves and liquid surfaces.
2. Add axes/shovels, mining progress, world saves and more crafting recipes.
3. Add world saves and more biomes/structures.
4. Add main menu, settings and mod API.

Original voxel sandbox prototype; not affiliated with Mojang or Microsoft.
