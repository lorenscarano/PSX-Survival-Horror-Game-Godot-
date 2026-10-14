class_name Player extends CharacterBody3D

@export_group("Movement Settings")
@export var turn_speed := 180.0
@export var walk_speed := 80.0
@export var run_speed := 280.0

const  GRAVITY = -9.81

func handle_turn(delta):
	var turn_dir = Input.get_axis("turn_left", "turn_right")
	rotation_degrees.y -= turn_dir * turn_speed * delta

func handle_walk(delta):
	var input_dir = Input.get_axis("move_forward", "move_backward")
	var walk_velocity = -basis.z * input_dir * walk_speed * delta
	velocity.x = walk_velocity.x
	velocity.z = walk_velocity.z

func handle_run(delta):
	if Input.is_action_pressed("move_backward"):
		handle_walk(delta)
		return
	var input_strength = Input.get_action_strength("move_forward")
	var walk_velocity = basis.z * input_strength * run_speed * delta
	velocity.x = walk_velocity.x
	velocity.z = walk_velocity.z

func handle_gravity(delta):
	if is_on_floor():
		velocity.y = -2
	else:
		velocity.y += GRAVITY * delta

func _physics_process(delta: float) -> void:
	handle_turn(delta)
	if Input.is_action_pressed("run"):
		handle_run(delta)
	else:
		handle_walk(delta)
	handle_gravity(delta)
	move_and_slide()
