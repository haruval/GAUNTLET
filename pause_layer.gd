extends CanvasLayer

@export var min_sens := 0.001
@export var max_sens := 2.0

@onready var root: Control        = $PauseRoot
@onready var sens_input: LineEdit = $PauseRoot/Panel/HBox/SensInput
@onready var apply_button: Button = $PauseRoot/Panel/Button

var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show_menu(false)

	player = get_tree().get_first_node_in_group("player")

	# Initialize field from player
	var current := 0.015
	if player and player.has_method("get_mouse_sens"):
		current = player.get_mouse_sens()
	if sens_input:
		sens_input.text = str(current)
		sens_input.text_changed.connect(_on_sens_text_changed)      # live while typing
		sens_input.text_submitted.connect(_on_sens_text_submitted)  # Enter to apply/normalize
	if apply_button:
		apply_button.pressed.connect(_apply_from_text)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	_show_menu(not get_tree().paused)

func _show_menu(show: bool) -> void:
	get_tree().paused = show
	root.visible = show
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
	if show and sens_input:
		sens_input.grab_focus()
		sens_input.caret_column = sens_input.text.length()

func _on_sens_text_changed(new_text: String) -> void:
	_set_player_sens(new_text)  # live apply (no normalization yet)

func _on_sens_text_submitted(new_text: String) -> void:
	_apply_from_text()

func _apply_from_text() -> void:
	if _set_player_sens(sens_input.text):
		sens_input.text = str(_clamp_parse(sens_input.text))  # normalize/clamp display

func _set_player_sens(text: String) -> bool:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Player not found in group 'player'.")
		return false

	var value := _clamp_parse(text)
	if value <= 0.0:
		return false

	if player.has_method("set_mouse_sens"):
		player.set_mouse_sens(value)
		return true
	else:
		push_warning("Player is missing set_mouse_sens(). Did you add the patch?")
		return false

func _clamp_parse(text: String) -> float:
	var v := text.to_float()
	if v <= 0.0:
		return 0.0
	return clampf(v, min_sens, max_sens)
