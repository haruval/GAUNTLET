# Target.gd
extends StaticBody3D

signal scored

@export var wall: Node3D
@export var wall_size := Vector2(10.0, 5.0)  # width (X) x height (Y) of the wall’s usable area
@export var margin := 0.5                    # keep away from edges
@export var pop_out := 0.1                   # how far in front of the wall surface
@onready var hit_sound: AudioStreamPlayer3D = $HitSound

func _ready() -> void:
	respawn()

func on_shot() -> void:
	if is_instance_valid(hit_sound):
		# restart the sound if it's mid-play, so it always clicks immediately
		hit_sound.stop()
		hit_sound.play()
		
	emit_signal("scored")
	respawn()

func respawn() -> void:
	if wall == null:
		push_warning("Target has no wall assigned.")
		return

	# Pick random local X/Y on the wall
	var half_w = wall_size.x * 0.5 - margin
	var half_h = wall_size.y * 0.5 - margin
	var rx = randf_range(-half_w, half_w)
	var ry = randf_range(-half_h, half_h)

	var wt: Transform3D = wall.global_transform
	var local_offset = wt.basis.x * rx + wt.basis.y * ry + wt.basis.z * pop_out
	var new_origin = wt.origin + local_offset

	# --- preserve local scale robustly ---
	var keep_local_scale := self.scale
	# Set rotation/position from wall
	self.global_transform = Transform3D(wt.basis.orthonormalized(), new_origin)
	# Reapply the local scale
	self.scale = keep_local_scale
