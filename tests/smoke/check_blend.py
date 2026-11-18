# SPDX-License-Identifier: GPL-3.0-or-later
# Step 2 of the smoke test: runs on the .blend written by make_blend.py.
import sys
import os
import platform

import bpy

out_dir = sys.argv[sys.argv.index("--") + 1]
failures = []

def check(cond, what):
    print(("PASS " if cond else "FAIL ") + what)
    if not cond:
        failures.append(what)

print("Python", sys.version.replace("\n", " "))
print("platform", platform.platform(), "machine", platform.machine())
print("Blender", bpy.app.version_string, "build", bpy.app.build_platform.decode())
check(sys.platform == "android", "sys.platform == 'android' (got %r)" % sys.platform)

# Stdlib extension modules that are compiled into the static libpython.
for mod in ("math", "_ssl", "hashlib", "sqlite3", "ctypes", "lzma", "bz2", "zlib",
            "json", "_decimal", "select", "socket", "struct", "array", "_datetime",
            "unicodedata", "pyexpat"):
    try:
        __import__(mod)
        check(True, "import " + mod)
    except Exception as ex:  # noqa
        check(False, "import %s: %s" % (mod, ex))

# Data loaded from the file.
obj = bpy.data.objects.get("AndroidSuzanne")
check(obj is not None, "object from .blend is present")
if obj is not None:
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(deps).to_mesh()
    # Suzanne has 500 faces; one subdivision level -> 4x quads.
    check(len(mesh.polygons) > 1000, "subdivision evaluated (%d faces)" % len(mesh.polygons))

# Geometry-nodes style evaluation through the Python API.
bpy.ops.mesh.primitive_cube_add()
cube = bpy.context.active_object
bmod = cube.modifiers.new("Bool", 'BOOLEAN')
bmod.object = obj
for solver in ("EXACT", "MANIFOLD"):          # GMP and Manifold back-ends
    try:
        bmod.solver = solver
        deps = bpy.context.evaluated_depsgraph_get()
        n = len(cube.evaluated_get(deps).to_mesh().polygons)
        check(n > 0, "boolean solver %s (%d faces)" % (solver, n))
    except Exception as ex:  # noqa
        check(False, "boolean solver %s: %s" % (solver, ex))
cube.hide_render = True

# Cycles CPU render.
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 4
scene.render.resolution_x = 64
scene.render.resolution_y = 48
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = os.path.join(out_dir, "render.png")
bpy.ops.render.render(write_still=True)
check(os.path.getsize(scene.render.filepath) > 100, "Cycles render written")

# Colour management (OpenColorIO config from the datafiles).
check(len(scene.view_settings.bl_rna.properties["view_transform"].enum_items) > 1,
      "OpenColorIO view transforms available")

if failures:
    print("SMOKE_FAILED", len(failures))
    sys.exit(1)
print("SMOKE_OK")
