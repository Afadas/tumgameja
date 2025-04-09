extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const HAND_MOVE_SPEED = 50.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var hand_touching_ground = false
var palm_closed = false

func get_movement_input() -> Vector3:
	var input_dir = Vector3.ZERO
	
	# Keyboard input
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1

# Hand tracking input
	var hands = get_node_or_null("/root/World/HandTracking")
	if hands:
		var left_hand = hands.left_hand
		var right_hand = hands.right_hand
		
		if left_hand and right_hand:
			var left_palm = left_hand.hand_landmarks[0]
			var right_palm = right_hand.hand_landmarks[0]
			
			# Calculate hand position relative to neutral position
			var hand_pos = (left_palm.global_position + right_palm.global_position) / 2.0
			var neutral_pos = Vector3(0, hand_pos.y, 0)
			var movement = (hand_pos - neutral_pos).normalized()
			
			input_dir += movement * HAND_MOVE_SPEED

	return input_dir.normalized()

func _on_hand_landmark_body_entered(body: Node3D) -> void:
	if body is CSGBox3D:
		hand_touching_ground = true

func _on_hand_landmark_body_exited(body: Node3D) -> void:
	if body is CSGBox3D:
		hand_touching_ground = false

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get movement direction
	var direction = get_movement_input()

	# Apply movement
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
