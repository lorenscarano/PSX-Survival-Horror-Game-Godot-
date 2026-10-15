class_name ReCamera extends Camera3D

@export var follow_player := false
var player: Player = null

func _on_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		player = body
		current = true
		
