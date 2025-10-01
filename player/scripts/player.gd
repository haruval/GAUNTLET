extends CharacterBody3D

const SPEED: float = 10.0
const MOUSE_SENS: float = 0.02
const JUMP_VELOCITY = 4.5
const PITCH_LIMIT: float = 89.0

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
# (Optional) if you want the pistol to follow head pitch but not required:
@onready var pistol: Node3D = $Pistol

var pitch_deg: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _input(event) -> void:
	if event is InputEventMouseMotion:
		#yaw
		rotation_degrees.y -= event.relative.x * MOUSE_SENS
		#pitch
		pitch_deg = clamp(pitch_deg - event.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
		head.rotation_degrees.x = pitch_deg
		# (Optional) if pistol should tilt with head but is not a child of Head:
		# pistol.rotation_degrees.x = pitch_deg
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot()
		if pistol and pistol.has_method("play_shoot"):
			pistol.play_shoot()

func shoot() -> void:
	var vp_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(vp_pos)
	var dir  = cam.project_ray_normal(vp_pos)
	var to   = from + dir * 2000.0

	var space_state = get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(from, to)
	var hit = space_state.intersect_ray(params)

	if hit:
		var col = hit.collider
		if col and col.is_in_group("target"):
			if col.has_method("on_shot"):
				col.on_shot()

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	#jump - comment out if breaking shit
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	#get the input direction and handle movement/decel
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
	
	
