class_name Player extends CharacterBody3D

@export_group("Movement Settings")
@export var turn_speed := 180.0
## Aca ponemos el tiempo que tarda en segundos para girar rapido.
@export var quick_turn_speed := 0.25
@export var walk_speed := 80.0
@export var run_speed := 280.0

const  GRAVITY = -9.81

enum State { IDLE, MOVING, TURNING }
var state := State.IDLE
var is_quick_turning := false

func update_state():
	var moving_input = Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward")
	var turning_input = Input.is_action_pressed("turn_right") or Input.is_action_pressed("turn_left")
	match state:
		State.IDLE:
			if moving_input:
				state = State.MOVING
			elif turning_input:
				state = State.TURNING
		State.MOVING:
			if not moving_input:
				state = State.IDLE
		State.TURNING:
			if not turning_input:
				state = State.IDLE

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
	velocity.x = 0
	velocity.z = 0
	
	if not is_quick_turning:
		update_state()
		match state:
			State.TURNING:
				handle_turn(delta)
			State.MOVING:
				if Input.is_action_pressed("run"):
					handle_run(delta)
				else:
					handle_walk(delta)

	handle_gravity(delta)
	move_and_slide()
	

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quick_turn") and not is_quick_turning:
		is_quick_turning = true
		var target_y_rotation = rotation.y + PI
		
		var tween := create_tween() as Tween
		tween.tween_property(self, "rotation:y", target_y_rotation, quick_turn_speed)
		
		tween.finished.connect(func(): is_quick_turning = false)
