import bpy
import os

out_dir = r"c:\Users\morrayne\Desktop\gamedev\godot\told-you-so\assets\models\basement\hub_textures"
os.makedirs(out_dir, exist_ok=True)

print("=== IMAGES ===")
for img in bpy.data.images:
    packed = img.packed_file is not None
    print(
        f"img name={img.name!r} size={img.size[:] if img.size else None} "
        f"filepath={img.filepath!r} packed={packed} source={img.source}"
    )
    safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in img.name)
    dest = os.path.join(out_dir, safe if "." in safe else safe + ".png")
    try:
        if packed:
            img.unpack(method="WRITE_ORIGINAL")
        # Save a copy we control.
        img.filepath_raw = dest
        img.file_format = "PNG"
        img.save()
        print(f"  saved {dest} exists={os.path.exists(dest)} bytes={os.path.getsize(dest) if os.path.exists(dest) else 0}")
    except Exception as e:
        print(f"  SAVE FAIL {img.name}: {e}")

print("=== LIGHTS ===")
for obj in bpy.data.objects:
    if obj.type == "LIGHT":
        d = obj.data
        print(
            f"light {obj.name} type={d.type} energy={getattr(d, 'energy', None)} "
            f"color={tuple(round(c, 3) for c in d.color)} loc={tuple(round(x, 3) for x in obj.matrix_world.translation)}"
        )

print("=== PS / GAMEPAD / MATERIALS ===")
for obj in bpy.data.objects:
    n = obj.name.lower()
    if "ps" in n or "pad" in n or "control" in n or "game" in n or "console" in n:
        print(f"obj {obj.name} type={obj.type}")
        if obj.type == "MESH" and obj.data:
            for i, slot in enumerate(obj.material_slots):
                mat = slot.material
                print(f"  slot {i} mat={mat.name if mat else None}")
                if mat and mat.use_nodes:
                    for node in mat.node_tree.nodes:
                        if node.type == "TEX_IMAGE":
                            img = node.image
                            print(f"    tex {node.name} image={img.name if img else None}")

print("=== ALL MESH MATERIALS WITH IMAGE TEX ===")
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    imgs = []
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            imgs.append(node.image.name)
    if imgs:
        users = [o.name for o in bpy.data.objects if any(s.material == mat for s in o.material_slots)]
        print(f"mat {mat.name} images={imgs} users={users}")
