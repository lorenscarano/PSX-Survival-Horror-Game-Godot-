extends Control

@onready var play: Button = $Play
@onready var controles_panel: Panel = $"../ControlesPanel"

func _ready() -> void:
	controles_panel.hide()
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/demo.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_controles_pressed() -> void:
	hide()
	controles_panel.show()


func _on_volver_pressed() -> void:
	controles_panel.hide()
	show()
