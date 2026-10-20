extends CanvasLayer

@onready var title_label: Label = $Centro/Caja/Titulo
@onready var retry_button: Button = $Centro/Caja/BtnReintentar
@onready var quit_button: Button = $Centro/Caja/BtnSalir

func _ready() -> void:
	add_to_group("end_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
func show_screen(title: String, color: Color = Color.WHITE) -> void:
	if visible:
		return
	title_label.text = title
	title_label.modulate = color
	visible = true
	get_tree().paused = true
	retry_button.grab_focus()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
func _on_quit_pressed() -> void:
	get_tree().quit()
