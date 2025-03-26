extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const HAND_MOVE_SPEED = 50.0  # Speed for hand-based movement

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func check_hand_movement() -> Vector3:
	var direction = Vector3.ZERO
	# Get hands node - adjust path if needed
	var hands = get_node_or_null("/root/Main/Hands")
	if hands:
		var left_hand = hands.get_node_or_null("LeftHand")
		var right_hand = hands.get_node_or_null("RightHand")
		
		if left_hand and right_hand:
			# Check if hands are at bottom (y near 0)
			var left_pos = left_hand.global_position
			var right_pos = right_hand.global_position
			
			if left_pos.y < 0.1 and right_pos.y < 0.1:
				# Check if fingers are close together (pinched)
				var hand_width = (left_pos - right_pos).length()
				if hand_width < 1.0:  # Adjust threshold as needed
					# Move forward in player's current direction
					direction = -global_transform.basis.z * HAND_MOVE_SPEED
	
	return direction

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Add hand-based movement
	var hand_movement = check_hand_movement()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# Apply hand movement if detected
	if hand_movement != Vector3.ZERO:
		velocity += hand_movement * delta
	
	move_and_slide()
