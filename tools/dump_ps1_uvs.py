import bpy
import os
from mathutils import Vector

out = r"c:\Users\morrayne\Desktop\gamedev\godot\told-you-so\assets\textures\ps1"


def uv_bounds(obj):
    mesh = obj.data
    if not mesh.uv_layers:
        print(f"{obj.name}: NO UV")
        return
    uv = mesh.uv_layers.active.data
    xs = []
    ys = []
    for loop in mesh.loops:
        c = uv[loop.index].uv
        xs.append(c.x)
        ys.append(c.y)
    print(
        f"{obj.name} verts={len(mesh.vertices)} loops={len(mesh.loops)} "
        f"uv u=[{min(xs):.3f},{max(xs):.3f}] v=[{min(ys):.3f},{max(ys):.3f}]"
    )
    # Face-island centroids in UV
    islands = []
    for poly in mesh.polygons:
        u = 0.0
        v = 0.0
        for li in poly.loop_indices:
            u += uv[li].uv.x
            v += uv[li].uv.y
        n = float(len(poly.loop_indices))
        islands.append((u / n, v / n, poly.index))
    # Cluster by 0.05 grid
    buckets = {}
    for u, v, pi in islands:
        key = (round(u * 8) / 8, round(v * 8) / 8)
        buckets.setdefault(key, 0)
        buckets[key] += 1
    print("  uv clusters (u,v,faces):")
    for k, c in sorted(buckets.items(), key=lambda kv: -kv[1])[:20]:
        print(f"    {k} x{c}")


for name in ["PS1Console_M_PS1_0", "PS1Controller_M_PS1_0"]:
    obj = bpy.data.objects.get(name)
    if obj:
        uv_bounds(obj)
    else:
        print("missing", name)
