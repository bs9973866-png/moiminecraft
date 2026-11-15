using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace NovaCraft.World
{
    [RequireComponent(typeof(MeshFilter), typeof(MeshRenderer), typeof(MeshCollider))]
    public sealed class VoxelChunk : MonoBehaviour
    {
        public const int Width = 16;
        public const int Height = 64;
        private BlockType[,,] blocks;
        private MeshFilter meshFilter;
        private MeshCollider meshCollider;
        private Mesh mesh;

        public void Initialize(Material material)
        {
            meshFilter = GetComponent<MeshFilter>();
            meshCollider = GetComponent<MeshCollider>();
            GetComponent<MeshRenderer>().sharedMaterial = material;
            blocks = new BlockType[Width, Height, Width];
        }

        public void SetBlock(int x, int y, int z, BlockType type)
        {
            if (Inside(x, y, z)) blocks[x, y, z] = type;
        }

        private BlockType GetBlock(int x, int y, int z)
        {
            return Inside(x, y, z) ? blocks[x, y, z] : BlockType.Air;
        }

        public void BuildMesh()
        {
            var vertices = new List<Vector3>(12000);
            var triangles = new List<int>(18000);
            var colors = new List<Color>(12000);
            for (int x = 0; x < Width; x++)
            for (int y = 0; y < Height; y++)
            for (int z = 0; z < Width; z++)
            {
                BlockType block = blocks[x, y, z];
                if (block == BlockType.Air) continue;
                AddVisibleFaces(x, y, z, block, vertices, triangles, colors);
            }
            if (mesh != null) Destroy(mesh);
            mesh = new Mesh { indexFormat = vertices.Count > 65000 ? IndexFormat.UInt32 : IndexFormat.UInt16 };
            mesh.name = "VoxelChunkMesh";
            mesh.SetVertices(vertices);
            mesh.SetTriangles(triangles, 0, true);
            mesh.SetColors(colors);
            mesh.RecalculateNormals();
            meshFilter.sharedMesh = mesh;
            meshCollider.sharedMesh = null;
            meshCollider.sharedMesh = mesh;
        }

        private void AddVisibleFaces(int x, int y, int z, BlockType block, List<Vector3> v, List<int> t, List<Color> c)
        {
            Color tint = block == BlockType.Grass ? new Color(0.42f, 0.72f, 0.28f) :
                         block == BlockType.Dirt ? new Color(0.48f, 0.31f, 0.18f) :
                         block == BlockType.Sand ? new Color(0.82f, 0.75f, 0.49f) : new Color(0.52f, 0.53f, 0.56f);
            if (GetBlock(x, y + 1, z) == BlockType.Air) Face(new Vector3(x,y+1,z), new Vector3(x,y+1,z+1), new Vector3(x+1,y+1,z+1), new Vector3(x+1,y+1,z), tint, v,t,c);
            if (GetBlock(x, y - 1, z) == BlockType.Air) Face(new Vector3(x,y,z), new Vector3(x+1,y,z), new Vector3(x+1,y,z+1), new Vector3(x,y,z+1), tint * 0.72f, v,t,c);
            if (GetBlock(x - 1, y, z) == BlockType.Air) Face(new Vector3(x,y,z), new Vector3(x,y,z+1), new Vector3(x,y+1,z+1), new Vector3(x,y+1,z), tint * 0.86f, v,t,c);
            if (GetBlock(x + 1, y, z) == BlockType.Air) Face(new Vector3(x+1,y,z+1), new Vector3(x+1,y,z), new Vector3(x+1,y+1,z), new Vector3(x+1,y+1,z+1), tint * 0.86f, v,t,c);
            if (GetBlock(x, y, z - 1) == BlockType.Air) Face(new Vector3(x+1,y,z), new Vector3(x,y,z), new Vector3(x,y+1,z), new Vector3(x+1,y+1,z), tint * 0.92f, v,t,c);
            if (GetBlock(x, y, z + 1) == BlockType.Air) Face(new Vector3(x,y,z+1), new Vector3(x+1,y,z+1), new Vector3(x+1,y+1,z+1), new Vector3(x,y+1,z+1), tint * 0.92f, v,t,c);
        }

        private static void Face(Vector3 a, Vector3 b, Vector3 c0, Vector3 d, Color color, List<Vector3> vertices, List<int> triangles, List<Color> colors)
        {
            int i = vertices.Count;
            vertices.Add(a); vertices.Add(b); vertices.Add(c0); vertices.Add(d);
            triangles.Add(i); triangles.Add(i + 1); triangles.Add(i + 2);
            triangles.Add(i); triangles.Add(i + 2); triangles.Add(i + 3);
            colors.Add(color); colors.Add(color); colors.Add(color); colors.Add(color);
        }

        private static bool Inside(int x, int y, int z) => x >= 0 && x < Width && y >= 0 && y < Height && z >= 0 && z < Width;
        private void OnDestroy() { if (mesh != null) Destroy(mesh); }
    }
}
