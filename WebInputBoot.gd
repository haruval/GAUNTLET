# WebInputBoot.gd (Godot 4.x)
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working even when paused
	if !OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# First click/key → fullscreen (web) + capture
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if OS.has_feature("web"):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
