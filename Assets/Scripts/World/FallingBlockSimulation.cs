using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    /// <summary>Budgeted gravity for sand and gravel. Only positions near edits are checked.</summary>
    public sealed class FallingBlockSimulation : MonoBehaviour
    {
        [SerializeField, Range(0.05f, 1f)] private float tickInterval = 0.18f;
        [SerializeField, Range(4, 64)] private int checksPerTick = 20;
        private readonly Queue<Vector3Int> pending = new Queue<Vector3Int>();
        private readonly HashSet<Vector3Int> queued = new HashSet<Vector3Int>();
        private VoxelWorld world;
        private float elapsed;

        public void Initialize(VoxelWorld voxelWorld) { world = voxelWorld; }

        public void NotifyChanged(Vector3Int changed)
        {
            Enqueue(changed + Vector3Int.up);
            Enqueue(changed + Vector3Int.up * 2);
        }

        private void Enqueue(Vector3Int p)
        {
            if (p.y > 0 && p.y < VoxelChunk.Height && queued.Add(p)) pending.Enqueue(p);
        }

        private void Update()
        {
            if (world == null || pending.Count == 0) return;
            elapsed += Time.deltaTime;
            if (elapsed < tickInterval) return;
            elapsed = 0f;
            int count = Mathf.Min(checksPerTick, pending.Count);
            for (int i = 0; i < count; i++)
            {
                Vector3Int p = pending.Dequeue();
                queued.Remove(p);
                BlockType block = world.GetBlock(p);
                if (block != BlockType.Sand && block != BlockType.Gravel) continue;
                Vector3Int below = p + Vector3Int.down;
                BlockType support = world.GetBlock(below);
                if (support != BlockType.Air && support != BlockType.Water && support != BlockType.Lava) continue;
                if (!world.SetBlock(p, BlockType.Air)) continue;
                if (!world.SetBlock(below, block)) world.SetBlock(p, block);
                Enqueue(p + Vector3Int.up);
                Enqueue(p + Vector3Int.up * 2);
            }
        }
    }
}