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


@export_group("Inventory")
@export var starting_items: Array[ItemData] = []

var inventory := Inventory.new()
var equipped_slot := -1

@export_group("Audio Settings")

@export var walking_step_sound: AudioStream
@export var running_step_sound: AudioStream

@export var walking_step_interval := 0.5
@export var running_step_interval := 0.28
@export var backward_step_multiplier := 1.2

var movement_step_timer := 0.0

@onready var shot_sound: AudioStreamPlayer3D = $ShotSound
@onready var movement_sound: AudioStreamPlayer3D = $MovementSound

@export_group ("Weapon Settings")
@export var shoot_height := -0.3

@export_group("Laser")
@export var laser_color := Color(1.0,0.1,0.1)
@export var laser_width := 0.04

var laser: MeshInstance3D
var laser_dot: MeshInstance3D

@onready var pistol_root: Node3D = get_node_or_null("PSXModels/Skeleton3D/BoneAttachment3D/PSX_Colt1911")
@onready var shotgun_root: Node3D = get_node_or_null("PSXModels/Skeleton3D/BoneAttachment3D/m1897")

@onready var pistol_muzzle: Marker3D = get_node_or_null("PSXModels/Skeleton3D/BoneAttachment3D/PSX_Colt1911/Muzzle")
@onready var shotgun_muzzle: Marker3D = get_node_or_null("PSXModels/Skeleton3D/BoneAttachment3D/m1897/Muzzle")

var current_weapon: WeaponData
var mag_ammo := {} #Balas en cada cargador, segun el nombre del arma

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
	create_laser()
	gun_model.visible = false
	model_base_pos = model.position
	health = max_health
	add_to_group("player")
	for it in starting_items:
		apply_item(it)
	for i in Inventory.SLOT_COUNT:
		var it := inventory.items[i]
		if it != null and it.item_type == ItemData.Type.WEAPON:
			equip_from_slot(i)
			break
	anim.playback_default_blend_time = 0.2
	for nombre in ["Idle/mixamo_com", "Walking/mixamo_com", "Running/mixamo_com", "Walking Backwards/mixamo_com"]:
		anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR

func register_weapon(w: WeaponData) -> void:
	if not mag_ammo.has(w.nombre):
		mag_ammo[w.nombre] = w.mag_size
	anim.get_animation(w.aim_animation).loop_mode = Animation.LOOP_LINEAR

func update_weapon_model() -> void:
	if pistol_root != null:
		pistol_root.visible = false
		
	if shotgun_root != null:
		shotgun_root.visible = false
	
	if  not is_aiming or current_weapon == null:
		return
	
	match current_weapon.nombre:
		"Pistola":
			if pistol_root != null:
				pistol_root.visible = true
			if gun_model != null:
				gun_model.visible = true
		"Escopeta":
			shotgun_root.visible = is_aiming
			

func equip_from_slot(slot: int) -> bool:
	if is_aiming or is_reloading or is_quick_turning:
		return false
		
	var it := inventory.items[slot]
	
	if it == null or it.item_type != ItemData.Type.WEAPON or it.weapon == null:
		return false
		
	current_weapon = it.weapon
	equipped_slot = slot
	
	register_weapon(current_weapon)
	update_weapon_model()
	return true

func get_shoot_origin() -> Vector3:
	if current_weapon != null:
		match current_weapon.nombre:
			"Pistola":
				if pistol_muzzle != null:
					return pistol_muzzle.global_position
			"Escopeta":
				if shotgun_muzzle != null:
					return shotgun_muzzle.global_position
	return global_position + Vector3(0, shoot_height, 0)
	
func create_laser() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = laser_color
	
	var box := BoxMesh.new()
	box.size = Vector3(laser_width, laser_width, 1.0)
	laser = MeshInstance3D.new()
	laser.mesh = box
	laser.material_override = mat
	laser.top_level = true
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser.visible = false
	add_child(laser)

	var sphere := SphereMesh.new()
	sphere.radius = laser_width * 1.5
	sphere.height = laser_width * 3.0
	laser_dot = MeshInstance3D.new()
	laser_dot.mesh = sphere
	laser_dot.material_override = mat
	laser_dot.top_level = true
	laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser_dot.visible = false
	add_child(laser_dot)
	
func update_laser() -> void:
	if current_weapon == null or not is_aiming:
		laser.visible = false
		laser_dot.visible = false
		return
	var from := get_shoot_origin()
	var to := from + global_transform.basis.z * current_weapon.max_range
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	var end := to
	if result:
		end = result.position
	var length := from.distance_to(end)
	if length < 0.05:
		laser.visible = false
		laser_dot.visible = false
		return
		
	laser.visible = true
	laser.global_position = from.lerp(end, 0.5)
	laser.look_at(end, Vector3.UP)
	laser.scale = Vector3(1.0,1.0,length)
	
	laser_dot.visible = result != null
	laser_dot.global_position = end

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
	if is_aiming and current_weapon != null:
		if current_weapon.aim_animation != "":
			anim.play(current_weapon.aim_animation)
		else:
			anim.play("Idle/mixamo_com")
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
	
	## Sonidos
	if current_weapon.shoot_sound != null:
		shot_sound.stream = current_weapon.shoot_sound
		shot_sound.pitch_scale = randf_range(0.95, 1.05)
		shot_sound.play()
	
	for i in current_weapon.pellets:
		fire_ray()

func fire_ray():
	var dir = global_transform.basis.z
	if current_weapon.spread_degrees > 0.0:
		var s = deg_to_rad(current_weapon.spread_degrees)
		dir = dir.rotated(Vector3.UP, randf_range(-s,s))
		dir = dir.rotated(global_transform.basis.x, randf_range(-s,s)).normalized()
	var from = get_shoot_origin()
	var to = from + dir * (current_weapon.max_range)
	var query = PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [self]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("take_damage"):
		result.collider.take_damage(current_weapon.damage)

func handle_reload():
	if current_weapon == null or is_reloading or is_quick_turning or is_aiming:
		return
		
	if not Input.is_action_just_pressed("reload"):
		return
		
	var w = current_weapon
	
	if not mag_ammo.has(w.nombre):
		register_weapon(w)
	
	var reserve = inventory.count_ammo(w.ammo_type)
	if mag_ammo[w.nombre] >= w.mag_size or reserve <=0 :
		return
	is_reloading =true
	await get_tree().create_timer(w.reload_time).timeout
	var taken = inventory.take_ammo(w.ammo_type,w.mag_size - mag_ammo[w.nombre])
	mag_ammo[w.nombre] += taken
	is_reloading = false

	
	
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
	update_weapon_model()
	update_laser()
	handle_gravity(delta)
	move_and_slide()
	update_movement_sound(delta)
	

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
	laser.visible = false
	laser_dot.visible = false
	is_aiming = false
	velocity = Vector3.ZERO
	anim.play(DEATH_ANIM)
	await anim.animation_finished
	await get_tree().create_timer(2.0).timeout
	get_tree().call_group("end_screen", "show_screen", "Moriste", Color.DARK_RED)

func apply_item(item: ItemData) -> bool:
	if is_dead or is_aiming or is_reloading or is_quick_turning:
		return false
	var qty := item.amount if item.item_type == ItemData.Type.AMMO else 1
	if not inventory.add_item(item,qty):
		return false
	if item.item_type == ItemData.Type.AMMO and item.weapon != null:
		register_weapon(item.weapon)
	return true

func has_key(id: String) -> bool:
	return inventory.has_key(id)

func use_slot(slot: int) -> void:
	var it := inventory.items[slot]
	if it == null:
		return
	match it.item_type:
		ItemData.Type.HEAL:
			if health < max_health:
				health = min(health + it.amount, max_health)
				inventory.remove_from_slot(slot)
		ItemData.Type.AMMO:
			equip_from_slot(slot)
		ItemData.Type.WEAPON:
			equip_from_slot(slot)

func update_movement_sound(delta: float) -> void:
	if is_dead:
		movement_step_timer = 0.0
		return
		
	if(
		not is_on_floor()
		or is_aiming
		or is_reloading
		or is_quick_turning
	):
		movement_step_timer = 0.0
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	
	if horizontal_speed <= 0.1:
		movement_step_timer = 0.0
		return
		
	movement_step_timer -= delta
	
	if movement_step_timer > 0.0:
		return
		
	var is_moving_backward := Input.is_action_pressed("move_backward")
	var is_running_forward := (
	Input.is_action_pressed("run")
	and Input.is_action_pressed("move_forward")
	and not is_moving_backward)
	
	var step_interval: float
	var selected_sound: AudioStream
	
	if is_running_forward:
		selected_sound = running_step_sound
		step_interval = running_step_interval
	else:
		selected_sound = walking_step_sound
		step_interval = walking_step_interval
		
		if is_moving_backward:
			step_interval *= backward_step_multiplier
	
	#Reiniciamos el tiempo (incluso sin audio)
	movement_step_timer = step_interval
	
	if selected_sound == null:
		return
		
	movement_sound.stream = selected_sound
	movement_sound.pitch_scale = randf_range(0.9,1.1)
	movement_sound.play()
