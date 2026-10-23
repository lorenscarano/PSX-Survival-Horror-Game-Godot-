class_name Pickup extends Area3D

@export var item: ItemData

var player_inside: Player = null

@onready var prompt: Label3D = $Label3D

func _ready() -> void:
	prompt.render_priority = 2
	prompt.outline_render_priority = 1
	prompt.no_depth_test = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false
	if item != null:
		prompt.text = "Recoger: %s" % item.nombre
	if item != null and item.world_model != null:
		var model := item.world_model.instantiate() as Node3D
		add_child(model)
		model.position = item.world_offset
		model.scale = item.world_scale * Vector3.ONE
		var placeholder := get_node_or_null("MeshInstance3D")
		if placeholder:
			placeholder.visible = false
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_inside = body
		prompt.visible = true
		
func _on_body_exited(body: Node3D) -> void:
	if body == player_inside:
		player_inside = null
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_inside == null or item == null:
		return
	if event.is_action_pressed("interact"):
		if player_inside.apply_item(item):
			queue_free()
		else:
			print("Ahora no")
