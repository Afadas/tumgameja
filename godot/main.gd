extends Node3D

func _ready():
	# Set up environment
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.6, 0.8)
	environment.environment = env
	add_child(environment)
	
	# Add lighting
	var directional_light = DirectionalLight3D.new()
	directional_light.rotation = Vector3(-0.8, 0.5, 0)
	directional_light.shadow_enabled = true
	add_child(directional_light)
	
	# Create floor
	_create_floor()
	
	# Create player
	_create_player()
	
	# Create obstacles for testing
	_create_obstacles()

func _create_floor():
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(20, 20)
	
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.3, 0.3)
	floor_mesh.material = floor_material
	
	var floor_node = StaticBody3D.new()
	floor_node.name = "Floor"
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = floor_mesh
	floor_node.add_child(mesh_instance)
	
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(20, 0.1, 20)
	collision_shape.shape = shape
	floor_node.add_child(collision_shape)
	
	add_child(floor_node)

func _create_player():
	var player = load("res://player.tscn").instantiate()
	player.transform.origin = Vector3(0, 1, 0)
	add_child(player)
	
	# Add camera - FIXED: Use look_at_from_position instead of adding camera first
	var camera = Camera3D.new()
	camera.transform.origin = Vector3(0, 5, 10)
	add_child(camera)
	# Call look_at after adding to the scene tree
	camera.look_at(Vector3(0, 1, 0))

func _create_obstacles():
	# Create some simple obstacle boxes
	for i in range(5):
		var box = StaticBody3D.new()
		
		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		mesh_instance.mesh = box_mesh
		box.add_child(mesh_instance)
		
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		collision_shape.shape = shape
		box.add_child(collision_shape)
		
		# Random position
		var pos = Vector3(randf_range(-8, 8), 0.5, randf_range(-8, 8))
		box.transform.origin = pos
		
		add_child(box)
