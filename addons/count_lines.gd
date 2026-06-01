@tool
extends EditorScript

var include_addons_folder : bool = false
var ignore_dirs : Array[String] = [
	"csg_toolkit",
	"linear_stairs", 
	"simplegrasstextured", 
	"virtual_joystick",
	"simple_ide_layout"
]

var count_code : int = 0
var count_comments : int = 0
var count_total : int = 0
var count_gd_files : int = 0


func _run():
	count_dir("res://")
	OS.alert("%s lines of code\n%s comments\n%s total lines\n%s GD Files" % [count_code, count_comments, count_total, count_gd_files])


func count_dir(path: String):
	var directories = DirAccess.get_directories_at(path)
	for d in directories:
		if d == "addons" and not include_addons_folder:
			continue
		if d in ignore_dirs:
			continue
		
		if path == "res://":
			count_dir(path + d)
		else:
			count_dir(path + "/" + d)

	var files = DirAccess.get_files_at(path)

	for f in files:
		if not f.get_extension() == "gd":
			continue
		count_gd_files += 1
		
		var file := FileAccess.open(path + "/" + f, FileAccess.READ)
		var lines = file.get_as_text().split("\n")

		for line in lines:
			count_total += 1
			if line.strip_edges().begins_with("#"):
				count_comments += 1
				continue
			if line.strip_edges() != "":
				count_code += 1
