extends CanvasLayer

const SLOT_SIZE := Vector2(156, 88)
const COLOR_AMMO := Color(0.35, 0.75, 1.0)
const COLOR_WEAPON := Color(0.4,1.0,0.4)

var player: Player
var slot_buttons: Array[Button] = []
var is_open := false 
var last_slot := 0

@onready var grid := find_child("Grilla", true, false) as GridContainer
@onready var status_label := find_child("Estado", true, false) as Label
@onready var equip_icon := find_child("IconoEquipo", true, false) as TextureRect
@onready var equip_label := find_child("CargaEquipo", true, false) as Label
@onready var description_label := find_child("Descripcion", true, false) as Label
@onready var exit_button := find_child("BtnSalida", true, false) as Button

func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false
		for i in Inventory.SLOT_COUNT:
			var b := Button.new()
			b.custom_minimum_size = SLOT_SIZE
			b.clip_text = true
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.focus_entered.connect(_on_slot_focused.bind(i))
			b.pressed.connect(_on_slot_pressed.bind(i))
			var count := Label.new()
			count.name = "Cantidad"
			count.position = Vector2(4, SLOT_SIZE.y -18)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(count)
			grid.add_child(b)
			slot_buttons.append(b)
		exit_button.pressed.connect(close)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if not player.inventory.changed.is_connected(refresh):
		player.inventory.changed.connect(refresh)
	var inv := player.inventory
	for i in Inventory.SLOT_COUNT:
		var b := slot_buttons[i]
		var count_label := b.get_node("Cantidad") as Label
		var it := inv.items[i]
		b.modulate = Color.WHITE
		if it == null:
			b.icon = null
			b.text = ""
			count_label.text = ""
			continue
		b.icon = it.icon
		b.text = "" if it.icon != null else it.nombre
		match it.item_type:
			ItemData.Type.WEAPON:
				if it.weapon != null:
					count_label.text = str(player.mag_ammo.get(it.weapon.nombre,0))
				count_label.modulate = COLOR_WEAPON
			ItemData.Type.AMMO:
				count_label.text = str(inv.quantities[i])
				count_label.modulate = COLOR_AMMO
			_:
				count_label.text = ""
		if i == player.equipped_slot:
			b.modulate = Color(1.0,1.0,0.6)
	equip_icon.texture = null
	equip_label.text = "-"
	if player.equipped_slot >= 0:
		var eq := inv.items[player.equipped_slot]
		if eq != null and eq.weapon != null:
			equip_icon.texture = eq.icon
			equip_label.text = "%s\n%d" % [eq.nombre, player.mag_ammo.get(eq.weapon.nombre, 0)]
	
	var ratio := float(player.health) / float(player.max_health)
	if ratio > 0.6:
		status_label.text = "Bien"
		status_label.modulate = Color.LIME_GREEN
	elif ratio > 0.3:
		status_label.text = "Alerta"
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = "Peligro"
		status_label.modulate = Color.RED

func _on_slot_focused(i: int) -> void:
	last_slot = i
	var it := player.inventory.items[i]
	if it == null:
		description_label.text = ""
	elif it.description == "":
		description_label.text = it.nombre
	else:
		description_label.text = "%s\n%s" % [it.nombre, it.description]

func _on_slot_pressed(i: int) -> void:
	player.use_slot(i)
	refresh()
	_on_slot_focused(i)

func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func open() -> void:
	if get_tree().paused:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead:
		return
	if player.is_aiming or player.is_reloading or player.is_quick_turning:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	refresh()
	slot_buttons[last_slot].grab_focus()
