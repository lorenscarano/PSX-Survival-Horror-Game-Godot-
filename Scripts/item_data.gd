class_name ItemData extends Resource
enum Type { AMMO, HEAL, KEY }

@export var nombre := "Iteam"
@export var item_type := Type.AMMO
## Cantidad de balas/vida que da
@export var amount := 15
## La municion debe coincidir con el Ammo Type del arma
@export var ammo_type := "9mm"
@export var icon: Texture2D
## Llave
@export var key_id := "llave_roja"
