extends SceneTree
func _init() -> void:
	var file = FileAccess.open("res://assets/GODOT_LICENSES.txt",FileAccess.WRITE)
	file.store_string("GODOT ENGINE\n============\n\n"+Engine.get_license_text()+"\n\n")
	file.store_string("THIRD-PARTY COMPONENT ATTRIBUTIONS\n==================================\n\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n")
	file.store_string("THIRD-PARTY LICENSE TEXTS\n========================\n\n")
	var licenses = Engine.get_license_info()
	for key in licenses:
		file.store_string(str(key)+"\n"+str(licenses[key])+"\n\n")
	file.close()
	quit()
