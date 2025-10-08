extends Node

signal sensitivity_changed(value: float)

var mouse_sens: float = 0.015:
	set = set_mouse_sens

func set_mouse_sens(v: float) -> void:
	mouse_sens = clampf(v, 0.001, 5.0)
	emit_signal("sensitivity_changed", mouse_sens)
