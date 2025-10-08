# res://scripts/splash_layer.gd
extends CanvasLayer

@onready var logo: TextureRect = $SplashOverlay/Logo

func _ready():
	# Overlay should not block input
	$SplashOverlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make the logo crisp (per-node filter)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	logo.modulate.a = 4.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "modulate:a", 0.0, 2.0)
	tween.finished.connect(func ():
		queue_free()
	)
