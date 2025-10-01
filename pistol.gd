extends Node3D

@onready var animation: AnimationPlayer = $Animation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if animation:
		animation.play("Idle")

func _input(event) -> void:
	if event is InputEventMouseButton:
		animation.play("Shoot", -1, 1.5)

func play_shoot() -> void:
	if animation:
		animation.play("Shoot", -1, 1.5)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
