extends NavigationRegion3D

# ============================================================
#  BLACK BREACHER — navmesh baker
#  CSG geometry won't bake via the normal scene parser (0 polys),
#  so we build the source geometry PROCEDURALLY: walk the level,
#  add a box for every collidable CSGBox3D / CSGCylinder3D, and
#  bake from that. Reliable + auto-adapts to the level layout.
# ============================================================

func _ready() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		root = owner if owner != null else get_parent()
	var source := NavigationMeshSourceGeometryData3D.new()
	_collect(root, source)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.5
	nm.cell_size = 0.3
	nm.cell_height = 0.3
	NavigationServer3D.bake_from_source_geometry_data(nm, source)
	navigation_mesh = nm
	print("NAV_POLYS ", nm.get_polygon_count())

func _collect(n: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	if n is CSGBox3D and n.use_collision:
		var bm := BoxMesh.new()
		bm.size = n.size
		source.add_mesh(bm, n.global_transform)
	elif n is CSGCylinder3D and n.use_collision:
		var bc := BoxMesh.new()
		bc.size = Vector3(n.radius * 2.0, n.height, n.radius * 2.0)
		source.add_mesh(bc, n.global_transform)
	for c in n.get_children():
		_collect(c, source)
