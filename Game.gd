# Game.gd
extends Node3D

var score: int = 0

func _ready() -> void:
	randomize()  # enable non-repeating randoms each run
	# Connect any targets already in the scene
	for t in get_tree().get_nodes_in_group("target"):
		t.scored.connect(_on_target_scored)

func _on_target_scored() -> void:
	score += 1
	var lbl := $CanvasLayer/ScoreLabel if has_node("CanvasLayer/ScoreLabel") else null
	if lbl:
		lbl.text = "Score: %d" % score
	print("Score: ", score)
