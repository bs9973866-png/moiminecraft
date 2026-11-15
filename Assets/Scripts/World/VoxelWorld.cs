using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace NovaCraft.World
{
    public sealed class VoxelWorld : MonoBehaviour
    {
        [Header("World")]
        [SerializeField] private int seed = 481516;
        [SerializeField, Range(1, 6)] private int renderDistance = 3;
        [SerializeField, Range(1, 2)] private int chunksPerFrame = 1;
        [SerializeField] private Transform player;
        [SerializeField] private Material chunkMaterial;
        private readonly Dictionary<Vector2Int, VoxelChunk> chunks = new Dictionary<Vector2Int, VoxelChunk>();
        private readonly Queue<Vector2Int> pending = new Queue<Vector2Int>();
        private readonly HashSet<Vector2Int> queued = new HashSet<Vector2Int>();
        private float offsetX, offsetZ;
        private Vector2Int lastCenter = new Vector2Int(int.MinValue, int.MinValue);
        public Transform Player { set => player = value; }

        private void Start()
        {
            Random.InitState(seed);
            offsetX = Random.Range(-10000f, 10000f);
            offsetZ = Random.Range(-10000f, 10000f);
            if (chunkMaterial == null)
            {
                Shader shader = Shader.Find("NovaCraft/VoxelVertexColor");
                if (shader == null) shader = Shader.Find("Unlit/Color");
                chunkMaterial = new Material(shader);
            }
            RefreshQueue();
            StartCoroutine(GenerateLoop());
        }

        private void Update()
        {
            if (player == null) return;
            Vector2Int center = PlayerChunk();
            if (center != lastCenter)
            {
                lastCenter = center;
                UnloadDistantChunks(center);
                RefreshQueue();
            }
        }

        private Vector2Int PlayerChunk() => new Vector2Int(Mathf.FloorToInt(player.position.x / VoxelChunk.Width), Mathf.FloorToInt(player.position.z / VoxelChunk.Width));

        private void UnloadDistantChunks(Vector2Int center)
        {
            int keepDistance = renderDistance + 1;
            var remove = new List<Vector2Int>();
            foreach (var pair in chunks)
                if ((pair.Key - center).sqrMagnitude > keepDistance * keepDistance) remove.Add(pair.Key);
            foreach (var key in remove)
            {
                Destroy(chunks[key].gameObject);
                chunks.Remove(key);
            }
            int count = pending.Count;
            for (int i = 0; i < count; i++)
            {
                Vector2Int key = pending.Dequeue();
                if ((key - center).sqrMagnitude <= renderDistance * renderDistance) pending.Enqueue(key);
                else queued.Remove(key);
            }
        }

        private void RefreshQueue()
        {
            if (player == null) return;
            Vector2Int center = PlayerChunk();
            var candidates = new List<Vector2Int>();
            for (int x = -renderDistance; x <= renderDistance; x++)
            for (int z = -renderDistance; z <= renderDistance; z++)
            {
                if (x*x + z*z > renderDistance*renderDistance) continue;
                Vector2Int key = new Vector2Int(center.x + x, center.y + z);
                if (!chunks.ContainsKey(key) && queued.Add(key)) candidates.Add(key);
            }
            candidates.Sort((a,b) => (a-center).sqrMagnitude.CompareTo((b-center).sqrMagnitude));
            foreach (var key in candidates) pending.Enqueue(key);
        }

        private IEnumerator GenerateLoop()
        {
            while (true)
            {
                int count = 0;
                while (pending.Count > 0 && count < chunksPerFrame)
                {
                    Vector2Int key = pending.Dequeue();
                    queued.Remove(key);
                    if (!chunks.ContainsKey(key) && player != null &&
                        (key - PlayerChunk()).sqrMagnitude <= (renderDistance + 1) * (renderDistance + 1))
                        CreateChunk(key);
                    count++;
                    yield return null;
                }
                yield return null;
            }
        }

        private void CreateChunk(Vector2Int key)
        {
            var go = new GameObject("Chunk_" + key.x + "_" + key.y);
            go.transform.SetParent(transform, false);
            go.transform.position = new Vector3(key.x * VoxelChunk.Width, 0, key.y * VoxelChunk.Width);
            VoxelChunk chunk = go.AddComponent<VoxelChunk>();
            chunk.Initialize(chunkMaterial);
            for (int x = 0; x < VoxelChunk.Width; x++)
            for (int z = 0; z < VoxelChunk.Width; z++)
            {
                int worldX = key.x * VoxelChunk.Width + x;
                int worldZ = key.y * VoxelChunk.Width + z;
                float broad = Mathf.PerlinNoise((worldX + offsetX) * 0.008f, (worldZ + offsetZ) * 0.008f);
                float detail = Mathf.PerlinNoise((worldX + offsetX + 1700f) * 0.035f, (worldZ + offsetZ + 1700f) * 0.035f);
                int surface = Mathf.Clamp(20 + Mathf.RoundToInt(broad * 25f + detail * 5f), 2, VoxelChunk.Height - 2);
                for (int y = 0; y <= surface; y++)
                {
                    BlockType type = y == surface ? BlockType.Grass : y >= surface - 3 ? BlockType.Dirt : BlockType.Stone;
                    chunk.SetBlock(x, y, z, type);
                }
            }
            chunk.BuildMesh();
            chunks.Add(key, chunk);
        }
    }
}