class_name AimTarget extends Area3D

@export var health_component: HealthComponent

func apply_damage(damage_amount: int):
	health_component.current_health -= damage_amount
