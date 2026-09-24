extends SceneTree
func _init() -> void:
	var image = Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icon.svg"),4.0)
	for size in [16,32,128,256,512]:
		for density in [1,2]:
			var out = image.duplicate()
			out.resize(size*density,size*density,Image.INTERPOLATE_LANCZOS)
			out.save_png("res://builds/GameIcon.iconset/icon_%dx%d%s.png"%[size,size,"@2x" if density==2 else ""])
	quit()
