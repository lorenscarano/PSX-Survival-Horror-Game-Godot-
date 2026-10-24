extends CanvasLayer

const SLOT_SIZE := Vector2(156, 88)
const COLOR_AMMO := Color(0.35, 0.75, 1.0)
const COLOR_WEAPON := Color(0.4,1.0,0.4)

var player: Player
var slot_buttons: Array[Button] = []
var slot_rows: Array[HBoxContainer] = []
var is_open := false 
var last_slot := 0
var combining := false
var combine_source_slot := -1
var combine_button: Button
var selected_slot := -1
var combine_original_parent: Node
var combine_original_index: int = -1

@onready var grid := find_child("Grilla", true, false) as GridContainer
@onready var status_label := find_child("Estado", true, false) as Label
@onready var equip_icon := find_child("IconoEquipo", true, false) as TextureRect
@onready var equip_label := find_child("CargaEquipo", true, false) as Label
@onready var description_label := find_child("Descripcion", true, false) as Label
@onready var exit_button := find_child("BtnSalida", true, false) as Button
@onready var ecg := find_child("Ecg", true, false) as EcgDisplay


func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false
		
		grid.columns = 1
		
		for row_index in 4:
			var row := HBoxContainer.new()
			row.custom_minimum_size.y = SLOT_SIZE.y
			row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			grid.add_child(row)
			slot_rows.append(row)
		
			for col_index in 2:
				var i := row_index * 2 + col_index
				
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
				
				row.add_child(b)
				slot_buttons.append(b)
				
		exit_button.pressed.connect(close)
		
		combine_button = Button.new()
		combine_button.add_theme_color_override("font_color", COLOR_AMMO)
		combine_button.name = "BtnCombinar"
		combine_button.text = "Combinar"
		combine_button.disabled = true
		combine_button.pressed.connect(_on_combine_pressed)
		
		grid.add_child(combine_button)
		combine_original_parent = combine_button.get_parent()
		combine_original_index = combine_button.get_index()
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
	for b in slot_buttons:
		b.visible = true
		b.custom_minimum_size = SLOT_SIZE
	for i in Inventory.SLOT_COUNT:
		var b := slot_buttons[i]
		var count_label := b.get_node("Cantidad") as Label
		var it := inv.items[i]
		b.modulate = Color.WHITE
		b.visible = true
		b.custom_minimum_size = SLOT_SIZE
		
		if it == null:
			b.icon = null
			b.text = ""
			count_label.text = ""
			if inv.reserved_by[i] != -1:
				b.visible = false
			
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
		## Arma equipada es amarillo
		if i == player.equipped_slot:
			b.modulate = Color(1.0,1.0,0.6)
		## Combinar es azul
		if combining and i == combine_source_slot:
			b.modulate = Color(0.4,0.8,1.0)

		
		if it.slot_size == 2:
			b.custom_minimum_size = Vector2(SLOT_SIZE.x * 2, SLOT_SIZE.y)
			if i + 1 < Inventory.SLOT_COUNT:
				slot_buttons[i + 1].visible = false
				
	equip_icon.texture = null
	equip_label.text = "-"
	if player.equipped_slot >= 0:
		var eq := inv.items[player.equipped_slot]
		if eq != null and eq.weapon != null:
			equip_icon.texture = eq.icon
			equip_label.text = "%s\n%d" % [eq.nombre, player.mag_ammo.get(eq.weapon.nombre, 0)]
	
	var ratio := float(player.health) / float(player.max_health)
	if ecg != null:
		ecg.set_health_ratio(ratio)
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
	if combining:
		_try_combine(i)
		refresh()
		if is_open and last_slot >= 0 and last_slot < slot_buttons.size():
			slot_buttons[last_slot].grab_focus()
		return
	
	last_slot = i
	selected_slot = i
	position_combine_button()
	player.use_slot(i)
	refresh()
	_on_slot_focused(i)	
	
	var it := player.inventory.items[i]
	combine_button.disabled = it == null or it.item_type != ItemData.Type.AMMO

func close() -> void:
	is_open = false
	_cancel_combine()
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
	if player.is_aiming or player.is_quick_turning:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	refresh()
	slot_buttons[last_slot].grab_focus()

func _on_combine_pressed() -> void:
	if combining:
		_cancel_combine()
		refresh()
		_on_slot_focused(last_slot)
		return
		
	if player == null:
		return
		
	if selected_slot < 0 or selected_slot >= Inventory.SLOT_COUNT:
		return
		
	var it := player.inventory.items[selected_slot]
	
	if it == null or it.item_type != ItemData.Type.AMMO:
		return
		
	combining = true
	combine_source_slot = selected_slot
	
	combine_button.text = "Cancelar"
	combine_button.disabled = false
	description_label.text = "Selecciona un arma compatible"
	
	refresh()

func _try_combine(target_slot: int) -> bool:
	if not combining or player == null:
		return false
		
	var inv := player.inventory
	
	if target_slot < 0 or target_slot >= Inventory.SLOT_COUNT:
		return false
		

	var ammo := inv.items[combine_source_slot]
	var target := inv.items[target_slot]
	
	if ammo == null or ammo.item_type != ItemData.Type.AMMO:
		_cancel_combine()
		return false
		
	if target == null or target.item_type != ItemData.Type.WEAPON:
		description_label.text = "Selecciona un arma compatible"
		return true
		
	if target.weapon == null or target.weapon.ammo_type != ammo.ammo_type:
		description_label.text = "Esta municion no es compatible"
		return true
		
	var weapon: WeaponData = target.weapon
	if not player.mag_ammo.has(weapon.nombre):
		player.register_weapon(weapon)
		
	var current: int = int(player.mag_ammo[weapon.nombre])
	var capacity: int = weapon.mag_size
	var available: int = inv.quantities[combine_source_slot]
	var space_left: int = maxi(capacity - current, 0)
	var transfer: int = mini(space_left, available)
	
	if transfer <= 0:
		description_label.text = "Cargador lleno"
		return true
		
	player.mag_ammo[weapon.nombre] = current + transfer
	inv.remove_from_slot(combine_source_slot, transfer)
	
	_cancel_combine()
	refresh()
	description_label.text = "Arma cargada"
	return true
	
func _cancel_combine() -> void:
	combining = false
	combine_source_slot = -1
	combine_button.text = "Combinar"
	restore_combineBtn()
	selected_slot = -1
	combine_button.disabled = true
	if is_open and last_slot >= 0 and last_slot < slot_buttons.size():
		slot_buttons[last_slot].grab_focus()


func position_combine_button() -> void:
	if combine_button == null:
		return
		
	# Si no hay municion dejarlo abajo
	if selected_slot < 0 or selected_slot >= Inventory.SLOT_COUNT:
		if combine_button.get_parent() != grid:
			combine_button.reparent(grid)
		return
		
	var item := player.inventory.items[selected_slot]
	 
	if item == null or item.item_type != ItemData.Type.AMMO:
		if combine_button.get_parent() != grid:
			combine_button.reparent(grid)
		return
		
	var row_index := int(selected_slot / 2)
	var row := slot_rows[row_index]
	
	## Movemos el cancelar al item
	if combine_button.get_parent() != row:
		combine_button.reparent(row)
		
	if selected_slot % 2 == 0:
		row.move_child(combine_button, row.get_child_count()-1)
		row.move_child(combine_button, selected_slot % 2)
	else:
		row.move_child(combine_button,row.get_child_count() -1 )		

func restore_combineBtn() -> void:
	if combine_original_parent == null:
		return
	if combine_button.get_parent() != combine_original_parent:
		combine_button.reparent(combine_original_parent)
	combine_original_parent.move_child(
		combine_button,
		combine_original_index
	)
