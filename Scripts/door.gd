class_name Door extends Area3D

signal opened

@export var required_key := "llave_roja"
@export var locked_text := "Esta cerrada con llave"
@export var open_text := "Abrir"

var player_inside: Player = null
var is_open = false

@onready var prompt: Label3D = $Label3D
@onready var blocker: StaticBody3D = $Blocker

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false
	prompt.render_priority = 2
	prompt.outline_render_priority = 1
	prompt.no_depth_test = true

func refresh_prompt() -> void:
	if player_inside == null:
		return
	prompt.text = open_text if player_inside.has_key(required_key) else locked_text

func _on_body_entered(body: Node3D) -> void:
	if is_open:
		return
	if body is Player:
		player_inside = body
		refresh_prompt()
		prompt.visible = true
		
func _on_body_exited(body: Node3D) -> void:
	if body == player_inside:
		player_inside = null
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_open or player_inside == null or player_inside.is_dead:
		return
	if not event.is_action_pressed("interact"):
		return
	if player_inside.has_key(required_key):
		open()
	else:
		refresh_prompt()

func open() -> void:
	is_open = true
	prompt.visible = false
	blocker.queue_free()
	opened.emit()
