import bpy
for o in bpy.context.scene.objects:
    if o.type == 'MESH':
        from mathutils import Vector
        pts = [o.matrix_world @ Vector(v) for v in o.bound_box]
        print('HUB_OBJECT', o.name, 'min', tuple(round(min(p[i] for p in pts),2) for i in range(3)), 'max', tuple(round(max(p[i] for p in pts),2) for i in range(3)))
bpy.ops.export_scene.gltf(filepath=bpy.path.abspath('//../../assets/models/basement/hub_sketch.glb'), export_format='GLB')
