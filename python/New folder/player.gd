extends CharacterBody3D

const MOVE_SPEED = 5.0      # Base movement speed
const TURN_SPEED = 2.5      # Rotation speed modifier
const FRICTION = 3.0        # Friction when not moving
const GRAVITY = 9.8
const MAX_SPEED = 8.0       # Maximum movement speed
const PULL_THRESHOLD = 0.1  # Minimum pull to register movement

var socket = PacketPeerUDP.new()
var server_port = 10000
var debug_label
var direction_indicator

# Hand state tracking
var hand_position = Vector3.ZERO
var previous_hand_position = Vector3.ZERO
var hand_gesture = "open"    # Can be "open", "fist", or "drag"
var tilt_angle = 0.0         # Hand tilt angle for turning (±75 degrees)
var pull_distance = 0.0      # How far the hand has been pulled in drag mode

func _ready():
	# Start UDP server for receiving hand tracking data
	var err = socket.bind(server_port)
	if err != OK:
		print("Error binding to port: ", err)
	
	# Add a debug label to show connection status
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	var canvas = CanvasLayer.new()
	canvas.add_child(debug_label)
	add_child(canvas)
	
	# Create a direction indicator to show where the model is facing
	_create_direction_indicator()

func _create_direction_indicator():
	# Create a simple arrow to show facing direction
	direction_indicator = MeshInstance3D.new()
	direction_indicator.name = "DirectionIndicator"
	
	# Create an arrow-shaped mesh
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0  # Point at the top
	arrow_mesh.bottom_radius = 0.2
	arrow_mesh.height = 0.5
	
	# Create material for the arrow
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)  # Red arrow
	arrow_mesh.material = material
	
	direction_indicator.mesh = arrow_mesh
	
	# Position the arrow slightly above and in front of the player
	direction_indicator.transform.origin = Vector3(0, 0.5, -1.0)
	# Rotate the arrow to point forward (Z axis)
	direction_indicator.rotation_degrees = Vector3(-90, 0, 0)
	
	add_child(direction_indicator)

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Apply friction when not in drag mode
	if hand_gesture != "drag":
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
	
	# Update debug info
	debug_label.text = "UDP Port: " + str(server_port) + "\n"
	debug_label.text += "Packets available: " + str(socket.get_available_packet_count()) + "\n"
	debug_label.text += "Position: " + str(global_position) + "\n"
	debug_label.text += "Velocity: " + str(velocity) + "\n"
	debug_label.text += "Gesture: " + hand_gesture + "\n"
	debug_label.text += "Tilt Angle: " + str(tilt_angle) + "\n"
	debug_label.text += "Pull Distance: " + str(pull_distance) + "\n"
	debug_label.text += "Facing: " + str(rotation_degrees.y) + " degrees\n"
	
	# Process hand tracking data
	if socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		var text = packet.get_string_from_utf8()
		
		var json_result = JSON.parse_string(text)
		if json_result != null:
			# Store previous hand position and update current position
			previous_hand_position = hand_position
			hand_position = Vector3(json_result.x, json_result.y, json_result.z)
			
			# Update control values
			hand_gesture = json_result.get("gesture", "open")
			tilt_angle = json_result.get("tilt_angle", 0.0)
			pull_distance = json_result.get("pull_distance", 0.0)
			
			# Only handle movement in drag mode
			if hand_gesture == "drag":
				# Apply turn based on hand tilt
				var rotation_amount = deg_to_rad(tilt_angle) * TURN_SPEED * delta
				rotate_y(rotation_amount)  # Note: already flipped in app.py
				
				# Move forward based on pull distance
				if pull_distance > PULL_THRESHOLD:
					var movement_speed = MOVE_SPEED * pull_distance
					var forward_dir = -global_transform.basis.z  # Negative Z is forward
					
					# Apply movement in the forward direction
					velocity.x = forward_dir.x * movement_speed
					velocity.z = forward_dir.z * movement_speed
					
					# Cap maximum speed
					var horizontal_velocity = Vector2(velocity.x, velocity.z)
					if horizontal_velocity.length() > MAX_SPEED:
						horizontal_velocity = horizontal_velocity.normalized() * MAX_SPEED
						velocity.x = horizontal_velocity.x
						velocity.z = horizontal_velocity.y
					
					debug_label.text += "\nMoving forward: " + str(movement_speed)
	
	# Move and slide using built-in CharacterBody3D physics
	move_and_slide()

func _exit_tree():
	# Clean up socket when node is removed
	socket.close()
