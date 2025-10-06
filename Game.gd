# Game.gd
extends Node3D

enum State { IDLE, RUNNING, FINISHED }

@onready var timer: Timer = $CountdownTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var level_label: Label = $CanvasLayer/LevelLabel

var state: State = State.IDLE
var score: int = 0
var level: int = 1

# Level 1 only (Level 2 will be a separate scene you load)
var levels: Array = [
	{"radius": 0.35, "goal": 100, "duration": 30.0},
]

func _ready() -> void:
	Engine.max_fps = 120
	randomize()

	# Connect all targets' signals
	for t in get_tree().get_nodes_in_group("target"):
		t.scored.connect(_on_target_scored)

	timer.timeout.connect(_on_timer_timeout)

	_apply_level_params()
	_reset_level_ui()

func _process(delta: float) -> void:
	if state == State.RUNNING:
		var remaining: float = max(timer.time_left, 0.0)
		timer_label.text = "%0.1f" % remaining

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and state == State.FINISHED:
		_start_level(level)  # retry same level
	if event.is_action_pressed("reload_level"):
		_start_level(level)
	if event.is_action_pressed("ui_cancel") and state == State.FINISHED:
		level = 1
		_start_level(level)

func _on_target_scored() -> void:
	if state == State.IDLE:
		_begin_run()
		score += 1
		_update_score_ui()
		return

	if state == State.RUNNING:
		score += 1
		_update_score_ui()
		return
	# Ignore hits once finished

func _begin_run() -> void:
	state = State.RUNNING
	timer.wait_time = float(_cur_level()["duration"])
	timer.start()

func _on_timer_timeout() -> void:
	state = State.FINISHED
	var goal: int = int(_cur_level()["goal"])

	if score >= goal:
		# Level 1 cleared -> load Level 2 scene (a copy of World)
		if level == 1:
			get_tree().change_scene_to_file("res://World_Level2.tscn")
			return
		# If you add more levels later, handle them here
		level_label.text = "All Levels Complete!"
		timer_label.text = "Done"
	else:
		level_label.text = "Level %d — FAILED (Goal: %d)" % [level, goal]
		timer_label.text = "00.0"

func _start_level(which: int) -> void:
	level = which
	_apply_level_params()
	_reset_level_ui()

func _apply_level_params() -> void:
	# Apply target radius for Level 1 (Level 2 is its own scene)
	var r: float = float(_cur_level()["radius"])
	for t in get_tree().get_nodes_in_group("target"):
		if t.has_method("set_radius"):
			t.set_radius(r)

func _reset_level_ui() -> void:
	state = State.IDLE
	score = 0
	_update_score_ui()
	var goal: int = int(_cur_level()["goal"])
	level_label.text = "Level %d (Goal: %d)" % [level, goal]
	timer_label.text = "%0.1f" % float(_cur_level()["duration"])
	timer.stop()

func _update_score_ui() -> void:
	score_label.text = "Score: %d" % score

func _cur_level() -> Dictionary:
	var idx: int = clamp(level - 1, 0, levels.size() - 1)
	return levels[idx]
