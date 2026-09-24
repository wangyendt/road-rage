extends SceneTree
func _init() -> void:
	var text = "GODOT ENGINE\n============\n\n"+Engine.get_license_text()+"\n\n"
	text += "THIRD-PARTY COMPONENT ATTRIBUTIONS\n==================================\n\n"
	text += JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"
	text += "THIRD-PARTY LICENSE TEXTS\n========================\n\n"
	var licenses = Engine.get_license_info()
	for key in licenses:
		text += str(key)+"\n"+str(licenses[key])+"\n\n"
	var file = FileAccess.open("res://assets/GODOT_LICENSES.txt",FileAccess.WRITE)
	file.store_string(text.strip_edges()+"\n")
	file.close()
	quit()
