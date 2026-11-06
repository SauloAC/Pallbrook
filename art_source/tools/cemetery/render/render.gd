extends Node
# Renders KayKit pieces as the town's camera sees them (50 degrees down, orthographic), one pixel per
# 0.04375 m, toon-shaded, on a transparent background. Args via env: MODELS="name:scale:yaw,...", OUT dir
const PX := 0.04375
const SIN50 := 0.76604444
const COS50 := 0.64278761
var shader := preload("res://toon.gdshader")
func _ready():
	var spec := OS.get_environment("MODELS").split(",")
	var out := OS.get_environment("OUT")
	for item in spec:
		# out=model:sx:sy:sz:yaw
		var halves := item.split("=")
		var name := halves[0]
		var parts := halves[1].split(":")
		var scene := (load("res://m/%s.gltf" % parts[0]) as PackedScene).instantiate() as Node3D
		scene.scale = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
		scene.rotation_degrees.y = float(parts[4])
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		vp.add_child(scene)
		var box := AABB()
		var first := true
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				var src := m.get_active_material(s) as BaseMaterial3D
				var sm := ShaderMaterial.new(); sm.shader = shader
				if src and src.albedo_texture: sm.set_shader_parameter("tex", src.albedo_texture)
				m.set_surface_override_material(s, sm)
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		# screen extents: x across, rows from y*cos + z*sin
		var corners := []
		for i in 8: corners.append(box.get_endpoint(i))
		var rmin := INF; var rmax := -INF
		for c in corners:
			var r: float = c.y * COS50 - c.z * SIN50
			rmin = minf(rmin, r); rmax = maxf(rmax, r)
		var wpx := int(ceil(box.size.x / PX)) + 6
		var hpx := int(ceil((rmax - rmin) / PX)) + 6
		vp.size = Vector2i(wpx, hpx)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = hpx * PX
		cam.near = 0.05; cam.far = 100.0
		var center := box.get_center()
		var rc := (rmin + rmax) / 2.0
		# a point on the screen centre line: the ground point whose row is rc at height center.y
		var dir := Vector3(0, -SIN50, -COS50)
		var target := Vector3(center.x, center.y, -(rc - center.y * COS50) / SIN50)
		cam.transform = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-50.0)), target - dir * 30.0)
		vp.add_child(cam)
		cam.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/" + name + ".png")
		print("R ", name, " size ", box.size.snapped(Vector3.ONE * 0.01), " px ", wpx, "x", hpx)
		vp.queue_free()
	get_tree().quit()
