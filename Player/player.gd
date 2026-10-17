class_name Player extends CharacterBody3D

@export_group("Movement Settings")
@export var turn_speed := 180.0
## Aca ponemos el tiempo que tarda en segundos para girar rapido.
@export var quick_turn_speed := 0.25
@export var walk_speed := 120.0
@export var run_speed := 280.0

@export_group ("Weapon Settings")
@export var damage := 10
@export var fire_rate := 0.4 #Aca se puede ajustar la velocidad de disparo
@export var reload_time := 1.5
@export var mag_size := 15 #Capacidad del cargador


const  GRAVITY = -9.81

enum State { IDLE, MOVING, TURNING }
var state := State.IDLE
var is_quick_turning := false
var is_aiming := false
var is_reloading := false
var fire_cooldown := 0.0
var ammo_in_mag := 15
var reserve_ammo := 30 #Municion fuera del cargador

@onready var anim: AnimationPlayer = $PSXModels/AnimationPlayer
@onready var shoot_ray: RayCast3D = $ShootRay


func _ready():
	ammo_in_mag = mag_size
	anim.playback_default_blend_time = 0.2
	for nombre in ["Idle/mixamo_com", "Walking/mixamo_com", "Running/mixamo_com", "Walking Backwards/mixamo_com", "Pistol Aim/mixamo_com"]:
		anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR

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

func update_animation():
	if is_aiming:
		anim.play("Pistol Aim/mixamo_com")
		
	elif state == State.MOVING and not is_quick_turning:
		if Input.is_action_pressed("move_backward"):
			anim.play("Walking Backwards/mixamo_com")
		elif Input.is_action_pressed("run"):
			anim.play("Running/mixamo_com")
		else:
			anim.play("Walking/mixamo_com")
	else:
		anim.play("Idle/mixamo_com")

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

func handle_shoot():
	if not is_aiming or is_reloading or fire_cooldown > 0.0:
		return
	if not Input.is_action_just_pressed("shoot"):
		return
	if ammo_in_mag <= 0:
		print("No hay mas balas en el cargador")
		return
	ammo_in_mag -= 1
	fire_cooldown = fire_rate
	
	shoot_ray.force_raycast_update()
	if shoot_ray.is_colliding():
		var target = shoot_ray.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(damage)
	print("Balas: ", ammo_in_mag, "/", reserve_ammo)
			
func handle_reload():
		if is_reloading or is_aiming or is_quick_turning:
			return
		if not Input.is_action_just_pressed("reload"):
			return
		if ammo_in_mag >= mag_size or reserve_ammo <= 0:
			return
			
		is_reloading = true
		await  get_tree().create_timer(reload_time).timeout
		var needed = mag_size - ammo_in_mag
		var taken = min(needed,reserve_ammo)
		ammo_in_mag += taken
		reserve_ammo -= taken
		is_reloading = false
		print("Arma Recargada. Balas: ", ammo_in_mag, "/", reserve_ammo)
	
func _physics_process(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	fire_cooldown = max(fire_cooldown - delta, 0.0)
	is_aiming = Input.is_action_pressed("aim") and not is_reloading and not is_quick_turning
	
	
	if not is_quick_turning and not is_reloading:
		if is_aiming:
			state = State.IDLE
			handle_turn(delta)
		
		else:
			update_state()
			match state:
				State.TURNING:
					handle_turn(delta)
				State.MOVING:
					if Input.is_action_pressed("run"):
						handle_run(delta)
					else:
						handle_walk(delta)

	handle_shoot()
	handle_reload()
	update_animation()
	handle_gravity(delta)
	move_and_slide()
	

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("quick_turn") and not is_quick_turning:
		is_quick_turning = true
		var target_y_rotation = rotation.y + PI
		
		var tween := create_tween() as Tween
		tween.tween_property(self, "rotation:y", target_y_rotation, quick_turn_speed)
		
		tween.finished.connect(func(): is_quick_turning = false)
