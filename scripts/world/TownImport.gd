@tool
extends EditorScenePostImport

# Runs whenever Godot imports town.glb.
# The kit's vertex-painted props (carrots, apples, books, bottles...) take their colors from
# the mesh's vertex colors, but the glTF import leaves "use vertex color" off, so they came
# out white. Turn it on for every material made for vertex colors.

func _post_import(scene: Node) -> Object:
	var fixed := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat and mat.resource_name.contains("Vertex") and not fixed.has(mat):
				mat.vertex_color_use_as_albedo = true
				fixed[mat] = true
	print("TownImport: vertex colors on for %d materials" % fixed.size())
	return scene
