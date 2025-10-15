# Game.gd
extends Node3D

enum State { IDLE, RUNNING, FINISHED }

@export var starting_level: int = 1   # <-- set this per scene: World.tscn = 1, World_Level2.tscn = 2

@onready var timer: Timer = $CountdownTimer
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var level_label: Label = $CanvasLayer/LevelLabel

var state: State = State.IDLE
var score: int = 0
var level: int = 1

#level params
# Level data for this scene
#real values: 110 goal - 60 sec
var levels: Array = [
	{"goal": 110, "duration": 60.0},  # Level 1
	# You can add more dicts here if you want to run multiple levels in one scene later.
]

func _ready() -> void:
	Engine.max_fps = 120
	randomize()

	# Initialize the scene's level from the exported value
	level = starting_level

	# Connect all targets' signals
	for t in get_tree().get_nodes_in_group("target"):
		t.scored.connect(_on_target_scored)
	
	# Apply higher floor clearance only in Level 1
	if starting_level == 1:
		for t in get_tree().get_nodes_in_group("target"):
			t.position.y += 1.3  # raise each target 1 meter upward

	timer.timeout.connect(_on_timer_timeout)

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
		level = starting_level
		_start_level(level)

func _on_target_scored() -> void:
	if state == State.IDLE:
		_begin_run()
		score += 1
		_update_score_ui()
		_check_for_level_clear()  # check immediately
		return

	if state == State.RUNNING:
		score += 1
		_update_score_ui()
		_check_for_level_clear()  # check immediately
		return
	# Ignore hits once finished

func _begin_run() -> void:
	state = State.RUNNING
	timer.wait_time = float(_cur_level()["duration"])
	timer.start()

func _on_timer_timeout() -> void:
	# Timer ended. If not already cleared, finalize as fail.
	if state != State.FINISHED:
		var goal: int = int(_cur_level()["goal"])
		state = State.FINISHED
		if score >= goal:
			_advance_to_next_level()
		else:
			level_label.text = "Level %d — FAILED (Goal: %d)" % [level, goal]
			timer_label.text = "00.0"

func _check_for_level_clear() -> void:
	var goal: int = int(_cur_level()["goal"])
	if score >= goal and state == State.RUNNING:
		# Clear immediately when goal is met
		state = State.FINISHED
		_advance_to_next_level()

func _advance_to_next_level() -> void:
	# Handle advancing from Level 1 -> Level 2 (new scene)
	if level == 1:
		get_tree().change_scene_to_file("res://World_Level2.tscn")
		return

	# If you add more scenes/levels later, extend this logic:
	# elif level == 2: change_scene_to_file("res://World_Level3.tscn")
	# else:
	level_label.text = "All Levels Complete!"
	timer_label.text = "Done"

func _start_level(which: int) -> void:
	level = which
	_reset_level_ui()

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
	# For now we only use index 0 (Level 1 data). If you later store per-level data,
	# you can map (level-1) to this array or split scenes as you planned.
	var idx: int = 0
	return levels[idx]
