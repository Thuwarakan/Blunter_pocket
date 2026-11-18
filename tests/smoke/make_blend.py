# SPDX-License-Identifier: GPL-3.0-or-later
# Step 1 of the smoke test: build a small scene and save it as a .blend file.
import sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_monkey_add()
obj = bpy.context.active_object
obj.name = "AndroidSuzanne"
mod = obj.modifiers.new("Subsurf", 'SUBSURF')   # exercises OpenSubdiv
mod.levels = 1
bpy.ops.object.camera_add(location=(0.0, -4.0, 0.0), rotation=(1.5708, 0.0, 0.0))
bpy.context.scene.camera = bpy.context.active_object
bpy.ops.object.light_add(type='SUN')
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SMOKE_SAVED", out)
