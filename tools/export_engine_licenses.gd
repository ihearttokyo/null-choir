extends SceneTree

func _initialize() -> void:
	var text = Engine.get_license_text()+"\n\nTHIRD-PARTY COPYRIGHTS\n"
	for item in Engine.get_copyright_info():
		text += "\n"+item.name+"\n"
		for part in item.parts:
			for notice in part.copyright: text += notice+"\n"
			text += "License: "+part.license+"\n"
	text += "\nTHIRD-PARTY LICENSE TEXTS\n"
	var licenses = Engine.get_license_info()
	for name in licenses: text += "\n"+name+"\n"+licenses[name]+"\n"
	DirAccess.make_dir_recursive_absolute("res://licenses")
	var file = FileAccess.open("res://licenses/Godot-Third-Party.txt",FileAccess.WRITE)
	if file == null:
		push_error("Cannot write runtime license notices")
		quit(1)
		return
	file.store_string(text.rstrip("\n")+"\n")
	file.close()
	print("PASS generated notices from installed Godot "+Engine.get_version_info().string)
	quit()
