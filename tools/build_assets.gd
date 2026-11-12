extends SceneTree
## Turns build/usd/*.json (from usd2json.py) into ArrayMesh resources with automatic
## levels of detail, saved as assets/nature/<name>.res. Colours are baked into the
## vertices so every model shares the one low-poly shader.

func _init() -> void:
	var dir := DirAccess.open("res://build/usd")
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/usd/" + f))
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		var flip := Basis(Vector3.UP, PI)   # Quaternius models face -Z; ours face +Z
		for i in d.pos.size():
			pos.append(flip * Vector3(d.pos[i][0], d.pos[i][1], d.pos[i][2]))
			if i < d.nrm.size():
				nrm.append(flip * Vector3(d.nrm[i][0], d.nrm[i][1], d.nrm[i][2]))
			# USD colours are linear; the Compatibility renderer shows vertex colours as sRGB
			col.append(Color(d.col[i][0], d.col[i][1], d.col[i][2]).linear_to_srgb())
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# USD lists corners counter-clockwise; Godot wants clockwise front faces
		for t in range(0, pos.size(), 3):
			for k in [0, 2, 1]:
				st.set_color(col[t + k])
				if not nrm.is_empty():
					st.set_normal(nrm[t + k])
				st.add_vertex(pos[t + k])
		st.index()
		if nrm.is_empty():
			st.generate_normals()
		var im := ImporterMesh.new()
		var arrays := st.commit_to_arrays()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(25.0, 60.0, [])
		var mesh := im.get_mesh()
		var out := "res://assets/nature/%s.res" % f.get_basename()
		ResourceSaver.save(mesh, out, ResourceSaver.FLAG_COMPRESS)
		var lods := []
		for l in im.get_surface_lod_count(0):
			lods.append(im.get_surface_lod_indices(0, l).size() / 3)
		print("%-22s %5d tris  lods %s" % [f.get_basename(), pos.size() / 3, lods])
		n += 1
	print("built %d meshes" % n)
	quit()
