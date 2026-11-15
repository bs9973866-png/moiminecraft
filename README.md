# NovaCraft

A mobile-first voxel sandbox prototype built with Unity and C#.

## Current milestone

- Seeded 16×64×16 chunk terrain.
- Exposed-face mesh generation; no GameObject per voxel.
- Chunk streaming with a per-frame generation budget and distant-chunk unloading.
- Procedural forest patches with voxel trunks and leaf crowns.
- Shallow sea-level lakes and shorelines.
- Separate transparent liquid mesh for water and lava.
- Budgeted cellular-automata liquid flow: water ticks faster and spreads farther than lava; liquids fall first, then spread sideways.
- Water/lava contact converts the contacted liquid cell into stone.
- Solid terrain mesh collider excludes liquid geometry.

## Unity setup

1. Create/open a Unity 2022.3 LTS (or newer) 3D project.
2. Copy the repository's `Assets` folder into the project.
3. Open an empty scene and add an empty GameObject.
4. Add `WorldBootstrap` from `Assets/Scripts/World/WorldBootstrap.cs`.
5. Press Play. The bootstrap creates a player, camera and nearby terrain.
6. Configure Android SDK/NDK/JDK in Unity Hub before building for Android.

## Controls

- Editor: WASD + mouse look, Space to jump.
- Touch prototype: left half moves; drag on the right half looks around.

## Performance notes

- Chunk meshes combine many voxel faces into a small number of renderers.
- Only exposed block faces are emitted.
- Liquids use a separate transparent mesh and a capped simulation budget.
- Flow simulation only processes queued active cells, not every world voxel.
- Mesh colliders are built from solid geometry only.
- This is an early prototype: profile on real Android hardware and tune chunk distance, simulation budget and transparency overdraw before release.

## Known prototype limits

- Liquids are grid-based gameplay fluids, not physically accurate fluid dynamics.
- Fluid simulation currently updates loaded chunks only; unloaded-chunk fluid persistence is not implemented yet.
- Liquid blocks currently render as shallow full-cell surfaces; per-cell fluid-height blending and waves are planned.
- World edits and fluid state are not saved yet.

## Roadmap

1. Finish terrain and liquid simulation.
2. Block breaking/placing and mobile hotbar.
3. Inventory and crafting.
4. Caves, ores, more biomes and structures.
5. Main menu, settings, world saves and mod API.

Original voxel sandbox prototype; not affiliated with Mojang or Microsoft.
