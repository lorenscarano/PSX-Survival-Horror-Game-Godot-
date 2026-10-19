class_name Player extends CharacterBody3D

@export_group("Movement Settings")
@export var turn_speed := 180.0
## Aca poner el tiempo que tarda (en segundos) para girar rapido.
@export var quick_turn_speed := 0.25
@export var walk_speed := 120.0
@export var run_speed := 280.0

@export_group("Health")
@export var max_health := 100

var health := 0 
var is_dead := false

var keys: Array[ItemData] = []

@export_group ("Weapon Settings")
@export var weapons: Array[WeaponData] = []
@export var shoot_height := -0.3


var current_weapon: WeaponData
var current_index := 0
var mag_ammo := {} #Balas en cada cargador, segun el nombre del arma
var reserve_ammo := {"9mm": 0, "escopeta": 0} #balas de cada tipo

const  GRAVITY = -9.81
const DEATH_ANIM := "Dying/mixamo_com"

enum State { IDLE, MOVING, TURNING }
var state := State.IDLE
var is_quick_turning := false
var is_aiming := false
var is_reloading := false
var fire_cooldown := 0.0

@onready var anim: AnimationPlayer = $PSXModels/AnimationPlayer
@onready var model: Node3D = $PSXModels
@onready var gun_model: Node3D = $PSXModels/Skeleton3D/BoneAttachment3D/PSX_Colt1911/SM_Colt1911
var model_base_pos := Vector3.ZERO

func _ready():
	gun_model.visible = false
	model_base_pos = model.position
	health = max_health
	add_to_group("player")
	
	anim.playback_default_blend_time = 0.2
	for w in weapons:
		mag_ammo[w.nombre] = w.mag_size
		anim.get_animation(w.aim_animation).loop_mode = Animation.LOOP_LINEAR
	if weapons.size() > 0:
		equip_weapon(0)
	for nombre in ["Idle/mixamo_com", "Walking/mixamo_com", "Running/mixamo_com", "Walking Backwards/mixamo_com"]:
		anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR

func equip_weapon(index: int) -> bool:
	if is_aiming or is_reloading or is_quick_turning:
		return false
	if index < 0 or index >= weapons.size():
		return false
	current_index = index
	current_weapon = weapons[index]
	return true

func play_recoil():
	var t:= create_tween()
	t.tween_property(model, "position:z", model_base_pos.z - 0.08, 0.04)
	t.tween_property(model, "position:z", model_base_pos.z, 0.12)

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
		anim.play(current_weapon.aim_animation)
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
	if mag_ammo[current_weapon.nombre] <=0:
		print("No hay mas balas en el cargador")
		return
	mag_ammo[current_weapon.nombre] -= 1
	fire_cooldown = current_weapon.fire_rate
	play_recoil()
	for i in current_weapon.pellets:
		fire_ray()
		print("Balas: ", mag_ammo[current_weapon.nombre], "/", reserve_ammo.get(current_weapon.ammo_type, 0))

func fire_ray():
	var dir = global_transform.basis.z
	if current_weapon.spread_degrees > 0.0:
		var s = deg_to_rad(current_weapon.spread_degrees)
		dir = dir.rotated(Vector3.UP, randf_range(-s,s))
		dir = dir.rotated(global_transform.basis.x, randf_range(-s,s)).normalized()
	var from = global_position + Vector3(0,shoot_height,0)
	var to = from + dir * current_weapon.max_range
	var query = PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [self]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(current_weapon.damage)
	if result:
		var marca := MeshInstance3D.new()
		marca.mesh = SphereMesh.new()
		marca.scale = Vector3.ONE * 0.2
		get_tree().current_scene.add_child(marca)
		marca.global_position = result.position
		get_tree().create_timer(2.0).timeout.connect(marca.queue_free)

func handle_reload():
	if current_weapon == null or is_reloading or is_quick_turning or is_aiming:
		return
	if not Input.is_action_just_pressed("reload"):
		return
	var w = current_weapon
	var reserve = reserve_ammo.get(w.ammo_type, 0)
	if mag_ammo[w.nombre] >= w.mag_size or reserve <=0 :
		return
	
	is_reloading =true
	await get_tree().create_timer(w.reload_time).timeout
	var taken = min(w.mag_size - mag_ammo[w.nombre], reserve)
	mag_ammo[w.nombre] += taken
	reserve_ammo[w.ammo_type] = reserve - taken
	is_reloading = false
	print("Arma recargada. Balas: ", mag_ammo[w.nombre], "/", reserve_ammo[w.ammo_type])
	
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
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
	gun_model.visible = is_aiming
	handle_gravity(delta)
	move_and_slide()
	

func _unhandled_input(_event: InputEvent) -> void:
	if is_dead:
		return
	if Input.is_action_just_pressed("quick_turn") and not is_quick_turning:
		is_quick_turning = true
		var target_y_rotation = rotation.y + PI
		
		var tween := create_tween() as Tween
		tween.tween_property(self, "rotation:y", target_y_rotation, quick_turn_speed)
		
		tween.finished.connect(func(): is_quick_turning = false)


## Funciones de daño y muerte

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
		
func die() -> void:
	is_dead = true
	is_aiming = false
	velocity = Vector3.ZERO
	anim.play(DEATH_ANIM)
	await anim.animation_finished
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func apply_item(item: ItemData) -> bool:
	if is_dead or is_aiming or is_reloading or is_quick_turning:
		return false
	match item.item_type:
		ItemData.Type.AMMO:
			reserve_ammo[item.ammo_type] = reserve_ammo.get(item.ammo_type,0 ) + item.amount
			return true
		ItemData.Type.HEAL:
			if health >= max_health:
				return false 
			health = min(health + item.amount, max_health)
			return true
		ItemData.Type.KEY:
			if not has_key(item.key_id):
				keys.append(item)
			return true
	return false

func has_key(id: String) -> bool:
	for k in keys:
		if k.key_id == id:
			return true
	return false
