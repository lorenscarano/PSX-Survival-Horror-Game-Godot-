extends StaticBody3D

@export var health := 30

func take_damage(amount: int) -> void:
	health -= amount
	print("El target recibio: ", amount, "de danio. Vida: ", health)
	if health <= 0:
		queue_free()
