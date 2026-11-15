# NovaCraft

A mobile-first voxel sandbox prototype built with Unity and C#.

## Current milestone: procedural terrain foundation

- Deterministic seeded terrain using Unity Perlin noise.
- 16×64×16 chunks with exposed-face mesh generation (no GameObject per block).
- One shared material and vertex colors to keep draw calls low.
- Mesh colliders generated per chunk.
- Configurable render distance and chunk generation budget.
- Runtime bootstrap for a first playable terrain prototype.

## Unity setup

1. Create/open a Unity 3D project (Unity 2022.3 LTS or newer).
2. Copy this repository's `Assets` folder into the project.
3. Open an empty scene and add an empty GameObject named `World`.
4. Add the `WorldBootstrap` component from `Assets/Scripts/World/WorldBootstrap.cs`.
5. Press Play. The bootstrap creates a player camera, basic movement and nearby terrain.
6. For Android, switch Build Settings to Android and configure the required Android SDK/NDK/JDK in Unity Hub.

## Controls

- Editor: WASD + mouse look, Space to jump.
- Touch prototype: left side moves; drag on the right side looks around.

## Performance design

Chunks are meshed as a single mesh and only faces next to air are emitted. The world does not create an individual Unity object for every voxel. Chunk count, view distance and generation budget are configurable. The first milestone disables real-time shadows and uses a shared material. Profile on actual devices before increasing view distance.

## Roadmap

1. Terrain, chunk streaming and mobile controls.
2. Block breaking/placing and hotbar.
3. Inventory and crafting.
4. Trees, caves, ores, structures and biomes.
5. Main menu, settings, world saves and mod API.

This is an original voxel sandbox prototype and is not affiliated with Mojang or Microsoft.
