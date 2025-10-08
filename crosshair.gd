extends Control

@export var line_len: int = 10    # length of each tick
@export var gap: int = 8          # gap from the center
@export var thickness: int = 4    # tick thickness (pixels)
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)  # white

func _ready() -> void:
	# Make sure we’re centered and the pivot is the center
	set_anchors_preset(Control.PRESET_CENTER)
	# If your size isn’t set in the Inspector, set it here:
	if size == Vector2.ZERO:
		size = Vector2(32, 32)
	pivot_offset = size / 2
	queue_redraw()

func _draw() -> void:
	var c = size / 2

	# Up
	draw_rect(
		Rect2(Vector2(c.x - thickness/2.0, c.y - gap - line_len),
			  Vector2(thickness, line_len)),
		color
	)
	# Down
	draw_rect(
		Rect2(Vector2(c.x - thickness/2.0, c.y + gap),
			  Vector2(thickness, line_len)),
		color
	)
	# Left
	draw_rect(
		Rect2(Vector2(c.x - gap - line_len, c.y - thickness/2.0),
			  Vector2(line_len, thickness)),
		color
	)
	# Right
	draw_rect(
		Rect2(Vector2(c.x + gap, c.y - thickness/2.0),
			  Vector2(line_len, thickness)),
		color
	)
