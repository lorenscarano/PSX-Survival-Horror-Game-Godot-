class_name Zombie extends CharacterBody3D

enum State {IDLE, CHASE, ATTACK, DEAD}

@export var max_health := 75
@export var move_speed := 1.4
@export var turn_speed := 5.0
@export var detection_range := 8.0
@export var attack_range := 1.3
@export var attack_damage := 15
@export var attack_cooldown := 1.2
@export var eye_height := -0.1
@export var lose_interest_time := 2.0

var lost_sight_timer := 0.0
var last_know_pos := Vector3.ZERO

const GRAVITY = -9.81

var state := State.IDLE
var health := 0
var attack_timer := 0.0
var player: Player

func can_see_player() -> bool:
	var offset = Vector3(0, eye_height,0)
	var from = global_position + offset
	var to = player.global_position + offset
	var query = PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [self]
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return result and result.collider == player

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player") as Player
	
func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0:
		die()
	elif  state == State.IDLE:
		state = State.CHASE

func die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	queue_free()
	
func face(dir: Vector3, delta: float) -> void:
	if dir == Vector3.ZERO:
		return
	var target_y = atan2(dir.x, dir.z) # el frente del modelo es el +z
	rotation.y = lerp_angle(rotation.y, target_y, turn_speed * delta)
	
func attack() -> void :
	attack_timer = attack_cooldown
	player.take_damage(attack_damage)
	
func _physics_process(delta: float) -> void:
	if state == State.DEAD or player == null or player.is_dead:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead:
		return
	attack_timer = max(attack_timer - delta, 0.0)
	
	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()
	var dir = to_player.normalized() if distance > 0.01 else Vector3.ZERO
	
	match state:
		State.IDLE:
			if distance <= detection_range and can_see_player():
				last_know_pos = player.global_position
				lost_sight_timer = 0.0
				state = State.CHASE
		State.CHASE:
			if distance <= attack_range:
				state = State.ATTACK
			elif can_see_player():
				last_know_pos = player.global_position
				lost_sight_timer = 0.0
			else:
				lost_sight_timer += delta
				if lost_sight_timer >= lose_interest_time:
					state = State.IDLE
		State.ATTACK:
			if distance > attack_range * 1.2:
				state = State.CHASE
				
	velocity.x = 0
	velocity.z = 0
	
	var move_dir = dir
	
	if state == State.CHASE and lost_sight_timer > 0.0:
		var to_last = last_know_pos - global_position
		to_last.y = 0
		move_dir = to_last.normalized() if to_last.length() > 0.4 else Vector3.ZERO
	
	if state == State.CHASE:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	if state == State.CHASE:
		face(dir, delta)
	elif state == State.ATTACK:
		face(move_dir,delta)
	if state == State.ATTACK and attack_timer <= 0.0 and can_see_player():
		attack()
		
	if is_on_floor():
		velocity.y = -2
	else:
		velocity.y += GRAVITY * delta
	move_and_slide()
