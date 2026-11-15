# NovaCraft

**Active engine: Godot 4.5.1.** NovaCraft is being moved to Godot so Android APK builds can run in GitHub Actions without a Unity account or Unity license.

## Current Godot port

- Android-first Godot project using the GL Compatibility renderer.
- Procedural 48×48 voxel terrain with grass, dirt and stone.
- Exposed-face mesh generation instead of one scene object per block.
- Collision mesh for the terrain.
- CharacterBody3D player with gravity, jumping, keyboard controls and touch look.
- On-screen movement, jump, break and place controls.
- Android ARM64 export preset and GitHub Actions APK workflow.

This is the first migration slice, not a complete feature-for-feature port yet. The previous Unity implementation remains in `Assets/` as a reference while its world, inventory, crafting, fluids, falling blocks and save systems are ported into Godot.

## Build an Android APK

1. Open **Actions → Build NovaCraft Android APK** in this repository.
2. Select **Run workflow**.
3. Wait for the workflow to finish.
4. Download the `NovaCraft-Android-APK` artifact from the run summary.

The Godot workflow does **not** need `UNITY_LICENSE`, `UNITY_EMAIL` or `UNITY_PASSWORD`. It uses Godot export templates and Android build tools in GitHub Actions.

## Controls

- Android: left-side arrows move; drag on the right side to look; buttons on the right jump, break and place.
- Keyboard: WASD / arrow keys move, Space jumps. Hold right mouse and move to look around.

## Next migration milestones

1. Port the 24-slot inventory, hotbar, item stacks and crafting.
2. Port block mining rules, pickaxe durability and world edit saving.
3. Add chunk streaming, trees, ores, caves, water and lava.
4. Improve touch layout and performance on the target Android phone.

The Godot build is an early testing APK, not a Play Store release. NovaCraft is an independent voxel sandbox and is not affiliated with Mojang or Microsoft.
