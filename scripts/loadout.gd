extends RefCounted
const Weapons=preload("res://scripts/weapons.gd")
var items: Array[String] = ["fists","kick"]
var current = "fists"
func _init(initial: String = "") -> void:
	if Weapons.armed(initial): acquire(initial)
func cycle() -> String:
	current=items[(items.find(current)+1)%items.size()]
	return current
func acquire(id: String) -> bool:
	if not Weapons.armed(id): return false
	var added=id not in items
	if added: items.append(id)
	current=id
	return added
func release_current() -> String:
	if not Weapons.armed(current): return ""
	var id=current
	items.erase(id)
	current="fists"
	return id
func take_from(other) -> String:
	if other==self: return ""
	var id=other.release_current()
	if not id.is_empty(): acquire(id)
	return id
