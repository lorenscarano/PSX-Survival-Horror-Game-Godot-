class_name ItemData extends Resource
enum Type { AMMO, HEAL, KEY, WEAPON }

@export var nombre := "Iteam"
@export var item_type := Type.AMMO
## Cantidad de balas/vida que da
@export var amount := 15
## La municion debe coincidir con el Ammo Type del arma
@export var ammo_type := "9mm"
## Llave
@export var key_id := "llave_roja"
##Armas
@export var weapon: WeaponData
##Unidades por espacio
@export var max_stack = 1
@export_range(1,2) var slot_size :=1
@export_multiline var description := ""
@export var icon: Texture2D
@export var world_model: PackedScene
@export var world_offset := Vector3(0,0.3,0)
@export var world_scale := 1.0
