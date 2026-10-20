extends CanvasLayer

@onready var health_label: Label = $HealthLabel
@onready var ammo_label: Label = $AmmoLabel

var player: Player

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null :
			return
	# Ajustamos Vida
	if player.is_dead:
		health_label.text = "Muerto"
	else:
		health_label.text = "Vida: %d / %d" % [player.health, player.max_health]
	health_label.modulate = health_color()
	
	#Ajustamos Municion
	var w = player.current_weapon
	if w == null:
		ammo_label.text = ""
	else:
		var mag = player.mag_ammo.get(w.nombre,0)
		var reserve = player.inventory.count_ammo(w.ammo_type)
		ammo_label.text = "%s\n Balas: %d  / %d \n Reserva: %d" % [w.nombre, mag, w.mag_size, reserve]


func health_color() -> Color:
	var ratio := float(player.health) / float(player.max_health)
	if ratio > 0.6:
		return Color.WHITE #buen estado de salud
	elif 0.6 >= ratio and ratio > 0.3: 
		return Color.YELLOW #ojito
	else:
		return Color.DARK_RED #peligro
