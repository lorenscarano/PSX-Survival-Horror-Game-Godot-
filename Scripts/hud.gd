extends CanvasLayer

@onready var ammo_label: Label = $AmmoContainer/AmmoLabel

var player: Player

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null :
			return
	#Ajustamos Municion
	var w = player.current_weapon
	
	if w == null:
		ammo_label.text = ""
	else:
		var mag = player.mag_ammo.get(w.nombre,0)
		ammo_label.text = str(mag)
