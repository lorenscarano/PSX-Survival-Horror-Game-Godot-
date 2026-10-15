class_name HealthComponent extends Node

signal health_changed(new_value: int)
signal died

@export var max_health := 100
@onready var current_health := max_health:
	set(value):
		if current_health != value:
			health_changed.emit(value)
			
		if value <= 0 :
			died.emit()
		
		current_health = value
