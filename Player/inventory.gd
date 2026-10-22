class_name Inventory extends RefCounted

signal changed

const SLOT_COUNT := 8

var items: Array[ItemData] = []
var quantities: Array[int] = []
var reserved_by: Array[int] = []

func _init() -> void:
	items.resize(SLOT_COUNT)
	quantities.resize(SLOT_COUNT)
	quantities.fill(0)
	
	reserved_by.resize(SLOT_COUNT)
	reserved_by.fill(-1)
	
func _same_stack(a: ItemData, b: ItemData) -> bool:
	if a == b:
		return true
	return a.item_type == ItemData.Type.AMMO and b.item_type == ItemData.Type.AMMO and a.ammo_type == b.ammo_type
	
func _room_for(item: ItemData) -> int:
	var stack_max := maxi(item.max_stack, 1)
	var room := 0
	
	if _item_size(item) == 1:
		for i in SLOT_COUNT:
			if items[i] != null and _same_stack(items[i], item):
				room += stack_max - quantities[i]
	
	for i in SLOT_COUNT:
		if _can_place_at(i,item):
			room += stack_max
	return room 

func _item_size(item: ItemData) -> int:
	return clampi(item.slot_size,1,SLOT_COUNT)
	
func _can_place_at(index: int, item: ItemData) -> bool:
	var size := _item_size(item)
	if size == 2 and index % 2 != 0:
		return false
	if index+ size > SLOT_COUNT:
		return false
	for j in range(index, index + size):
		if items[j] != null or reserved_by[j] != -1:
			return false
			
	return true

func add_item(item: ItemData, qty: int = 1) -> bool:
	if qty <= 0 or _room_for(item) < qty:
		return false
	var stack_max := maxi(item.max_stack,1)
	var left := qty
	if _item_size(item) == 1:
		for i in SLOT_COUNT:
			if left <= 0:
				break
				
			if items[i] != null and _same_stack(items[i], item):
				var n := mini(left, stack_max - quantities[i])
				quantities[i] += n
				left -= n
				
	for i in SLOT_COUNT:
		if left <= 0:
			break
		if not _can_place_at(i, item):
			continue
			
		var n := mini(left, stack_max)
		items[i] = item
		quantities[i] = n
		left -= n
		
		var size := _item_size(item)
		for j in range(i + 1, i+size):
			reserved_by[j] = i
	changed.emit()
	return true
	
func remove_from_slot(i: int, qty: int = 1) -> void:
	if i < 0 or i >= SLOT_COUNT:
		return
		
	if reserved_by[i] != -1:
		return
		
	if items[i] == null:
		return
		
	quantities[i] -= qty
	if quantities[i] <= 0:
		var size := _item_size(items[i])
		
		for j in range (i + 1, mini(i + size, SLOT_COUNT)):
			if reserved_by[j] == i:
				reserved_by[j] = -1
		
		items[i] = null
		quantities[i] = 0

	changed.emit()

func count_ammo(ammo_type: String) -> int:
	var total := 0
	for i in SLOT_COUNT:
		var it := items[i]
		if it != null and it.item_type == ItemData.Type.AMMO and it.ammo_type == ammo_type:
			total += quantities[i]
	return total

func take_ammo(ammo_type: String, wanted: int) -> int:
	var taken := 0
	for i in SLOT_COUNT:
		if taken >= wanted:
			break
		var it := items[i]
		if it != null and it.item_type == ItemData.Type.AMMO and it.ammo_type == ammo_type:
			var n := mini(wanted - taken, quantities[i])
			quantities[i] -=n
			taken +=n
			if quantities[i] <= 0:
				items[i] = null
				quantities[i] = 0
	if taken > 0:
		changed.emit()
	return taken
	
func has_key(id: String) -> bool:
	for it in items:
		if it != null and it.item_type == ItemData.Type.KEY and it.key_id == id:
			return true
	return false

func consume_key(id: String) -> void:
	for i in SLOT_COUNT:
		var it := items[i]
		if it != null and it.item_type == ItemData.Type.KEY and it.key_id == id:
			remove_from_slot(i)
			return

func debug_print() -> void:
	for i in SLOT_COUNT:
		if items[i] == null:
			print(i, ": (vacio)")
		else:
			print(i, ": ", items[i].nombre, " x", quantities[i])
