"""HELD: execute only after explicit native/Blender authorization. No .blend presently claimed.
Example later: blender --background --python source/blender_import_save.py -- /absolute/path/to/kit
Imports each editable glTF, packs the shared atlas, saves a separate recoverable master.
"""
import sys,pathlib
import bpy
root=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert (root/'raw/texture-atlas.png').is_file(),'Shared atlas required before master import'
out=root/'blender-masters';out.mkdir(exist_ok=True)
for asset in sorted((root/'models').glob('*.gltf')):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(asset))
 for obj in bpy.context.scene.objects:
  obj['source_family']=asset.stem
 bpy.ops.file.pack_all()
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(asset.stem+'.blend')))
